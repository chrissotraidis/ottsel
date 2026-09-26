#import "touch_controls.h"

#import <UIKit/UIKit.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

#include <SDL3/SDL.h>

#include <algorithm>
#include <atomic>
#include <cmath>
#include <string>
#include <unordered_map>

#include "game/sce/ottsel_platform_input.h"

namespace pi = ottsel::platform_input;

// game/sce/libpad.cpp: the cheat to toggle (a pc-cheats bit, -1 none) and the cheats that are on.
extern std::atomic<int> g_ottsel_cheat_request;
extern std::atomic<unsigned> g_ottsel_cheats_on;

namespace {
OttselTouchHooks g_hooks{};

// Versioned: a layout saved against older default positions starts over from the current defaults.
NSString* const kCentersKey = @"OttselTouchControlCenters.v3";  // ident -> normalized center in the safe area
NSString* const kSizesKey = @"OttselTouchControlSizes.v3";      // ident -> size multiplier
NSString* const kOpacityKey = @"OttselTouchOpacity";
NSString* const kSizeScaleKey = @"OttselTouchSizeScale";
NSString* const kShowFPSKey = @"OttselShowFPS";
NSString* const kFloatingKey = @"OttselTouchFloatingStick";  // absent = on

// One control's default placement: normalized center in the safe area and its size in iPad points.
struct ControlDefault {
  NSString* ident;
  NSString* label;
  CGFloat x, y, w, h;
};
// Two columns on the screen edges, one per thumb, so the middle of the screen stays clear:
// left edge L1 / D-pad / move stick, right edge R1 / face buttons / camera stick, START bottom centre.
// The move stick normally floats: it appears wherever the left thumb lands below the D-pad, so its
// position here only matters with "Stick follows thumb" turned off.
const ControlDefault kDefaults[] = {
    {@"L1", @"L1", 0.120, 0.13, 128, 52},
    {@"L2", @"L2", 0.245, 0.13, 92, 44},
    {@"dpad", @"D-pad", 0.120, 0.37, 128, 128},
    {@"move", @"Move stick", 0.120, 0.78, 180, 180},
    {@"R1", @"R1", 0.880, 0.13, 128, 52},
    {@"R2", @"R2", 0.755, 0.13, 92, 44},
    {@"face", @"Face buttons", 0.880, 0.49, 232, 232},
    {@"camera", @"Camera stick", 0.855, 0.86, 124, 124},
    {@"start", @"START", 0.500, 0.95, 96, 40},
};

int setting(const char* key) {
  return g_hooks.setting ? g_hooks.setting(key) : 0;
}

void set_setting(const char* key, int value) {
  if (g_hooks.set_setting) g_hooks.set_setting(key, value);
}

UIColor* border_color(bool selected) {
  return selected ? [UIColor colorWithRed:0.20 green:0.78 blue:1.0 alpha:1.0]
                  : [UIColor colorWithRed:1.0 green:0.78 blue:0.20 alpha:0.95];
}
}  // namespace

// Controls that the layout editor can move and resize.
@protocol OttselEditable <NSObject>
@property(nonatomic, assign) BOOL editing;
- (void)releaseInput;
@end

// MARK: - Stick

@interface OttselStickView : UIView <OttselEditable>
@property(nonatomic, copy) void (^valueChanged)(float x, float y);
@property(nonatomic, assign) BOOL editing;
- (void)trackPoint:(CGPoint)p;
@end

@implementation OttselStickView {
  UIView* _thumb;
  float _x, _y;
}

- (instancetype)initWithBase:(UIColor*)base thumb:(UIColor*)thumb {
  if ((self = [super initWithFrame:CGRectMake(0, 0, 128, 128)])) {
    self.multipleTouchEnabled = NO;
    self.backgroundColor = base;
    self.layer.borderWidth = 2.0;
    self.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.34].CGColor;
    _thumb = [[UIView alloc] initWithFrame:CGRectZero];
    _thumb.userInteractionEnabled = NO;
    _thumb.backgroundColor = thumb;
    [self addSubview:_thumb];
  }
  return self;
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

// A thumb that lands just outside the ring still grabs the stick.
- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent*)event {
  CGFloat grow = self.bounds.size.width * 0.18;
  return CGRectContainsPoint(CGRectInset(self.bounds, -grow, -grow), point);
}

- (void)placeThumb {
  CGFloat half = self.bounds.size.width * 0.5;
  CGFloat travel = std::max<CGFloat>(0.0, half - _thumb.bounds.size.width * 0.5 - 4.0);
  _thumb.center = CGPointMake(half + _x * travel, half + _y * travel);
}

- (void)track:(UITouch*)touch {
  [self trackPoint:[touch locationInView:self]];
}

// p is in this view's coordinates; the stick's centre is neutral.
- (void)trackPoint:(CGPoint)p {
  CGFloat radius = std::max<CGFloat>(1.0, self.bounds.size.width * 0.5);
  CGFloat dx = (p.x - CGRectGetMidX(self.bounds)) / radius;
  CGFloat dy = (p.y - CGRectGetMidY(self.bounds)) / radius;
  CGFloat length = std::hypot(dx, dy);
  // Dead zone near the centre and full deflection before the rim, so a resting thumb is neutral and
  // running does not need the thumb at the very edge.
  constexpr CGFloat kDead = 0.12, kFull = 0.85;
  CGFloat scaled = std::clamp((length - kDead) / (kFull - kDead), 0.0, 1.0);
  CGFloat shown = std::min<CGFloat>(length, 1.0);
  _x = length > 0 ? (float)(dx / length * scaled) : 0.f;
  _y = length > 0 ? (float)(dy / length * scaled) : 0.f;
  CGFloat half = self.bounds.size.width * 0.5;
  CGFloat travel = std::max<CGFloat>(0.0, half - _thumb.bounds.size.width * 0.5 - 4.0);
  _thumb.center = CGPointMake(half + (length > 0 ? dx / length * shown : 0) * travel,
                              half + (length > 0 ? dy / length * shown : 0) * travel);
  if (self.valueChanged) self.valueChanged(_x, _y);
}

- (void)releaseInput {
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
  if (!self.editing) [self releaseInput];
}
- (void)touchesCancelled:(NSSet<UITouch*>*)touches withEvent:(UIEvent*)event {
  [self releaseInput];
}
@end

// MARK: - Floating stick area

// The left thumb's area. Wherever a thumb lands becomes the move stick's centre, so there is no exact
// spot to hit; the stick fades in under the thumb and out when it lifts. Dragging past the rim pulls
// the centre along, so reversing direction takes a short movement from anywhere. Controls above this
// view (D-pad, L1) still get their own touches first.
@interface OttselStickZone : UIView
@property(nonatomic, weak) OttselStickView* stick;
@property(nonatomic, readonly) BOOL tracking;
@end

@implementation OttselStickZone {
  CGPoint _origin;  // stick centre, in the superview's coordinates
}

- (instancetype)initWithFrame:(CGRect)frame {
  if ((self = [super initWithFrame:frame])) {
    self.multipleTouchEnabled = NO;  // one thumb drives the stick; a second finger here is ignored
    self.backgroundColor = UIColor.clearColor;
    self.isAccessibilityElement = YES;
    self.accessibilityLabel = @"Move area";
  }
  return self;
}

- (void)follow:(UITouch*)touch {
  OttselStickView* stick = self.stick;
  CGPoint p = [touch locationInView:self.superview];
  CGFloat radius = stick.bounds.size.width * 0.5;
  CGFloat dx = p.x - _origin.x, dy = p.y - _origin.y, length = std::hypot(dx, dy);
  if (length > radius) {
    _origin.x += dx * (1.0 - radius / length);
    _origin.y += dy * (1.0 - radius / length);
    stick.center = _origin;
  }
  [stick trackPoint:[self.superview convertPoint:p toView:stick]];
}

