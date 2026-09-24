#import "touch_controls.h"

#import <UIKit/UIKit.h>

#include <SDL3/SDL.h>

#include <algorithm>
#include <cmath>

#include "game/sce/ottsel_platform_input.h"

namespace pi = ottsel::platform_input;

namespace {
OttselTouchHooks g_hooks{};

NSString* const kCentersKey = @"OttselTouchControlCenters";  // id -> normalized center in the safe area
NSString* const kOpacityKey = @"OttselTouchOpacity";
NSString* const kSizeKey = @"OttselTouchSize";

// One control's default placement: normalized center in the safe area and its size in iPad points.
struct ControlDefault {
  NSString* ident;
  CGFloat x, y, w, h;
};
// iPad landscape. Phones use the same centers with sizes scaled to the smaller screen.
const ControlDefault kDefaults[] = {
    {@"move", 0.125, 0.72, 172, 172},  {@"dpad", 0.300, 0.83, 150, 150},
    {@"camera", 0.905, 0.86, 116, 116}, {@"face", 0.865, 0.50, 250, 250},
    {@"L1", 0.130, 0.22, 132, 56},     {@"R1", 0.855, 0.22, 132, 56},
    {@"start", 0.500, 0.09, 108, 46},
};

const ControlDefault* default_for(NSString* ident) {
  for (const auto& d : kDefaults) {
    if ([d.ident isEqualToString:ident]) return &d;
  }
  return nullptr;
}
}  // namespace

// MARK: - Stick

@interface OttselStickView : UIView
@property(nonatomic, copy) void (^valueChanged)(float x, float y);
@property(nonatomic, assign) BOOL editing;
- (void)reset;
@end

@implementation OttselStickView {
  UIView* _thumb;
  float _x, _y;
}

- (instancetype)initWithFrame:(CGRect)frame {
  if ((self = [super initWithFrame:frame])) {
    self.multipleTouchEnabled = NO;
    self.layer.borderWidth = 2.0;
    self.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.34].CGColor;
    _thumb = [[UIView alloc] initWithFrame:CGRectZero];
    _thumb.userInteractionEnabled = NO;
    [self addSubview:_thumb];
  }
  return self;
}

- (void)setBaseColor:(UIColor*)base thumbColor:(UIColor*)thumb {
  self.backgroundColor = base;
  _thumb.backgroundColor = thumb;
}

- (void)layoutSubviews {
  [super layoutSubviews];
  CGFloat side = std::min(self.bounds.size.width, self.bounds.size.height);
  self.layer.cornerRadius = side * 0.5;
  CGFloat thumb = side * 0.42;
  _thumb.bounds = CGRectMake(0, 0, thumb, thumb);
  _thumb.layer.cornerRadius = thumb * 0.5;
  [self placeThumb];
}

- (void)placeThumb {
  CGFloat half = self.bounds.size.width * 0.5;
  CGFloat travel = std::max<CGFloat>(0.0, half - _thumb.bounds.size.width * 0.5 - 4.0);
  _thumb.center = CGPointMake(half + _x * travel, half + _y * travel);
}

- (void)track:(UITouch*)touch {
  CGPoint p = [touch locationInView:self];
  CGFloat radius = std::max<CGFloat>(1.0, self.bounds.size.width * 0.5);
  CGFloat dx = (p.x - CGRectGetMidX(self.bounds)) / radius;
  CGFloat dy = (p.y - CGRectGetMidY(self.bounds)) / radius;
  CGFloat length = std::hypot(dx, dy);
  if (length > 1.0) {
    dx /= length;
    dy /= length;
  }
  _x = (float)dx;
  _y = (float)dy;
  [self placeThumb];
  if (self.valueChanged) self.valueChanged(_x, _y);
}

- (void)reset {
  _x = _y = 0.f;
  [self placeThumb];
  if (self.valueChanged) self.valueChanged(0.f, 0.f);
}

