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
  if (screen.preferredMode && screen.currentMode != screen.preferredMode) {
    screen.currentMode = screen.preferredMode;
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
}

- (void)sceneDidDisconnect:(UIScene*)scene {
  lg::info("OTTSEL DISPLAY: external screen disconnected");
  render_on_ipad();
  self.window = nil;
}
@end

void ottsel_external_display_install() {
  g_renderer_ready = true;
  render_on_tv();
}