- (void)touchesBegan:(NSSet<UITouch*>*)touches withEvent:(UIEvent*)event {
  _tracking = YES;
  _origin = [touches.anyObject locationInView:self.superview];
  [self.stick.layer removeAllAnimations];
  self.stick.center = _origin;
  self.stick.alpha = 1.0;
  [self follow:touches.anyObject];
}
- (void)touchesMoved:(NSSet<UITouch*>*)touches withEvent:(UIEvent*)event {
  [self follow:touches.anyObject];
}
- (void)touchesEnded:(NSSet<UITouch*>*)touches withEvent:(UIEvent*)event {
  [self lift];
}
- (void)touchesCancelled:(NSSet<UITouch*>*)touches withEvent:(UIEvent*)event {
  [self lift];
}

- (void)lift {
  _tracking = NO;
  OttselStickView* stick = self.stick;
  [stick releaseInput];
  [UIView animateWithDuration:0.18 animations:^{
    stick.alpha = 0.0;
  }];
}
@end

// MARK: - Button cluster (face buttons, D-pad)

// Four buttons in a cross that track fingers as a group: a thumb can slide from one button to the next
// without lifting (jump, then attack), and a thumb resting between two presses both (a D-pad diagonal).
@interface OttselButtonCluster : UIView <OttselEditable>
@property(nonatomic, copy) void (^maskChanged)(uint16_t mask);
@property(nonatomic, assign) BOOL editing;
@end

@implementation OttselButtonCluster {
  NSMutableArray<UIView*>* _faces;
  uint16_t _masks[4];
  std::unordered_map<void*, uint16_t> _touches;
  uint16_t _mask;
  UIImpactFeedbackGenerator* _haptic;
}

- (instancetype)init {
  if ((self = [super initWithFrame:CGRectMake(0, 0, 200, 200)])) {
    self.multipleTouchEnabled = YES;
    _faces = [NSMutableArray array];
    _haptic = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
  }
  return self;
}

// Buttons go top, right, bottom, left.
- (void)addButton:(NSString*)symbol label:(NSString*)label mask:(uint16_t)mask color:(UIColor*)color {
  UIView* face = [[UIView alloc] initWithFrame:CGRectZero];
  face.userInteractionEnabled = NO;
  face.backgroundColor = [UIColor colorWithWhite:0.08 alpha:0.62];
  face.layer.borderWidth = 2.0;
  face.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.34].CGColor;
  UIImageView* glyph = [[UIImageView alloc]
      initWithImage:[UIImage systemImageNamed:symbol
                            withConfiguration:[UIImageSymbolConfiguration
                                                  configurationWithWeight:UIImageSymbolWeightHeavy]]];
  glyph.tintColor = color;
  glyph.contentMode = UIViewContentModeScaleAspectFit;
  glyph.tag = 1;
  [face addSubview:glyph];
  // Each button is its own accessibility element (and what UI tests press).
  face.isAccessibilityElement = YES;
  face.accessibilityLabel = label;
  face.accessibilityTraits = UIAccessibilityTraitButton;
  _masks[_faces.count] = mask;
  [_faces addObject:face];
  [self addSubview:face];
}

- (void)layoutSubviews {
  [super layoutSubviews];
  CGFloat side = self.bounds.size.width;
  CGFloat d = side * 0.36;
  CGFloat c = side * 0.5, r = side * 0.5 - d * 0.5;
  const CGPoint offsets[4] = {{0, -1}, {1, 0}, {0, 1}, {-1, 0}};
  for (NSUInteger i = 0; i < _faces.count; i++) {
    UIView* face = _faces[i];
    face.bounds = CGRectMake(0, 0, d, d);
    face.center = CGPointMake(c + offsets[i].x * r, c + offsets[i].y * r);
    face.layer.cornerRadius = d * 0.5;
    UIView* glyph = [face viewWithTag:1];
    glyph.frame = CGRectInset(face.bounds, d * 0.27, d * 0.27);
  }
}

- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent*)event {
  CGFloat grow = self.bounds.size.width * 0.08;
  return CGRectContainsPoint(CGRectInset(self.bounds, -grow, -grow), point);
}

- (uint16_t)maskAt:(CGPoint)p {
  CGFloat d = self.bounds.size.width * 0.36;
  uint16_t mask = 0;
  CGFloat nearest = CGFLOAT_MAX;
  uint16_t nearest_mask = 0;
  for (NSUInteger i = 0; i < _faces.count; i++) {
    CGFloat dist = std::hypot(p.x - _faces[i].center.x, p.y - _faces[i].center.y);
    if (dist < d * 0.72) mask |= _masks[i];  // between two buttons presses both
    if (dist < nearest) {
      nearest = dist;
      nearest_mask = _masks[i];
    }
  }
  // Anywhere else inside the cluster presses the closest button.
  if (!mask && nearest < d * 1.1) mask = nearest_mask;
  return mask;
}

- (void)update {
  uint16_t mask = 0;
  for (auto& [touch, bits] : _touches) mask |= bits;
  if (mask == _mask) return;
  if (mask & ~_mask) [_haptic impactOccurred];
  _mask = mask;
  for (NSUInteger i = 0; i < _faces.count; i++) {
    const bool down = (mask & _masks[i]) != 0;
    _faces[i].backgroundColor = [UIColor colorWithWhite:down ? 0.5 : 0.08 alpha:down ? 0.8 : 0.62];
    _faces[i].transform = down ? CGAffineTransformMakeScale(0.9, 0.9) : CGAffineTransformIdentity;
  }
  if (self.maskChanged) self.maskChanged(mask);
}

- (void)touchesBegan:(NSSet<UITouch*>*)touches withEvent:(UIEvent*)event {
  if (self.editing) return;
  for (UITouch* touch in touches) _touches[(__bridge void*)touch] = [self maskAt:[touch locationInView:self]];
  [self update];
}
- (void)touchesMoved:(NSSet<UITouch*>*)touches withEvent:(UIEvent*)event {
  if (self.editing) return;
  for (UITouch* touch in touches) _touches[(__bridge void*)touch] = [self maskAt:[touch locationInView:self]];
  [self update];
}
- (void)touchesEnded:(NSSet<UITouch*>*)touches withEvent:(UIEvent*)event {
  for (UITouch* touch in touches) _touches.erase((__bridge void*)touch);
  [self update];
}
- (void)touchesCancelled:(NSSet<UITouch*>*)touches withEvent:(UIEvent*)event {
  [self touchesEnded:touches withEvent:event];
}

- (void)releaseInput {
  _touches.clear();
  [self update];
}
@end

// MARK: - Single buttons (L1, R1, START)

@interface OttselPadButton : UIButton <OttselEditable>
@property(nonatomic, assign) uint16_t mask;
@property(nonatomic, assign) BOOL editing;
@property(nonatomic, copy) void (^pressed)(BOOL down);
@end

@implementation OttselPadButton
- (void)releaseInput {
  self.transform = CGAffineTransformIdentity;
  self.backgroundColor = [UIColor colorWithWhite:0.08 alpha:0.62];
}
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

@interface OttselTouchOverlay : OttselPassThroughView <UIDocumentPickerDelegate>
- (void)setControlsHidden:(BOOL)hidden;
- (void)setTVMode:(BOOL)onTV;
@end