- (void)touchesBegan:(NSSet<UITouch*>*)touches withEvent:(UIEvent*)event {
  if (!self.editing) [self track:touches.anyObject];
}
- (void)touchesMoved:(NSSet<UITouch*>*)touches withEvent:(UIEvent*)event {
  if (!self.editing) [self track:touches.anyObject];
}
- (void)touchesEnded:(NSSet<UITouch*>*)touches withEvent:(UIEvent*)event {
  if (!self.editing) [self reset];
}
- (void)touchesCancelled:(NSSet<UITouch*>*)touches withEvent:(UIEvent*)event {
  if (!self.editing) [self reset];
}
@end

// MARK: - Buttons

@interface OttselPadButton : UIButton
@property(nonatomic, assign) uint16_t mask;
@end
@implementation OttselPadButton
@end

// A container (face buttons, D-pad) that is dragged as one piece in edit mode.
@interface OttselControlGroup : UIView
@end
@implementation OttselControlGroup
@end

// Touches that miss every control fall through to the game view.
@interface OttselPassThroughView : UIView
@end
@implementation OttselPassThroughView
- (UIView*)hitTest:(CGPoint)point withEvent:(UIEvent*)event {
  UIView* hit = [super hitTest:point withEvent:event];
  return hit == self ? nil : hit;
}
@end

// MARK: - Overlay

@interface OttselTouchOverlay : OttselPassThroughView
- (void)setControlsHidden:(BOOL)hidden;
@end

@implementation OttselTouchOverlay {
  UIButton* _menuButton;
  UIView* _controls;  // every control; hidden as one
  OttselStickView* _move;
  OttselStickView* _camera;
  OttselControlGroup* _face;
  OttselControlGroup* _dpad;
  NSMutableArray<OttselPadButton*>* _buttons;
  NSMutableDictionary<NSString*, UIView*>* _byIdent;
  UIButton* _doneButton;
  OttselTouchPad _pad;
  BOOL _editing;
  BOOL _hiddenByInput;
}

- (instancetype)initWithFrame:(CGRect)frame {
  if ((self = [super initWithFrame:frame])) {
    self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.multipleTouchEnabled = YES;
    _buttons = [NSMutableArray array];
    _byIdent = [NSMutableDictionary dictionary];
    _controls = [[OttselPassThroughView alloc] initWithFrame:self.bounds];
    _controls.autoresizingMask = self.autoresizingMask;
    _controls.multipleTouchEnabled = YES;
    [self addSubview:_controls];
    [self buildControls];
    [self buildMenuButton];
    [self buildDoneButton];
    [self applyAppearance];
  }
  return self;
}

// MARK: Controls

