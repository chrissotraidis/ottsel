#import "external_display.h"

#import <QuartzCore/CAMetalLayer.h>
#import <UIKit/UIKit.h>

#include "common/log/log.h"
#include "game/graphics/pipelines/ottsel_gl_view.h"
#include "touch_controls.h"

namespace {
UIWindow* g_tv_window = nil;  // full-screen window in the external display's scene
bool g_renderer_ready = false;
bool g_on_tv = false;
}  // namespace

// A view backed by a CAMetalLayer, which ANGLE renders into. A TV often connects in a small mode
// and switches to its real resolution a moment later, so a size change rebuilds the render surface.
@interface OttselMetalView : UIView
@end
@implementation OttselMetalView {
  CGSize _renderedSize;
}
+ (Class)layerClass {
  return CAMetalLayer.class;
}
- (void)layoutSubviews {
  [super layoutSubviews];
  if (!g_on_tv || CGSizeEqualToSize(self.bounds.size, _renderedSize)) return;
  _renderedSize = self.bounds.size;
  ottsel_gl_retarget((__bridge void*)self.layer);
}
@end

namespace {
// Move rendering to the TV once both the TV window and the renderer exist (either can come first).
void render_on_tv() {
  if (!g_renderer_ready || g_on_tv || !g_tv_window) return;
  [g_tv_window layoutIfNeeded];
  if (!ottsel_gl_retarget((__bridge void*)g_tv_window.rootViewController.view.layer)) return;
  g_on_tv = true;
  ottsel_touch_set_tv_mode(true);
}

void render_on_ipad() {
  if (g_on_tv) {
    ottsel_gl_retarget(nullptr);
    ottsel_touch_set_tv_mode(false);
    g_on_tv = false;
  }
  g_tv_window.hidden = YES;
  g_tv_window = nil;
}
}  // namespace

// iOS connects an external display (HDMI, USB-C, AirPlay) as its own scene; SDL's app delegate hands
// that scene to this class (see OpenGOAL's patched third-party/SDL/.../SDL_uikitappdelegate.m).
@interface OttselExternalSceneDelegate : UIResponder <UIWindowSceneDelegate>
@property(nonatomic, strong) UIWindow* window;
@property(nonatomic, strong) NSTimer* sizeWatch;
@end

@implementation OttselExternalSceneDelegate
- (void)scene:(UIScene*)scene
    willConnectToSession:(UISceneSession*)session
                 options:(UISceneConnectionOptions*)options {
  if (![scene isKindOfClass:UIWindowScene.class]) return;
  UIWindowScene* windowScene = (UIWindowScene*)scene;
  // An external screen can start in a low mode (720x480); use the mode the display prefers.
  UIScreen* screen = windowScene.screen;
  NSMutableString* modes = [NSMutableString string];
  for (UIScreenMode* mode in screen.availableModes) {
    [modes appendFormat:@" %dx%d", (int)mode.size.width, (int)mode.size.height];
  }
  lg::info("OTTSEL DISPLAY: modes current={}x{} preferred={}x{} available:{}",
           (int)screen.currentMode.size.width, (int)screen.currentMode.size.height,
           (int)screen.preferredMode.size.width, (int)screen.preferredMode.size.height,
           modes.UTF8String);
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
  // The display's preferred mode, unless it is below 720p (the Simulator, some adapters) and a
  // better one exists; then the largest mode up to 1080p, which a 60 Hz game fills without a 4K cost.
  UIScreenMode* chosen = screen.preferredMode;
  if (!chosen || chosen.size.height < 720) {
    for (UIScreenMode* mode in screen.availableModes) {
      if (mode.size.height <= 1080 && (!chosen || mode.size.height > chosen.size.height)) chosen = mode;
    }
  }
  if (chosen && screen.currentMode != chosen) {
    screen.currentMode = chosen;
    lg::info("OTTSEL DISPLAY: switched to {}x{} (now {}x{})", (int)chosen.size.width,
             (int)chosen.size.height, (int)screen.currentMode.size.width,
             (int)screen.currentMode.size.height);
  }
#pragma clang diagnostic pop
  UIWindow* window = [[UIWindow alloc] initWithWindowScene:windowScene];
  OttselMetalView* view = [[OttselMetalView alloc] initWithFrame:window.bounds];
  view.backgroundColor = UIColor.blackColor;
  view.contentScaleFactor = windowScene.screen.scale;
  view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
  UIViewController* controller = [UIViewController new];
  controller.view = view;
  window.rootViewController = controller;
  window.hidden = NO;
  self.window = window;
  g_tv_window = window;
  lg::info("OTTSEL DISPLAY: external screen connected {}x{} @{}x", (int)window.bounds.size.width,
           (int)window.bounds.size.height, windowScene.screen.scale);
  render_on_tv();
  // A TV can switch modes after connecting (720x480, then its real 1080p or 4K) without the scene's
  // window being resized. Keep the window on the screen's current size; the view then rebuilds the
  // render surface (OttselMetalView layoutSubviews).
  __weak OttselExternalSceneDelegate* weakSelf = self;
  self.sizeWatch = [NSTimer scheduledTimerWithTimeInterval:0.5
                                                   repeats:YES
                                                     block:^(NSTimer*) { [weakSelf followScreenSize]; }];
}

- (void)followScreenSize {
  UIWindowScene* scene = self.window.windowScene;
  if (!scene) return;
  const CGRect bounds = scene.screen.bounds;
  if (CGRectEqualToRect(self.window.frame, bounds)) return;
  lg::info("OTTSEL DISPLAY: external screen is now {}x{}", (int)bounds.size.width,
           (int)bounds.size.height);
  self.window.frame = bounds;
  [self.window layoutIfNeeded];
}

- (void)windowScene:(UIWindowScene*)windowScene
    didUpdateCoordinateSpace:(id<UICoordinateSpace>)previousCoordinateSpace
        interfaceOrientation:(UIInterfaceOrientation)previousInterfaceOrientation
             traitCollection:(UITraitCollection*)previousTraitCollection {
  [self followScreenSize];
}

- (void)sceneDidDisconnect:(UIScene*)scene {
  lg::info("OTTSEL DISPLAY: external screen disconnected");
  [self.sizeWatch invalidate];
  self.sizeWatch = nil;
  render_on_ipad();
  self.window = nil;
}
@end

void ottsel_external_display_install() {
  g_renderer_ready = true;
  render_on_tv();
}