@implementation OttselTouchOverlay {
  UIButton* _menuButton;
  UIView* _controls;  // every gameplay control; hidden as one
  UIView* _tvBackdrop;  // covers the (no longer presented) game view while the game is on a TV
  OttselStickZone* _moveZone;
  NSMutableDictionary<NSString*, UIView<OttselEditable>*>* _byIdent;
  OttselTouchPad _pad;
  uint16_t _clusterMasks[2];  // face, D-pad
  UIImpactFeedbackGenerator* _haptic;
  BOOL _editing;
  BOOL _hiddenByInput;
  __weak UIView* _selected;

  UIView* _panel;
  UISegmentedControl* _showControl;
  UISlider* _opacitySlider;
  UISlider* _sizeSlider;
  UISlider* _cameraSlider;
  UISwitch* _invertSwitch;
  UISwitch* _floatSwitch;
  UISwitch* _editSwitch;

  UIView* _editorBar;
  UILabel* _editorHint;
  UISlider* _selectedSize;

  UILabel* _fpsLabel;
  NSTimer* _fpsTimer;
}

- (instancetype)initWithFrame:(CGRect)frame {
  if ((self = [super initWithFrame:frame])) {
    self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.multipleTouchEnabled = YES;
    // Layouts saved against older default positions are never read again; drop them.
    for (NSString* key in @[ @"OttselTouchControlCenters.v2", @"OttselTouchControlSizes.v2" ]) {
      [NSUserDefaults.standardUserDefaults removeObjectForKey:key];
    }
    _byIdent = [NSMutableDictionary dictionary];
    _haptic = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
    [self buildTVBackdrop];
    _controls = [[OttselPassThroughView alloc] initWithFrame:self.bounds];
    _controls.autoresizingMask = self.autoresizingMask;
    _controls.multipleTouchEnabled = YES;
    [self addSubview:_controls];
    [self buildControls];
    [self buildFPSLabel];
    [self buildPanel];
    [self buildEditorBar];
    [self buildMenuButton];
    [self applyAppearance];
  }
  return self;
}

// MARK: Controls

- (void)buildTVBackdrop {
  _tvBackdrop = [[UIView alloc] initWithFrame:self.bounds];
  _tvBackdrop.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
  _tvBackdrop.backgroundColor = [UIColor colorWithWhite:0.04 alpha:1.0];
  _tvBackdrop.userInteractionEnabled = NO;
  _tvBackdrop.hidden = YES;
  UIImageView* icon = [[UIImageView alloc]
      initWithImage:[UIImage systemImageNamed:@"tv"
                            withConfiguration:[UIImageSymbolConfiguration
                                                  configurationWithPointSize:44
                                                                      weight:UIImageSymbolWeightRegular]]];
  icon.tintColor = [UIColor colorWithWhite:1.0 alpha:0.5];
  UILabel* title = [UILabel new];
  title.text = @"Playing on your TV";
  title.textColor = [UIColor colorWithWhite:1.0 alpha:0.75];
  title.font = [UIFont systemFontOfSize:22 weight:UIFontWeightSemibold];
  UILabel* note = [UILabel new];
  note.text = @"This iPad is the controller.";
  note.textColor = [UIColor colorWithWhite:1.0 alpha:0.45];
  note.font = [UIFont systemFontOfSize:15];
  UIStackView* stack = [[UIStackView alloc] initWithArrangedSubviews:@[ icon, title, note ]];
  stack.axis = UILayoutConstraintAxisVertical;
  stack.alignment = UIStackViewAlignmentCenter;
  stack.spacing = 8;
  stack.translatesAutoresizingMaskIntoConstraints = NO;
  [_tvBackdrop addSubview:stack];
  [NSLayoutConstraint activateConstraints:@[
    [stack.centerXAnchor constraintEqualToAnchor:_tvBackdrop.centerXAnchor],
    [stack.centerYAnchor constraintEqualToAnchor:_tvBackdrop.centerYAnchor constant:-40],
  ]];
  [self addSubview:_tvBackdrop];
}

- (void)setTVMode:(BOOL)onTV {
  _tvBackdrop.hidden = !onTV;
}

- (void)buildControls {
  __weak OttselTouchOverlay* weakSelf = self;
  OttselStickView* move = [[OttselStickView alloc]
      initWithBase:[UIColor colorWithWhite:0.13 alpha:0.86]
             thumb:[UIColor colorWithWhite:0.58 alpha:0.94]];
  move.valueChanged = ^(float x, float y) {
    [weakSelf stick:NO x:x y:y];
  };
  OttselStickView* camera = [[OttselStickView alloc]
      initWithBase:[UIColor colorWithRed:0.10 green:0.28 blue:0.55 alpha:0.86]
             thumb:[UIColor colorWithRed:0.45 green:0.66 blue:1.00 alpha:0.96]];
  camera.valueChanged = ^(float x, float y) {
    [weakSelf stick:YES x:x y:y];
  };
  // Added first, so every control drawn over it keeps its own touches.
  _moveZone = [[OttselStickZone alloc] initWithFrame:CGRectZero];
  _moveZone.stick = move;
  _moveZone.accessibilityIdentifier = @"move-zone";
  [_controls addSubview:_moveZone];

  // PlayStation face buttons in their glyph colours.
  OttselButtonCluster* face = [OttselButtonCluster new];
  [face addButton:@"triangle" label:@"Triangle" mask:pi::Triangle
            color:[UIColor colorWithRed:0.30 green:0.85 blue:0.62 alpha:1]];
  [face addButton:@"circle" label:@"Circle" mask:pi::Circle
            color:[UIColor colorWithRed:1.00 green:0.38 blue:0.40 alpha:1]];
  [face addButton:@"xmark" label:@"Cross" mask:pi::Cross
            color:[UIColor colorWithRed:0.50 green:0.68 blue:1.00 alpha:1]];
  [face addButton:@"square" label:@"Square" mask:pi::Square
            color:[UIColor colorWithRed:1.00 green:0.52 blue:0.86 alpha:1]];
  face.maskChanged = ^(uint16_t mask) {
    [weakSelf cluster:0 mask:mask];
  };
  OttselButtonCluster* dpad = [OttselButtonCluster new];
  UIColor* white = [UIColor colorWithWhite:0.92 alpha:1];
  [dpad addButton:@"arrowtriangle.up.fill" label:@"D-pad up" mask:pi::DpadUp color:white];
  [dpad addButton:@"arrowtriangle.right.fill" label:@"D-pad right" mask:pi::DpadRight color:white];
  [dpad addButton:@"arrowtriangle.down.fill" label:@"D-pad down" mask:pi::DpadDown color:white];
  [dpad addButton:@"arrowtriangle.left.fill" label:@"D-pad left" mask:pi::DpadLeft color:white];
  dpad.maskChanged = ^(uint16_t mask) {
    [weakSelf cluster:1 mask:mask];
  };

  NSDictionary<NSString*, UIView<OttselEditable>*>* controls = @{
    @"move" : move,
    @"camera" : camera,
    @"face" : face,
    @"dpad" : dpad,
    @"L1" : [self textButton:@"L1" mask:pi::L1],
    @"L2" : [self textButton:@"L2" mask:pi::L2],
    @"R1" : [self textButton:@"R1" mask:pi::R1],
    @"R2" : [self textButton:@"R2" mask:pi::R2],
    @"start" : [self textButton:@"START" mask:pi::Start],
  };
  for (const auto& d : kDefaults) {
    UIView<OttselEditable>* control = controls[d.ident];
    control.accessibilityIdentifier = d.ident;
    if (![control isKindOfClass:OttselButtonCluster.class]) control.accessibilityLabel = d.label;
    _byIdent[d.ident] = control;
    [_controls addSubview:control];
    UIPanGestureRecognizer* pan = [[UIPanGestureRecognizer alloc] initWithTarget:self
                                                                          action:@selector(dragged:)];
    UITapGestureRecognizer* tap = [[UITapGestureRecognizer alloc] initWithTarget:self
                                                                          action:@selector(tapped:)];
    pan.enabled = tap.enabled = NO;
    [control addGestureRecognizer:pan];
    [control addGestureRecognizer:tap];
  }
}