- (void)buildControls {
  __weak OttselTouchOverlay* weakSelf = self;
  _move = [[OttselStickView alloc] initWithFrame:CGRectMake(0, 0, 172, 172)];
  [_move setBaseColor:[UIColor colorWithWhite:0.13 alpha:0.86]
           thumbColor:[UIColor colorWithWhite:0.58 alpha:0.94]];
  _move.accessibilityLabel = @"Move stick";
  _move.valueChanged = ^(float x, float y) {
    [weakSelf stick:NO x:x y:y];
  };
  _camera = [[OttselStickView alloc] initWithFrame:CGRectMake(0, 0, 116, 116)];
  [_camera setBaseColor:[UIColor colorWithRed:0.10 green:0.28 blue:0.55 alpha:0.86]
             thumbColor:[UIColor colorWithRed:0.45 green:0.66 blue:1.00 alpha:0.96]];
  _camera.accessibilityLabel = @"Camera stick";
  _camera.valueChanged = ^(float x, float y) {
    [weakSelf stick:YES x:x y:y];
  };
  [self addControl:_move ident:@"move"];
  [self addControl:_camera ident:@"camera"];

  // PlayStation face buttons: glyph colours on dark fills.
  _face = [[OttselControlGroup alloc] initWithFrame:CGRectMake(0, 0, 250, 250)];
  _face.accessibilityLabel = @"Face buttons";
  [self addControl:_face ident:@"face"];
  [self addButton:@"triangle" mask:pi::Triangle label:@"Triangle"
            color:[UIColor colorWithRed:0.30 green:0.85 blue:0.62 alpha:1] into:_face];
  [self addButton:@"circle" mask:pi::Circle label:@"Circle"
            color:[UIColor colorWithRed:1.00 green:0.38 blue:0.40 alpha:1] into:_face];
  [self addButton:@"xmark" mask:pi::Cross label:@"Cross"
            color:[UIColor colorWithRed:0.50 green:0.68 blue:1.00 alpha:1] into:_face];
  [self addButton:@"square" mask:pi::Square label:@"Square"
            color:[UIColor colorWithRed:1.00 green:0.52 blue:0.86 alpha:1] into:_face];

  _dpad = [[OttselControlGroup alloc] initWithFrame:CGRectMake(0, 0, 150, 150)];
  _dpad.accessibilityLabel = @"D-pad";
  [self addControl:_dpad ident:@"dpad"];
  UIColor* white = [UIColor colorWithWhite:0.92 alpha:1];
  [self addButton:@"arrowtriangle.up.fill" mask:pi::DpadUp label:@"D-pad up" color:white into:_dpad];
  [self addButton:@"arrowtriangle.right.fill" mask:pi::DpadRight label:@"D-pad right" color:white
             into:_dpad];
  [self addButton:@"arrowtriangle.down.fill" mask:pi::DpadDown label:@"D-pad down" color:white
             into:_dpad];
  [self addButton:@"arrowtriangle.left.fill" mask:pi::DpadLeft label:@"D-pad left" color:white
             into:_dpad];

  [self addControl:[self textButton:@"L1" mask:pi::L1] ident:@"L1"];
  [self addControl:[self textButton:@"R1" mask:pi::R1] ident:@"R1"];
  [self addControl:[self textButton:@"START" mask:pi::Start] ident:@"start"];
}

- (void)addControl:(UIView*)control ident:(NSString*)ident {
  control.accessibilityIdentifier = ident;
  _byIdent[ident] = control;
  [_controls addSubview:control];
  UIPanGestureRecognizer* pan = [[UIPanGestureRecognizer alloc] initWithTarget:self
                                                                        action:@selector(dragged:)];
  pan.enabled = NO;
  [control addGestureRecognizer:pan];
}

- (void)styleButton:(OttselPadButton*)button {
  button.backgroundColor = [UIColor colorWithWhite:0.08 alpha:0.62];
  button.layer.borderWidth = 2.0;
  button.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.34].CGColor;
  [button addTarget:self action:@selector(buttonDown:) forControlEvents:UIControlEventTouchDown];
  [button addTarget:self
                action:@selector(buttonUp:)
      forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside |
                       UIControlEventTouchCancel];
  [_buttons addObject:button];
}

- (void)addButton:(NSString*)symbol
             mask:(uint16_t)mask
            label:(NSString*)label
            color:(UIColor*)color
             into:(UIView*)group {
  OttselPadButton* button = [OttselPadButton buttonWithType:UIButtonTypeCustom];
  button.mask = mask;
  button.accessibilityLabel = label;
  UIImageSymbolConfiguration* config =
      [UIImageSymbolConfiguration configurationWithPointSize:26 weight:UIImageSymbolWeightHeavy];
  [button setImage:[UIImage systemImageNamed:symbol withConfiguration:config]
          forState:UIControlStateNormal];
  button.tintColor = color;
  [self styleButton:button];
  [group addSubview:button];
}