- (OttselPadButton*)textButton:(NSString*)title mask:(uint16_t)mask {
  OttselPadButton* button = [OttselPadButton buttonWithType:UIButtonTypeCustom];
  button.mask = mask;
  [button setTitle:title forState:UIControlStateNormal];
  [button setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
  button.titleLabel.font = [UIFont systemFontOfSize:17 weight:UIFontWeightBold];
  button.layer.borderWidth = 2.0;
  button.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.34].CGColor;
  [button releaseInput];
  [button addTarget:self action:@selector(buttonDown:) forControlEvents:UIControlEventTouchDown];
  [button addTarget:self
                action:@selector(buttonUp:)
      forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside |
                       UIControlEventTouchCancel];
  return button;
}

// MARK: Input

- (void)publish {
  _pad.buttons = (_pad.buttons & ~(uint16_t)(pi::Triangle | pi::Circle | pi::Cross | pi::Square |
                                             pi::DpadUp | pi::DpadRight | pi::DpadDown |
                                             pi::DpadLeft)) |
                 _clusterMasks[0] | _clusterMasks[1];
  if (g_hooks.pad_changed) g_hooks.pad_changed(_pad);
}

- (void)stick:(BOOL)camera x:(float)x y:(float)y {
  if (_editing) return;
  (camera ? _pad.rx : _pad.lx) = x;
  (camera ? _pad.ry : _pad.ly) = y;
  [self publish];
}

- (void)cluster:(int)index mask:(uint16_t)mask {
  _clusterMasks[index] = _editing ? 0 : mask;
  [self publish];
}

- (void)buttonDown:(OttselPadButton*)button {
  if (_editing) return;
  _pad.buttons |= button.mask;
  button.transform = CGAffineTransformMakeScale(0.92, 0.92);
  button.backgroundColor = [UIColor colorWithWhite:0.5 alpha:0.8];
  [_haptic impactOccurred];
  [self publish];
}

- (void)buttonUp:(OttselPadButton*)button {
  _pad.buttons &= ~button.mask;
  [button releaseInput];
  [self publish];
}

- (void)clearInput {
  for (UIView<OttselEditable>* control in _byIdent.allValues) [control releaseInput];
  _pad = {};
  _clusterMasks[0] = _clusterMasks[1] = 0;
  [self publish];
}

// MARK: Layout

- (CGRect)safeRect {
  return UIEdgeInsetsInsetRect(self.bounds, self.safeAreaInsets);
}

- (CGFloat)baseScale {
  CGRect safe = [self safeRect];
  // SunPad's rule: fixed sizes on iPad, scaled to an 800x380 reference area on phones.
  if (self.traitCollection.userInterfaceIdiom != UIUserInterfaceIdiomPhone) return 1.0;
  return 0.74 * std::min<CGFloat>(1.0, std::min(safe.size.width / 800.0, safe.size.height / 380.0));
}

- (CGFloat)sizeScaleFor:(NSString*)ident {
  NSNumber* each = [[NSUserDefaults.standardUserDefaults dictionaryForKey:kSizesKey] objectForKey:ident];
  NSNumber* all = [NSUserDefaults.standardUserDefaults objectForKey:kSizeScaleKey];
  CGFloat global = all && all.doubleValue >= 0.5 ? all.doubleValue : 1.0;
  return global * (each ? std::clamp(each.doubleValue, 0.6, 1.75) : 1.0);
}

- (void)layoutSubviews {
  [super layoutSubviews];
  CGRect safe = [self safeRect];
  CGFloat base = [self baseScale];
  NSDictionary* saved = [NSUserDefaults.standardUserDefaults dictionaryForKey:kCentersKey];
  for (const auto& d : kDefaults) {
    UIView* control = _byIdent[d.ident];
    if (control == _byIdent[@"move"] && _moveZone.tracking) continue;  // it sits under the thumb
    CGFloat scale = base * [self sizeScaleFor:d.ident];
    control.bounds = CGRectMake(0, 0, d.w * scale, d.h * scale);
    CGPoint n = CGPointMake(d.x, d.y);
    if (NSString* s = saved[d.ident]) n = CGPointFromString(s);
    CGFloat hw = std::min(control.bounds.size.width, safe.size.width) * 0.5;
    CGFloat hh = std::min(control.bounds.size.height, safe.size.height) * 0.5;
    CGFloat cx = CGRectGetMinX(safe) + std::clamp<CGFloat>(n.x, 0, 1) * safe.size.width;
    CGFloat cy = CGRectGetMinY(safe) + std::clamp<CGFloat>(n.y, 0, 1) * safe.size.height;
    control.center = CGPointMake(std::clamp(cx, CGRectGetMinX(safe) + hw, CGRectGetMaxX(safe) - hw),
                                 std::clamp(cy, CGRectGetMinY(safe) + hh, CGRectGetMaxY(safe) - hh));
    if ([control isKindOfClass:OttselPadButton.class]) {
      control.layer.cornerRadius = control.bounds.size.height * 0.5;
    }
  }
  // The floating stick's area: the left 45% of the screen below the D-pad.
  UIView* dpad = _byIdent[@"dpad"];
  CGFloat zoneTop = std::min(CGRectGetMaxY(dpad.frame), CGRectGetMinY(safe) + safe.size.height * 0.5);
  _moveZone.frame = CGRectMake(CGRectGetMinX(self.bounds), zoneTop,
                               CGRectGetMinX(safe) + safe.size.width * 0.45 - CGRectGetMinX(self.bounds),
                               CGRectGetMaxY(self.bounds) - zoneTop);
  _menuButton.frame = CGRectMake(CGRectGetMaxX(safe) - 52, CGRectGetMinY(safe) + 12, 40, 40);
  _fpsLabel.frame = CGRectMake(CGRectGetMinX(safe) + 12, CGRectGetMinY(safe) + 12, 96, 26);
  CGFloat pw = std::min<CGFloat>(360, safe.size.width - 32);
  CGFloat ph = std::min<CGFloat>(500, safe.size.height * 0.8);
  _panel.frame = CGRectMake(CGRectGetMaxX(safe) - pw - 12, CGRectGetMinY(safe) + 60, pw, ph);
  CGFloat ew = std::min<CGFloat>(560, safe.size.width - 24);
  _editorBar.frame = CGRectMake(CGRectGetMidX(safe) - ew * 0.5, CGRectGetMaxY(safe) - 72, ew, 60);
  [self updateEditingAppearance];
}

// MARK: Layout editing (SunPad: drag to move, tap to select and resize, Done)

- (void)setEditing:(BOOL)editing {
  [self clearInput];
  _editing = editing;
  _selected = nil;
  _editSwitch.on = editing;
  for (UIView<OttselEditable>* control in _byIdent.allValues) {
    control.editing = editing;
    for (UIGestureRecognizer* g in control.gestureRecognizers) g.enabled = editing;
  }
  _editorBar.hidden = !editing;
  if (editing) _panel.hidden = YES;
  _selectedSize.enabled = NO;
  _selectedSize.value = 1.0;
  _editorHint.text = @"Drag controls • tap one to resize";
  [self updateVisibility];
  [self updateStickMode];
  [self updateEditingAppearance];
}

- (void)updateEditingAppearance {
  for (UIView* control in _byIdent.allValues) {
    if (_editing) {
      control.layer.borderWidth = control == _selected ? 4 : 3;
      control.layer.borderColor = border_color(control == _selected).CGColor;
    } else {
      control.layer.borderWidth = [control isKindOfClass:OttselButtonCluster.class] ? 0 : 2;
      control.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.34].CGColor;
    }
    if ([control isKindOfClass:OttselButtonCluster.class]) {
      control.layer.cornerRadius = 18;
    }
  }
  _controls.alpha = _editing ? 1.0 : [self opacity];
}

- (void)select:(UIView*)control {
  _selected = control;
  _selectedSize.enabled = YES;
  NSNumber* each =
      [[NSUserDefaults.standardUserDefaults dictionaryForKey:kSizesKey] objectForKey:control.accessibilityIdentifier];
  _selectedSize.value = each ? each.floatValue : 1.0f;
  NSString* name = control.accessibilityLabel;
  for (const auto& d : kDefaults) {
    if ([d.ident isEqualToString:control.accessibilityIdentifier]) name = d.label;
  }
  _editorHint.text = [NSString stringWithFormat:@"%@ size", name];
  [self updateEditingAppearance];
}

- (void)tapped:(UITapGestureRecognizer*)tap {
  if (tap.state == UIGestureRecognizerStateEnded) [self select:tap.view];
}

- (void)dragged:(UIPanGestureRecognizer*)pan {
  UIView* control = pan.view;
  if (pan.state == UIGestureRecognizerStateBegan) [self select:control];
  CGPoint t = [pan translationInView:self];
  CGRect safe = [self safeRect];
  CGFloat hw = control.bounds.size.width * 0.5, hh = control.bounds.size.height * 0.5;
  control.center = CGPointMake(
      std::clamp(control.center.x + t.x, CGRectGetMinX(safe) + hw, CGRectGetMaxX(safe) - hw),
      std::clamp(control.center.y + t.y, CGRectGetMinY(safe) + hh, CGRectGetMaxY(safe) - hh));
  [pan setTranslation:CGPointZero inView:self];
  if (pan.state == UIGestureRecognizerStateEnded || pan.state == UIGestureRecognizerStateCancelled) {
    CGPoint n = CGPointMake((control.center.x - CGRectGetMinX(safe)) / safe.size.width,
                            (control.center.y - CGRectGetMinY(safe)) / safe.size.height);
    NSMutableDictionary* saved =
        [[NSUserDefaults.standardUserDefaults dictionaryForKey:kCentersKey] mutableCopy]
            ?: [NSMutableDictionary dictionary];
    saved[control.accessibilityIdentifier] = NSStringFromCGPoint(n);
    [NSUserDefaults.standardUserDefaults setObject:saved forKey:kCentersKey];
  }
}

- (void)selectedSizeChanged:(UISlider*)slider {
  NSString* ident = _selected.accessibilityIdentifier;
  if (!_editing || ident.length == 0) return;
  NSMutableDictionary* sizes = [[NSUserDefaults.standardUserDefaults dictionaryForKey:kSizesKey] mutableCopy]
                                   ?: [NSMutableDictionary dictionary];
  sizes[ident] = @(slider.value);
  [NSUserDefaults.standardUserDefaults setObject:sizes forKey:kSizesKey];
  [self setNeedsLayout];
}

- (void)buildEditorBar {
  _editorBar = [OttselPassThroughView new];
  _editorBar.backgroundColor = [UIColor colorWithWhite:0.035 alpha:0.95];
  _editorBar.layer.cornerRadius = 16;
  _editorBar.layer.borderWidth = 1;
  _editorBar.layer.borderColor = border_color(false).CGColor;
  _editorBar.hidden = YES;
  _editorBar.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;
  [self addSubview:_editorBar];

  _editorHint = [UILabel new];
  _editorHint.textColor = UIColor.whiteColor;
  _editorHint.font = [UIFont systemFontOfSize:14 weight:UIFontWeightSemibold];
  _editorHint.adjustsFontSizeToFitWidth = YES;
  _editorHint.minimumScaleFactor = 0.75;
  _selectedSize = [UISlider new];
  _selectedSize.minimumValue = 0.6;
  _selectedSize.maximumValue = 1.75;
  _selectedSize.accessibilityLabel = @"Selected control size";
  [_selectedSize addTarget:self action:@selector(selectedSizeChanged:)
          forControlEvents:UIControlEventValueChanged];
  UIButton* done = [UIButton buttonWithType:UIButtonTypeSystem];
  [done setTitle:@"Done" forState:UIControlStateNormal];
  [done setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
  done.titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightBold];
  done.backgroundColor = [UIColor colorWithRed:0.12 green:0.48 blue:0.82 alpha:1.0];
  done.layer.cornerRadius = 10;
  done.accessibilityLabel = @"Finish moving touch controls";
  [done addTarget:self action:@selector(finishEditing) forControlEvents:UIControlEventTouchUpInside];

  UIStackView* stack = [[UIStackView alloc] initWithArrangedSubviews:@[ _editorHint, _selectedSize, done ]];
  stack.translatesAutoresizingMaskIntoConstraints = NO;
  stack.alignment = UIStackViewAlignmentCenter;
  stack.spacing = 12;
  [_editorBar addSubview:stack];
  [_editorHint setContentCompressionResistancePriority:UILayoutPriorityDefaultLow
                                               forAxis:UILayoutConstraintAxisHorizontal];
  [NSLayoutConstraint activateConstraints:@[
    [stack.leadingAnchor constraintEqualToAnchor:_editorBar.leadingAnchor constant:14],
    [stack.trailingAnchor constraintEqualToAnchor:_editorBar.trailingAnchor constant:-10],
    [stack.topAnchor constraintEqualToAnchor:_editorBar.topAnchor constant:8],
    [stack.bottomAnchor constraintEqualToAnchor:_editorBar.bottomAnchor constant:-8],
    [_selectedSize.widthAnchor constraintGreaterThanOrEqualToConstant:150],
    [done.widthAnchor constraintEqualToConstant:68],
    [done.heightAnchor constraintEqualToConstant:40],
  ]];
}

- (void)finishEditing {
  [self setEditing:NO];
}

// MARK: Appearance and visibility

- (CGFloat)opacity {
  NSNumber* opacity = [NSUserDefaults.standardUserDefaults objectForKey:kOpacityKey];
  return opacity ? std::clamp(opacity.doubleValue, 0.25, 1.0) : 0.8;
}

- (void)applyAppearance {
  _opacitySlider.value = [self opacity];
  NSNumber* size = [NSUserDefaults.standardUserDefaults objectForKey:kSizeScaleKey];
  _sizeSlider.value = size && size.doubleValue >= 0.5 ? size.floatValue : 1.0f;
  _showControl.selectedSegmentIndex = std::clamp(setting("controls"), 0, 2);
  _cameraSlider.value = setting("camera_sensitivity");
  _invertSwitch.on = setting("invert_camera_y") != 0;
  _floatSwitch.on = [self floatingStick];
  [self updateStickMode];
  [self updateFPSVisibility];
  [self updateVisibility];
  [self setNeedsLayout];
}

- (BOOL)floatingStick {
  NSNumber* on = [NSUserDefaults.standardUserDefaults objectForKey:kFloatingKey];
  return on ? on.boolValue : YES;
}

// Floating: the stick is invisible until a thumb lands in its area. Fixed (or while editing the
// layout): the stick is always drawn at its saved place and takes its own touches.
- (void)updateStickMode {
  UIView* move = _byIdent[@"move"];
  const BOOL floating = [self floatingStick] && !_editing;
  _moveZone.hidden = !floating;
  move.userInteractionEnabled = !floating;
  move.alpha = floating ? 0.0 : 1.0;
  if (!floating) [self setNeedsLayout];  // back to its saved place
}