- (OttselPadButton*)textButton:(NSString*)title mask:(uint16_t)mask {
  OttselPadButton* button = [OttselPadButton buttonWithType:UIButtonTypeCustom];
  button.mask = mask;
  button.accessibilityLabel = title;
  [button setTitle:title forState:UIControlStateNormal];
  [button setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
  button.titleLabel.font = [UIFont systemFontOfSize:17 weight:UIFontWeightBold];
  [self styleButton:button];
  return button;
}

// MARK: Input

- (void)publish {
  if (g_hooks.pad_changed) g_hooks.pad_changed(_pad);
}

- (void)stick:(BOOL)camera x:(float)x y:(float)y {
  if (_editing) return;
  if (camera) {
    _pad.rx = x;
    _pad.ry = y;
  } else {
    _pad.lx = x;
    _pad.ly = y;
  }
  [self publish];
}

- (void)buttonDown:(OttselPadButton*)button {
  if (_editing) return;
  _pad.buttons |= button.mask;
  button.transform = CGAffineTransformMakeScale(0.9, 0.9);
  button.backgroundColor = [UIColor colorWithWhite:0.45 alpha:0.75];
  [self publish];
}

- (void)buttonUp:(OttselPadButton*)button {
  if (_editing) return;
  _pad.buttons &= ~button.mask;
  button.transform = CGAffineTransformIdentity;
  button.backgroundColor = [UIColor colorWithWhite:0.08 alpha:0.62];
  [self publish];
}

- (void)clearInput {
  for (OttselPadButton* button in _buttons) {
    button.transform = CGAffineTransformIdentity;
    button.backgroundColor = [UIColor colorWithWhite:0.08 alpha:0.62];
  }
  [_move reset];
  [_camera reset];
  _pad = {};
  [self publish];
}

// MARK: Layout

- (CGRect)safeRect {
  return UIEdgeInsetsInsetRect(self.bounds, self.safeAreaInsets);
}

- (CGFloat)sizeScale {
  CGRect safe = [self safeRect];
  BOOL phone = self.traitCollection.userInterfaceIdiom == UIUserInterfaceIdiomPhone;
  // SunPad's rule: fixed sizes on iPad, scaled to an 800x380 reference area on phones.
  CGFloat base = phone ? std::min<CGFloat>(0.74, std::min(safe.size.width / 800.0 * 0.74,
                                                          safe.size.height / 380.0 * 0.74))
                       : 1.0;
  NSInteger size = [NSUserDefaults.standardUserDefaults integerForKey:kSizeKey];  // -1, 0, 1
  return base * (size < 0 ? 0.85 : size > 0 ? 1.15 : 1.0);
}

- (void)layoutSubviews {
  [super layoutSubviews];
  CGRect safe = [self safeRect];
  CGFloat scale = [self sizeScale];
  NSDictionary* saved = [NSUserDefaults.standardUserDefaults dictionaryForKey:kCentersKey];
  for (const auto& d : kDefaults) {
    UIView* control = _byIdent[d.ident];
    control.bounds = CGRectMake(0, 0, d.w * scale, d.h * scale);
    CGPoint n = CGPointMake(d.x, d.y);
    if (NSString* s = saved[d.ident]) n = CGPointFromString(s);
    CGFloat hw = control.bounds.size.width * 0.5, hh = control.bounds.size.height * 0.5;
    CGFloat cx = CGRectGetMinX(safe) + std::clamp<CGFloat>(n.x, 0, 1) * safe.size.width;
    CGFloat cy = CGRectGetMinY(safe) + std::clamp<CGFloat>(n.y, 0, 1) * safe.size.height;
    control.center = CGPointMake(std::clamp(cx, CGRectGetMinX(safe) + hw, CGRectGetMaxX(safe) - hw),
                                 std::clamp(cy, CGRectGetMinY(safe) + hh, CGRectGetMaxY(safe) - hh));
  }
  [self layoutCross:_face buttonFraction:0.34];
  [self layoutCross:_dpad buttonFraction:0.34];
  for (OttselPadButton* button in _buttons) {
    button.layer.cornerRadius = std::min(button.bounds.size.width, button.bounds.size.height) * 0.5;
  }
  _menuButton.frame = CGRectMake(CGRectGetMaxX(safe) - 52, CGRectGetMinY(safe) + 12, 40, 40);
  _doneButton.frame = CGRectMake(CGRectGetMidX(safe) - 150, CGRectGetMinY(safe) + 70, 300, 48);
}

// Four buttons in a cross (top, right, bottom, left), in the order they were added.
- (void)layoutCross:(UIView*)group buttonFraction:(CGFloat)fraction {
  CGFloat side = group.bounds.size.width;
  CGFloat d = side * fraction;
  CGFloat c = side * 0.5, r = side * 0.5 - d * 0.5;
  const CGPoint offsets[4] = {{0, -1}, {1, 0}, {0, 1}, {-1, 0}};
  NSUInteger i = 0;
  for (UIView* button in group.subviews) {
    if (i >= 4) break;
    button.bounds = CGRectMake(0, 0, d, d);
    button.center = CGPointMake(c + offsets[i].x * r, c + offsets[i].y * r);
    i++;
  }
}

- (void)dragged:(UIPanGestureRecognizer*)pan {
  UIView* control = pan.view;
  CGPoint t = [pan translationInView:self];
  control.center = CGPointMake(control.center.x + t.x, control.center.y + t.y);
  [pan setTranslation:CGPointZero inView:self];
  if (pan.state == UIGestureRecognizerStateEnded || pan.state == UIGestureRecognizerStateCancelled) {
    CGRect safe = [self safeRect];
    CGPoint n = CGPointMake((control.center.x - CGRectGetMinX(safe)) / safe.size.width,
                            (control.center.y - CGRectGetMinY(safe)) / safe.size.height);
    NSMutableDictionary* saved =
        [[NSUserDefaults.standardUserDefaults dictionaryForKey:kCentersKey] mutableCopy]
            ?: [NSMutableDictionary dictionary];
    saved[control.accessibilityIdentifier] = NSStringFromCGPoint(n);
    [NSUserDefaults.standardUserDefaults setObject:saved forKey:kCentersKey];
    [self setNeedsLayout];
  }
}

- (void)setEditing:(BOOL)editing {
  [self clearInput];
  _editing = editing;
  _move.editing = editing;
  _camera.editing = editing;
  for (UIView* control in _byIdent.allValues) {
    for (UIGestureRecognizer* g in control.gestureRecognizers) g.enabled = editing;
    // While editing, a group moves as one piece instead of pressing its buttons.
    for (UIView* child in control.subviews) child.userInteractionEnabled = !editing;
    control.layer.borderWidth = editing && [control isKindOfClass:OttselControlGroup.class] ? 2 : 0;
    control.layer.borderColor = UIColor.systemYellowColor.CGColor;
  }
  _doneButton.hidden = !editing;
  if (editing) _controls.hidden = NO;
  else [self updateVisibility];
}

// MARK: Appearance and visibility

- (void)applyAppearance {
  NSNumber* opacity = [NSUserDefaults.standardUserDefaults objectForKey:kOpacityKey];
  _controls.alpha = opacity ? opacity.doubleValue : 0.8;
  [self setNeedsLayout];
}

- (void)setControlsHidden:(BOOL)hidden {
  _hiddenByInput = hidden;
  [self updateVisibility];
}

- (void)updateVisibility {
  const int mode = g_hooks.setting ? g_hooks.setting("controls") : 0;
  const BOOL hidden = !_editing && (mode == 2 || (mode == 0 && _hiddenByInput));
  if (hidden && !_controls.hidden) [self clearInput];
  _controls.hidden = hidden;
}

// MARK: Menu

- (void)buildMenuButton {
  UIImageSymbolConfiguration* symbol =
      [UIImageSymbolConfiguration configurationWithPointSize:19 weight:UIImageSymbolWeightBold];
  UIButtonConfiguration* config = [UIButtonConfiguration plainButtonConfiguration];
  config.image = [UIImage systemImageNamed:@"ellipsis" withConfiguration:symbol];
  config.baseForegroundColor = UIColor.whiteColor;
  config.contentInsets = NSDirectionalEdgeInsetsZero;
  UIBackgroundConfiguration* background = [UIBackgroundConfiguration clearConfiguration];
  background.backgroundColor = [UIColor colorWithWhite:0.06 alpha:0.72];
  background.cornerRadius = 20;
  background.strokeColor = [UIColor colorWithWhite:1.0 alpha:0.30];
  background.strokeWidth = 1;
  config.background = background;
  _menuButton = [UIButton buttonWithConfiguration:config primaryAction:nil];
  _menuButton.automaticallyUpdatesConfiguration = NO;
  _menuButton.accessibilityLabel = @"Menu";
  _menuButton.showsMenuAsPrimaryAction = YES;
  _menuButton.menu = [self buildMenu];
  [self addSubview:_menuButton];
}

- (void)buildDoneButton {
  UIButtonConfiguration* config = [UIButtonConfiguration filledButtonConfiguration];
  config.title = @"Done Editing Layout";
  config.baseBackgroundColor = UIColor.systemYellowColor;
  config.baseForegroundColor = UIColor.blackColor;
  config.cornerStyle = UIButtonConfigurationCornerStyleCapsule;
  __weak OttselTouchOverlay* weakSelf = self;
  _doneButton = [UIButton buttonWithConfiguration:config
                                    primaryAction:[UIAction actionWithHandler:^(UIAction*) {
                                      [weakSelf setEditing:NO];
                                      [weakSelf refreshMenu];
                                    }]];
  _doneButton.hidden = YES;
  [self addSubview:_doneButton];
}

- (void)refreshMenu {
  _menuButton.menu = [self buildMenu];
}

- (int)setting:(const char*)key {
  return g_hooks.setting ? g_hooks.setting(key) : 0;
}

- (void)set:(const char*)key value:(int)value {
  if (g_hooks.set_setting) g_hooks.set_setting(key, value);
  [self updateVisibility];
  [self refreshMenu];
}

// A single-choice submenu over one shell setting.
- (UIMenu*)choose:(NSString*)title key:(const char*)key titles:(NSArray<NSString*>*)titles
           values:(NSArray<NSNumber*>*)values {
  NSMutableArray* actions = [NSMutableArray array];
  const int current = [self setting:key];
  __weak OttselTouchOverlay* weakSelf = self;
  for (NSUInteger i = 0; i < titles.count; i++) {
    const int value = values[i].intValue;
    UIAction* action = [UIAction actionWithTitle:titles[i] image:nil identifier:nil
                                         handler:^(UIAction*) { [weakSelf set:key value:value]; }];
    action.state = current == value ? UIMenuElementStateOn : UIMenuElementStateOff;
    [actions addObject:action];
  }
  return [UIMenu menuWithTitle:title image:nil identifier:nil
                       options:UIMenuOptionsSingleSelection children:actions];
}

// A single-choice submenu over an overlay preference.
- (UIMenu*)choosePreference:(NSString*)title key:(NSString*)key titles:(NSArray<NSString*>*)titles
                     values:(NSArray<NSNumber*>*)values fallback:(NSNumber*)fallback {
  NSMutableArray* actions = [NSMutableArray array];
  NSNumber* current = [NSUserDefaults.standardUserDefaults objectForKey:key] ?: fallback;
  __weak OttselTouchOverlay* weakSelf = self;
  for (NSUInteger i = 0; i < titles.count; i++) {
    NSNumber* value = values[i];
    UIAction* action = [UIAction actionWithTitle:titles[i] image:nil identifier:nil
                                         handler:^(UIAction*) {
                                           [NSUserDefaults.standardUserDefaults setObject:value
                                                                                   forKey:key];
                                           [weakSelf applyAppearance];
                                           [weakSelf refreshMenu];
                                         }];
    action.state = [current isEqual:value] ? UIMenuElementStateOn : UIMenuElementStateOff;
    [actions addObject:action];
  }
  return [UIMenu menuWithTitle:title image:nil identifier:nil
                       options:UIMenuOptionsSingleSelection children:actions];
}

- (UIMenu*)buildMenu {
  __weak OttselTouchOverlay* weakSelf = self;
  UIAction* edit = [UIAction actionWithTitle:@"Edit Layout"
                                       image:[UIImage systemImageNamed:@"hand.draw"]
                                  identifier:nil
                                     handler:^(UIAction*) { [weakSelf setEditing:YES]; }];
  UIAction* reset = [UIAction actionWithTitle:@"Reset Layout"
                                        image:[UIImage systemImageNamed:@"arrow.counterclockwise"]
                                   identifier:nil
                                      handler:^(UIAction*) {
                                        [NSUserDefaults.standardUserDefaults
                                            removeObjectForKey:kCentersKey];
                                        [NSUserDefaults.standardUserDefaults
                                            removeObjectForKey:kSizeKey];
                                        [weakSelf applyAppearance];
                                      }];
  UIMenu* controls = [UIMenu
      menuWithTitle:@"Controls"
              image:[UIImage systemImageNamed:@"gamecontroller"]
         identifier:nil
            options:0
           children:@[
             [self choose:@"Show Touch Controls" key:"controls"
                   titles:@[ @"Automatically", @"Always", @"Never" ] values:@[ @0, @1, @2 ]],
             [self choosePreference:@"Opacity" key:kOpacityKey
                             titles:@[ @"Faint", @"Medium", @"Solid" ]
                             values:@[ @0.45, @0.8, @1.0 ] fallback:@0.8],
             [self choosePreference:@"Size" key:kSizeKey titles:@[ @"Small", @"Normal", @"Large" ]
                             values:@[ @(-1), @0, @1 ] fallback:@0],
             edit, reset
           ]];
  UIMenu* camera = [UIMenu
      menuWithTitle:@"Camera"
              image:[UIImage systemImageNamed:@"camera.rotate"]
         identifier:nil
            options:0
           children:@[
             [self choose:@"Sensitivity" key:"camera_sensitivity"
                   titles:@[ @"50%", @"75%", @"100%", @"125%", @"150%", @"200%" ]
                   values:@[ @50, @75, @100, @125, @150, @200 ]],
             [self choose:@"Vertical" key:"invert_camera_y" titles:@[ @"Normal", @"Inverted" ]
                   values:@[ @0, @1 ]],
           ]];
  UIMenu* display = [self choose:@"Render Resolution" key:"render_scale"
                          titles:@[ @"100%", @"75%", @"50%" ] values:@[ @100, @75, @50 ]];
  UIMenu* audio = [self choose:@"Music Volume" key:"music_volume"
                        titles:@[ @"Off", @"25%", @"50%", @"75%", @"100%" ]
                        values:@[ @0, @25, @50, @75, @100 ]];
  UIMenu* diagnostics = [self choose:@"Diagnostics Log" key:"log_overlay"
                              titles:@[ @"Hidden", @"Shown over the game" ] values:@[ @0, @1 ]];
  return [UIMenu menuWithTitle:@"Ottsel" children:@[ controls, camera, display, audio, diagnostics ]];
}
@end

// MARK: - C++ entry points

namespace {
OttselTouchOverlay* g_overlay = nil;
}

void ottsel_touch_install(SDL_Window* window, const OttselTouchHooks& hooks) {
  g_hooks = hooks;
  UIWindow* uiwindow = (__bridge UIWindow*)SDL_GetPointerProperty(
      SDL_GetWindowProperties(window), SDL_PROP_WINDOW_UIKIT_WINDOW_POINTER, nullptr);
  UIView* host = uiwindow.rootViewController.view;
  if (!host) {
    SDL_Log("OTTSEL TOUCH: no UIKit view to attach the controls to");
    return;
  }
  g_overlay = [[OttselTouchOverlay alloc] initWithFrame:host.bounds];
  [host addSubview:g_overlay];
  [host bringSubviewToFront:g_overlay];
}

void ottsel_touch_set_hidden(bool hidden) {
  [g_overlay setControlsHidden:hidden];
}