- (void)setControlsHidden:(BOOL)hidden {
  _hiddenByInput = hidden;
  [self updateVisibility];
}

- (void)updateVisibility {
  const int mode = setting("controls");
  const BOOL hidden = !_editing && (mode == 2 || (mode == 0 && _hiddenByInput));
  if (hidden && !_controls.hidden) [self clearInput];
  _controls.hidden = hidden;
}

// MARK: FPS counter

- (void)buildFPSLabel {
  _fpsLabel = [UILabel new];
  _fpsLabel.font = [UIFont monospacedDigitSystemFontOfSize:14 weight:UIFontWeightSemibold];
  _fpsLabel.textColor = UIColor.whiteColor;
  _fpsLabel.textAlignment = NSTextAlignmentCenter;
  _fpsLabel.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.55];
  _fpsLabel.layer.cornerRadius = 8;
  _fpsLabel.clipsToBounds = YES;
  _fpsLabel.accessibilityIdentifier = @"fps";
  _fpsLabel.hidden = YES;
  [self addSubview:_fpsLabel];
}

- (void)updateFPSVisibility {
  const BOOL show = [NSUserDefaults.standardUserDefaults boolForKey:kShowFPSKey];
  _fpsLabel.hidden = !show;
  [_fpsTimer invalidate];
  _fpsTimer = nil;
  if (!show) return;
  __weak UILabel* label = _fpsLabel;
  _fpsTimer = [NSTimer scheduledTimerWithTimeInterval:0.5 repeats:YES block:^(NSTimer*) {
    label.text = [NSString stringWithFormat:@"%.0f FPS", g_hooks.fps ? g_hooks.fps() : 0.0];
  }];
  [_fpsTimer fire];
}

// MARK: Touch Control Settings panel

- (UIView*)row:(NSString*)title control:(UIView*)control {
  UILabel* label = [UILabel new];
  label.text = title;
  label.textColor = UIColor.whiteColor;
  label.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
  [control setContentHuggingPriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];
  [label setContentHuggingPriority:UILayoutPriorityDefaultHigh forAxis:UILayoutConstraintAxisHorizontal];
  UIStackView* row = [[UIStackView alloc] initWithArrangedSubviews:@[ label, control ]];
  row.spacing = 12;
  row.alignment = UIStackViewAlignmentCenter;
  [row.heightAnchor constraintGreaterThanOrEqualToConstant:40].active = YES;
  return row;
}

- (UISlider*)slider:(float)min max:(float)max label:(NSString*)label action:(SEL)action {
  UISlider* slider = [UISlider new];
  slider.minimumValue = min;
  slider.maximumValue = max;
  slider.accessibilityLabel = label;
  [slider addTarget:self action:action forControlEvents:UIControlEventValueChanged];
  return slider;
}

- (void)buildPanel {
  _panel = [UIView new];
  _panel.backgroundColor = [UIColor colorWithWhite:0.035 alpha:0.94];
  _panel.layer.cornerRadius = 16;
  _panel.layer.borderWidth = 1;
  _panel.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.22].CGColor;
  _panel.hidden = YES;
  _panel.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;
  [self addSubview:_panel];

  UILabel* title = [UILabel new];
  title.text = @"Touch Control Settings";
  title.textColor = UIColor.whiteColor;
  title.font = [UIFont systemFontOfSize:18 weight:UIFontWeightBold];
  UIButton* close = [UIButton buttonWithType:UIButtonTypeCustom];
  [close setImage:[UIImage systemImageNamed:@"xmark"
                          withConfiguration:[UIImageSymbolConfiguration
                                                configurationWithPointSize:16
                                                                    weight:UIImageSymbolWeightBold]]
         forState:UIControlStateNormal];
  close.tintColor = UIColor.whiteColor;
  close.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.14];
  close.layer.cornerRadius = 16;
  close.accessibilityLabel = @"Close touch control settings";
  [close addTarget:self action:@selector(closePanel) forControlEvents:UIControlEventTouchUpInside];
  UIStackView* header = [[UIStackView alloc] initWithArrangedSubviews:@[ title, close ]];
  header.translatesAutoresizingMaskIntoConstraints = NO;
  header.alignment = UIStackViewAlignmentCenter;
  header.spacing = 12;
  [_panel addSubview:header];

  _showControl = [[UISegmentedControl alloc] initWithItems:@[ @"Auto", @"Always", @"Never" ]];
  _showControl.accessibilityLabel = @"Show touch controls";
  [_showControl addTarget:self action:@selector(showChanged:) forControlEvents:UIControlEventValueChanged];
  _opacitySlider = [self slider:0.25 max:1.0 label:@"Control opacity" action:@selector(opacityChanged:)];
  _sizeSlider = [self slider:0.7 max:1.35 label:@"Control size" action:@selector(sizeChanged:)];
  _cameraSlider = [self slider:50 max:200 label:@"Camera speed" action:@selector(cameraChanged:)];
  _invertSwitch = [UISwitch new];
  _invertSwitch.accessibilityLabel = @"Invert camera up and down";
  [_invertSwitch addTarget:self action:@selector(invertChanged:) forControlEvents:UIControlEventValueChanged];
  _floatSwitch = [UISwitch new];
  _floatSwitch.accessibilityLabel = @"Move stick follows thumb";
  [_floatSwitch addTarget:self action:@selector(floatChanged:) forControlEvents:UIControlEventValueChanged];
  _editSwitch = [UISwitch new];
  _editSwitch.accessibilityLabel = @"Move touch controls";
  [_editSwitch addTarget:self action:@selector(editChanged:) forControlEvents:UIControlEventValueChanged];
  UIButton* reset = [UIButton buttonWithType:UIButtonTypeSystem];
  [reset setTitle:@"Reset This Device Layout" forState:UIControlStateNormal];
  [reset setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
  reset.titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
  reset.backgroundColor = [UIColor colorWithWhite:0.18 alpha:0.88];
  reset.layer.cornerRadius = 10;
  [reset addTarget:self action:@selector(confirmReset) forControlEvents:UIControlEventTouchUpInside];

  UILabel* note = [UILabel new];
  note.text = @"Auto hides the controls while a controller or keyboard is in use and brings them "
              @"back on your next touch.";
  note.numberOfLines = 0;
  note.textColor = [UIColor colorWithWhite:1.0 alpha:0.6];
  note.font = [UIFont systemFontOfSize:12];
  UILabel* floatNote = [UILabel new];
  floatNote.text = @"On: the move stick appears wherever your left thumb lands. Off: it stays in one "
                   @"place.";
  floatNote.numberOfLines = 0;
  floatNote.textColor = note.textColor;
  floatNote.font = note.font;

  UIStackView* stack = [[UIStackView alloc] initWithArrangedSubviews:@[
    [self row:@"Show" control:_showControl], note,
    [self row:@"Stick follows thumb" control:_floatSwitch], floatNote,
    [self row:@"Opacity" control:_opacitySlider],
    [self row:@"All sizes" control:_sizeSlider], [self row:@"Camera speed" control:_cameraSlider],
    [self row:@"Invert camera Y" control:_invertSwitch], [self row:@"Move controls" control:_editSwitch],
    reset
  ]];
  stack.translatesAutoresizingMaskIntoConstraints = NO;
  stack.axis = UILayoutConstraintAxisVertical;
  stack.spacing = 6;
  UIScrollView* scroll = [UIScrollView new];
  scroll.translatesAutoresizingMaskIntoConstraints = NO;
  [_panel addSubview:scroll];
  [scroll addSubview:stack];
  [NSLayoutConstraint activateConstraints:@[
    [header.leadingAnchor constraintEqualToAnchor:_panel.leadingAnchor constant:16],
    [header.trailingAnchor constraintEqualToAnchor:_panel.trailingAnchor constant:-12],
    [header.topAnchor constraintEqualToAnchor:_panel.topAnchor constant:8],
    [header.heightAnchor constraintEqualToConstant:40],
    [close.widthAnchor constraintEqualToConstant:32],
    [close.heightAnchor constraintEqualToConstant:32],
    [scroll.leadingAnchor constraintEqualToAnchor:_panel.leadingAnchor],
    [scroll.trailingAnchor constraintEqualToAnchor:_panel.trailingAnchor],
    [scroll.topAnchor constraintEqualToAnchor:header.bottomAnchor constant:2],
    [scroll.bottomAnchor constraintEqualToAnchor:_panel.bottomAnchor],
    [stack.leadingAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.leadingAnchor constant:16],
    [stack.trailingAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.trailingAnchor constant:-16],
    [stack.topAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.topAnchor constant:8],
    [stack.bottomAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.bottomAnchor constant:-8],
    [stack.widthAnchor constraintEqualToAnchor:scroll.frameLayoutGuide.widthAnchor constant:-32],
    [reset.heightAnchor constraintEqualToConstant:40],
  ]];
}

- (void)openPanel {
  if (_editing) [self setEditing:NO];
  [self applyAppearance];
  _panel.hidden = NO;
  [self bringSubviewToFront:_panel];
  [self bringSubviewToFront:_menuButton];
}

- (void)closePanel {
  _panel.hidden = YES;
}

- (void)showChanged:(UISegmentedControl*)control {
  set_setting("controls", (int)control.selectedSegmentIndex);
  [self updateVisibility];
  [self refreshMenu];
}

- (void)opacityChanged:(UISlider*)slider {
  [NSUserDefaults.standardUserDefaults setDouble:slider.value forKey:kOpacityKey];
  [self updateEditingAppearance];
}

- (void)sizeChanged:(UISlider*)slider {
  [NSUserDefaults.standardUserDefaults setDouble:slider.value forKey:kSizeScaleKey];
  [self setNeedsLayout];
}

- (void)cameraChanged:(UISlider*)slider {
  const int value = (int)std::lround(slider.value / 5.0) * 5;
  slider.value = value;
  set_setting("camera_sensitivity", value);
}

- (void)invertChanged:(UISwitch*)switcher {
  set_setting("invert_camera_y", switcher.on ? 1 : 0);
}

- (void)floatChanged:(UISwitch*)switcher {
  [self clearInput];
  [NSUserDefaults.standardUserDefaults setBool:switcher.on forKey:kFloatingKey];
  [self updateStickMode];
}

- (void)editChanged:(UISwitch*)switcher {
  [self setEditing:switcher.on];
}

- (void)confirmReset {
  __weak OttselTouchOverlay* weakSelf = self;
  UIAlertController* alert = [UIAlertController
      alertControllerWithTitle:@"Reset Touch Control Layout?"
                       message:@"All control positions and sizes, opacity and overall size return to "
                               @"their defaults."
                preferredStyle:UIAlertControllerStyleAlert];
  [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
  [alert addAction:[UIAlertAction actionWithTitle:@"Reset"
                                            style:UIAlertActionStyleDestructive
                                          handler:^(UIAlertAction*) {
                                            [weakSelf resetLayout];
                                          }]];
  [self present:alert];
}

- (void)resetLayout {
  for (NSString* key in @[ kCentersKey, kSizesKey, kOpacityKey, kSizeScaleKey ]) {
    [NSUserDefaults.standardUserDefaults removeObjectForKey:key];
  }
  [self applyAppearance];
}

- (void)present:(UIViewController*)controller {
  UIViewController* presenter = self.window.rootViewController;
  while (presenter.presentedViewController) presenter = presenter.presentedViewController;
  controller.popoverPresentationController.sourceView = _menuButton;
  [presenter presentViewController:controller animated:YES completion:nil];
}

// MARK: Game data import (Files -> Documents/OttselUserData, validated on the next launch)

- (void)importGameData {
  UIDocumentPickerViewController* picker =
      [[UIDocumentPickerViewController alloc] initForOpeningContentTypes:@[ UTTypeFolder ]];
  picker.delegate = self;
  [self present:picker];
}

- (void)documentPicker:(UIDocumentPickerViewController*)controller
    didPickDocumentsAtURLs:(NSArray<NSURL*>*)urls {
  NSURL* source = urls.firstObject;
  if (!source) return;
  const BOOL scoped = [source startAccessingSecurityScopedResource];
  NSFileManager* files = NSFileManager.defaultManager;
  NSURL* documents = [files URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask].firstObject;
  NSURL* destination = [documents URLByAppendingPathComponent:@"OttselUserData"];
  NSError* error = nil;
  const BOOL looks_like_pack = [files fileExistsAtPath:[source URLByAppendingPathComponent:@"manifest.txt"].path];
  if (looks_like_pack) {
    [files removeItemAtURL:destination error:nil];
    [files copyItemAtURL:source toURL:destination error:&error];
  }
  if (scoped) [source stopAccessingSecurityScopedResource];
  NSString* message =
      !looks_like_pack ? @"That folder is not an Ottsel game-data pack. Choose the OttselUserData folder "
                         @"made by scripts/prepare-user-data-pack.sh from your own Jak and Daxter disc."
      : error ? [NSString stringWithFormat:@"Copying failed: %@", error.localizedDescription]
              : @"Close and reopen Ottsel. It checks the pack on launch and keeps it for later launches.";
  UIAlertController* alert =
      [UIAlertController alertControllerWithTitle:looks_like_pack && !error ? @"Game Data Copied"
                                                                            : @"Game Data Not Imported"
                                          message:message
                                   preferredStyle:UIAlertControllerStyleAlert];
  [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
  [self present:alert];
}

// MARK: Diagnostics

- (void)shareLogs {
  NSString* dir = g_hooks.log_dir ? @(g_hooks.log_dir) : @"";
  NSMutableArray* items = [NSMutableArray array];
  for (NSString* name in @[ @"ottsel-runtime.log", @"ottsel-fault.log" ]) {
    NSString* path = [dir stringByAppendingPathComponent:name];
    if ([NSFileManager.defaultManager fileExistsAtPath:path]) [items addObject:[NSURL fileURLWithPath:path]];
  }
  if (items.count == 0) return;
  [self present:[[UIActivityViewController alloc] initWithActivityItems:items applicationActivities:nil]];
}

// MARK: Three-dot menu (SunPad's structure: Display, FPS counter, Controls, Game Data, Diagnostics)

- (void)buildMenuButton {
  UIButtonConfiguration* config = [UIButtonConfiguration plainButtonConfiguration];
  config.image = [UIImage systemImageNamed:@"ellipsis"
                         withConfiguration:[UIImageSymbolConfiguration
                                               configurationWithPointSize:19
                                                                   weight:UIImageSymbolWeightBold]];
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

- (void)refreshMenu {
  _menuButton.menu = [self buildMenu];
}

- (UIAction*)action:(NSString*)title symbol:(NSString*)symbol handler:(void (^)(void))handler {
  return [UIAction actionWithTitle:title
                             image:symbol ? [UIImage systemImageNamed:symbol] : nil
                        identifier:nil
                           handler:^(UIAction*) { handler(); }];
}

- (UIMenu*)buildMenu {
  return [self buildMenuElements];
}

- (void)jumpTo:(NSString*)continueName {
  if (!g_hooks.log_dir) return;
  NSString* path = [@(g_hooks.log_dir) stringByAppendingString:@"ottsel-warp"];
  [continueName writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:nil];
}

- (UIMenu*)buildMenuElements {
  __weak OttselTouchOverlay* weakSelf = self;
  NSMutableArray* render = [NSMutableArray array];
  const int scale = setting("render_scale");
  for (NSNumber* value in @[ @100, @75, @50 ]) {
    const int v = value.intValue;
    UIAction* choice = [self action:v == 100 ? @"Native" : [NSString stringWithFormat:@"%d%%", v]
                             symbol:nil
                            handler:^{
                              set_setting("render_scale", v);
                              [weakSelf refreshMenu];
                            }];
    choice.state = scale == v ? UIMenuElementStateOn : UIMenuElementStateOff;
    [render addObject:choice];
  }
  UIMenu* display = [UIMenu menuWithTitle:@"Display"
                                    image:[UIImage systemImageNamed:@"display"]
                               identifier:nil
                                  options:0
                                 children:@[ [UIMenu menuWithTitle:@"Render Resolution"
                                                             image:nil
                                                        identifier:nil
                                                           options:UIMenuOptionsSingleSelection
                                                          children:render] ]];

  UIAction* fps = [self action:@"Show FPS Counter" symbol:@"speedometer" handler:^{
    NSUserDefaults* d = NSUserDefaults.standardUserDefaults;
    [d setBool:![d boolForKey:kShowFPSKey] forKey:kShowFPSKey];
    [weakSelf updateFPSVisibility];
    [weakSelf refreshMenu];
  }];
  fps.state = [NSUserDefaults.standardUserDefaults boolForKey:kShowFPSKey] ? UIMenuElementStateOn
                                                                           : UIMenuElementStateOff;

  UIMenu* controls = [UIMenu
      menuWithTitle:@"Controls"
              image:[UIImage systemImageNamed:@"gamecontroller"]
         identifier:nil
            options:0
           children:@[
             [self action:@"Touch Control Settings…" symbol:@"slider.horizontal.3"
                  handler:^{ [weakSelf openPanel]; }],
             [self action:@"Move Touch Controls" symbol:@"hand.draw"
                  handler:^{ [weakSelf setEditing:YES]; }],
           ]];

  const bool has_data = g_hooks.has_game_data && g_hooks.has_game_data();
  UIAction* status = [self action:has_data ? @"Game Data Installed" : @"No Game Data Yet"
                           symbol:has_data ? @"checkmark.circle" : @"exclamationmark.circle"
                          handler:^{}];
  status.attributes = UIMenuElementAttributesDisabled;
  UIMenu* data = [UIMenu menuWithTitle:@"Game Data"
                                 image:[UIImage systemImageNamed:@"internaldrive"]
                            identifier:nil
                               options:0
                              children:@[
                                status,
                                [self action:@"Import Game Data…" symbol:@"square.and.arrow.down"
                                     handler:^{ [weakSelf importGameData]; }],
                              ]];

  UIAction* log = [self action:@"Show Log Over Game" symbol:@"text.alignleft" handler:^{
    set_setting("log_overlay", setting("log_overlay") ? 0 : 1);
    [weakSelf refreshMenu];
  }];
  log.state = setting("log_overlay") ? UIMenuElementStateOn : UIMenuElementStateOff;
  // Testing: start play at a level's own continue point (the game's respawn path), with this
  // session's progress. game/sce/libpad.cpp reads the request; main.gc starts play there.
  static const struct {
    NSString* title;
    const char* name;
  } kLevels[] = {
      {@"Geyser Rock", "training-start"},     {@"Sandover Village", "village1-hut"},
      {@"Forbidden Jungle", "jungle-start"},  {@"Sentinel Beach", "beach-start"},
      {@"Misty Island", "misty-start"},       {@"Fire Canyon", "firecanyon-start"},
      {@"Rock Village", "village2-start"},    {@"Precursor Basin", "rolling-start"},
      {@"Boggy Swamp", "swamp-start"},        {@"Lost Precursor City", "sunken-start"},
      {@"Mountain Pass", "ogre-start"},       {@"Volcanic Crater", "village3-start"},
      {@"Spider Cave", "maincave-start"},     {@"Snowy Mountain", "snow-start"},
      {@"Lava Tube", "lavatube-start"},       {@"Gol and Maia's Citadel", "citadel-start"},
  };
  NSMutableArray<UIMenuElement*>* levels = [NSMutableArray array];
  for (const auto& level : kLevels) {
    NSString* name = @(level.name);
    [levels addObject:[self action:level.title symbol:nil handler:^{ [weakSelf jumpTo:name]; }]];
  }
  UIMenu* jump = [UIMenu menuWithTitle:@"Jump to Level (Testing)"
                                 image:[UIImage systemImageNamed:@"arrow.triangle.turn.up.right.diamond"]
                            identifier:nil
                               options:0
                              children:levels];
  UIMenu* diagnostics = [UIMenu menuWithTitle:@"Diagnostics"
                                        image:[UIImage systemImageNamed:@"stethoscope"]
                                   identifier:nil
                                      options:0
                                     children:@[
                                       log, jump,
                                       [self action:@"Share Logs…" symbol:@"square.and.arrow.up"
                                            handler:^{ [weakSelf shareLogs]; }],
                                     ]];
  return [UIMenu menuWithTitle:@"Ottsel"
                      children:@[ display, fps, controls, [self cheatsMenu], data, diagnostics ]];
}

// OpenGOAL's own cheats (Secrets → Cheats in the game), switched on without typing a button code. The
// list is built each time it opens, so its checkmarks follow changes made in the game's menu too.
- (UIMenu*)cheatsMenu {
  static const struct {
    NSString* title;
    int bit;  // pc-cheats bit (goal_src/jak1/pc/pc-cheats.gc)
  } kCheats[] = {
      {@"Invincibility", 4},         {@"Infinite Blue Eco", 2},  {@"Infinite Yellow Eco", 3},
      {@"Infinite Red Eco", 1},      {@"Infinite Green Eco", 0}, {@"Big Head Jak", 9},
      {@"Huge Head Jak", 15},        {@"Small Head Jak", 10},    {@"Big Fist Jak", 11},
      {@"Big Head Villagers", 16},   {@"Blue Daxter", 5},        {@"Mirror World", 8},
      {@"Real-Time Sky", 7},         {@"All Music Flavors", 6},
  };
  UIDeferredMenuElement* list = [UIDeferredMenuElement elementWithUncachedProvider:^(
                                                           void (^completion)(NSArray<UIMenuElement*>*)) {
    const unsigned on = g_ottsel_cheats_on.load();
    NSMutableArray<UIMenuElement*>* items = [NSMutableArray array];
    for (const auto& cheat : kCheats) {
      const int bit = cheat.bit;
      UIAction* action = [UIAction actionWithTitle:cheat.title
                                             image:nil
                                        identifier:nil
                                           handler:^(UIAction*) { g_ottsel_cheat_request = bit; }];
      action.state = (on >> bit) & 1 ? UIMenuElementStateOn : UIMenuElementStateOff;
      [items addObject:action];
    }
    completion(items);
  }];
  return [UIMenu menuWithTitle:@"Cheats"
                         image:[UIImage systemImageNamed:@"wand.and.stars"]
                    identifier:nil
                       options:0
                      children:@[ list ]];
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

void ottsel_touch_set_tv_mode(bool on_tv) {
  [g_overlay setTVMode:on_tv];
}
