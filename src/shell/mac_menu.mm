// Ottsel's menus on the Mac: the iPad's three-dot menu (src/shell/touch_controls.mm) as the menu bar, on
// the same shell settings. A Mac plays with a keyboard, mouse or controller, so there are no touch controls
// and no TV mode; those entry points do nothing here.
#import "touch_controls.h"
#import "external_display.h"

#import <AppKit/AppKit.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

#include <SDL3/SDL.h>

#include <atomic>

// game/sce/libpad.cpp: the cheat to toggle (a pc-cheats bit, -1 none) and the cheats that are on.
extern std::atomic<int> g_ottsel_cheat_request;
extern std::atomic<unsigned> g_ottsel_cheats_on;

namespace {
OttselTouchHooks g_hooks{};
SDL_Window* g_window = nullptr;
NSString* const kShowFPSKey = @"OttselShowFPS";
NSString* const kGitHubURL = @"https://github.com/chrissotraidis/ottsel";
NSString* const kDiscordURL = @"https://discord.gg/xwHfUD2bxW";

int setting(const char* key) {
  return g_hooks.setting ? g_hooks.setting(key) : 0;
}

void set_setting(const char* key, int value) {
  if (g_hooks.set_setting) g_hooks.set_setting(key, value);
}

NSString* writable_dir() {
  return g_hooks.log_dir ? @(g_hooks.log_dir) : NSTemporaryDirectory();
}
}  // namespace

// A menu item that runs a block.
@interface OttselMenuItem : NSMenuItem
@property(nonatomic, copy) void (^handler)(void);
@end

@implementation OttselMenuItem
- (void)run:(id)sender {
  if (self.handler) self.handler();
}
@end

static NSMenuItem* Item(NSString* title, BOOL on, void (^handler)(void)) {
  OttselMenuItem* item = [[OttselMenuItem alloc] initWithTitle:title action:@selector(run:) keyEquivalent:@""];
  item.target = item;
  item.handler = handler;
  item.state = on ? NSControlStateValueOn : NSControlStateValueOff;
  return item;
}

static NSMenuItem* Note(NSString* title) {
  NSMenuItem* item = [[NSMenuItem alloc] initWithTitle:title action:nil keyEquivalent:@""];
  item.enabled = NO;
  return item;
}

static NSMenuItem* Submenu(NSString* title, NSArray<NSMenuItem*>* items) {
  NSMenuItem* item = [[NSMenuItem alloc] initWithTitle:title action:nil keyEquivalent:@""];
  NSMenu* menu = [[NSMenu alloc] initWithTitle:title];
  menu.autoenablesItems = NO;
  for (NSMenuItem* child in items) [menu addItem:child];
  item.submenu = menu;
  return item;
}

static void Alert(NSString* title, NSString* message) {
  NSAlert* alert = [[NSAlert alloc] init];
  alert.messageText = title;
  alert.informativeText = message;
  [alert runModal];
}

static void OpenURL(NSString* url) {
  [NSWorkspace.sharedWorkspace openURL:[NSURL URLWithString:url]];
}

@interface OttselMacMenus : NSObject <NSMenuDelegate>
@end

@implementation OttselMacMenus {
  NSTimer* _titleTimer;
}

- (instancetype)init {
  self = [super init];
  // The FPS counter lives in the window title: a Mac window has one, and it stays out of the picture.
  _titleTimer = [NSTimer scheduledTimerWithTimeInterval:1.0
                                                repeats:YES
                                                  block:^(NSTimer*) { [self updateTitle]; }];
  return self;
}

- (void)updateTitle {
  if (!g_window) return;
  if ([NSUserDefaults.standardUserDefaults boolForKey:kShowFPSKey] && g_hooks.fps) {
    SDL_SetWindowTitle(g_window, [NSString stringWithFormat:@"Ottsel — %.0f fps", g_hooks.fps()].UTF8String);
  } else {
    SDL_SetWindowTitle(g_window, "Ottsel");
  }
}

// Each menu is rebuilt as it opens, so its checkmarks follow the settings, the game's own menus and files
// added since.
- (void)menuNeedsUpdate:(NSMenu*)menu {
  [menu removeAllItems];
  NSArray<NSMenuItem*>* items = @[];
  if ([menu.title isEqualToString:@"Display"]) items = [self displayItems];
  if ([menu.title isEqualToString:@"Cheats"]) items = [self cheatItems];
  if ([menu.title isEqualToString:@"Mods"]) items = [self modItems];
  if ([menu.title isEqualToString:@"Controls"]) items = [self controlItems];
  if ([menu.title isEqualToString:@"Game Data"]) items = [self dataItems];
  if ([menu.title isEqualToString:@"Diagnostics"]) items = [self diagnosticItems];
  if ([menu.title isEqualToString:@"Help"]) items = [self helpItems];
  for (NSMenuItem* item in items) [menu addItem:item];
}

- (NSArray<NSMenuItem*>*)displayItems {
  const int scale = setting("render_scale");
  NSMutableArray* render = [NSMutableArray array];
  for (NSNumber* value in @[ @100, @75, @50 ]) {
    const int v = value.intValue;
    [render addObject:Item(v == 100 ? @"Native" : [NSString stringWithFormat:@"%d%%", v], scale == v,
                           ^{ set_setting("render_scale", v); })];
  }
  const bool full = g_window && (SDL_GetWindowFlags(g_window) & SDL_WINDOW_FULLSCREEN);
  NSMenuItem* fullscreen = Item(@"Full Screen", full, ^{ SDL_SetWindowFullscreen(g_window, !full); });
  fullscreen.keyEquivalent = @"f";
  fullscreen.keyEquivalentModifierMask = NSEventModifierFlagCommand | NSEventModifierFlagControl;
  return @[
    fullscreen,
    Submenu(@"Render Resolution", render),
    Item(@"Show FPS Counter", [NSUserDefaults.standardUserDefaults boolForKey:kShowFPSKey],
         ^{
           NSUserDefaults* d = NSUserDefaults.standardUserDefaults;
           [d setBool:![d boolForKey:kShowFPSKey] forKey:kShowFPSKey];
           [self updateTitle];
         }),
  ];
}

// OpenGOAL's own cheats (Secrets → Cheats in the game), switched on without typing a button code.
- (NSArray<NSMenuItem*>*)cheatItems {
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
  const unsigned on = g_ottsel_cheats_on.load();
  NSMutableArray* items = [NSMutableArray array];
  for (const auto& cheat : kCheats) {
    const int bit = cheat.bit;
    [items addObject:Item(cheat.title, (on >> bit) & 1, ^{ g_ottsel_cheat_request = bit; })];
  }
  return items;
}

// Play as Mario needs the player's own US Super Mario 64 ROM, as the game needs their disc.
- (NSArray<NSMenuItem*>*)modItems {
  const bool rom = setting("mario_rom");
  NSMenuItem* mario = Item(@"Play as Mario", setting("mario"), ^{ set_setting("mario", setting("mario") ? 0 : 1); });
  mario.enabled = rom;
  NSMenuItem* moves = Item(@"Mario's Moves (Triple Jump, Sideflip)", setting("mario_moves"),
                           ^{ set_setting("mario_moves", setting("mario_moves") ? 0 : 1); });
  moves.enabled = setting("mario");
  NSMutableArray* items = [NSMutableArray arrayWithArray:@[ mario, moves, NSMenuItem.separatorItem ]];
  [items addObject:Item(rom ? @"Replace Super Mario 64 ROM…" : @"Add Super Mario 64 (US) ROM…", NO,
                        ^{ [self addRom]; })];
  return items;
}

- (void)addRom {
  NSOpenPanel* panel = [NSOpenPanel openPanel];
  panel.message = @"Choose your own Super Mario 64 (US) ROM (.z64, .v64 or .n64).";
  NSMutableArray* types = [NSMutableArray array];
  for (NSString* ext in @[ @"z64", @"v64", @"n64" ]) {
    UTType* type = [UTType typeWithFilenameExtension:ext];
    if (type) [types addObject:type];
  }
  panel.allowedContentTypes = types;
  if ([panel runModal] != NSModalResponseOK || !panel.URL) return;
  NSFileManager* files = NSFileManager.defaultManager;
  NSString* dir = writable_dir();
  for (NSString* name in [files contentsOfDirectoryAtPath:dir error:nil]) {
    if ([@[ @"z64", @"v64", @"n64" ] containsObject:name.pathExtension.lowercaseString]) {
      [files removeItemAtPath:[dir stringByAppendingPathComponent:name] error:nil];
    }
  }
  NSString* destination =
      [dir stringByAppendingPathComponent:[@"sm64." stringByAppendingString:panel.URL.pathExtension.lowercaseString]];
  NSError* error = nil;
  if (![files copyItemAtPath:panel.URL.path toPath:destination error:&error]) {
    Alert(@"ROM Not Added", error.localizedDescription);
    return;
  }
  Alert(@"ROM Added", @"Turn on Mods → Play as Mario. A ROM that is not the US release is refused when Mario starts.");
}

- (NSArray<NSMenuItem*>*)controlItems {
  const int speed = setting("camera_sensitivity");
  NSMutableArray* speeds = [NSMutableArray array];
  for (NSNumber* value in @[ @50, @75, @100, @125, @150, @200 ]) {
    const int v = value.intValue;
    [speeds addObject:Item([NSString stringWithFormat:@"%d%%", v], speed == v,
                           ^{ set_setting("camera_sensitivity", v); })];
  }
  return @[
    Submenu(@"Camera Speed", speeds),
    Item(@"Invert Camera Up/Down", setting("invert_camera_y"),
         ^{ set_setting("invert_camera_y", setting("invert_camera_y") ? 0 : 1); }),
    NSMenuItem.separatorItem,
    Item(@"Keyboard and Mouse Controls…", NO, ^{
      Alert(@"Keyboard and Mouse Controls",
            @"Move: W A S D\nJump (✕): Space\nPunch (□): F\nSpin kick (○): E\nTriangle: R\n"
            @"Crouch / roll (R1): O     L1: Q\nStart: Return     D-pad: arrow keys\n\n"
            @"Click the game to steer the camera with the mouse.\n"
            @"A connected game controller works as it does on the iPad.");
    }),
  ];
}

// Game data comes from the player's own disc: a pack made by scripts/prepare-user-data-pack.sh, copied in
// here and validated on the next launch (src/shell/ios_boot.cpp).
- (NSArray<NSMenuItem*>*)dataItems {
  const bool has_data = g_hooks.has_game_data && g_hooks.has_game_data();
  return @[
    Note(has_data ? @"✓ Game Data Installed" : @"No Game Data Yet"),
    Item(@"Import Game Data…", NO, ^{ [self importGameData]; }),
    Item(@"Show Ottsel's Folder in Finder", NO,
         ^{ [NSWorkspace.sharedWorkspace openURL:[NSURL fileURLWithPath:writable_dir()]]; }),
  ];
}

- (void)importGameData {
  NSOpenPanel* panel = [NSOpenPanel openPanel];
  panel.canChooseDirectories = YES;
  panel.canChooseFiles = NO;
  panel.message = @"Choose the game-data folder made from your own Jak and Daxter disc (\"Ottsel game data\" from PadMint).";
  if ([panel runModal] != NSModalResponseOK || !panel.URL) return;
  NSFileManager* files = NSFileManager.defaultManager;
  NSURL* source = panel.URL;
  if (![files fileExistsAtPath:[source URLByAppendingPathComponent:@"manifest.txt"].path]) {
    Alert(@"Game Data Not Imported",
          @"That folder is not Ottsel game data. Choose the folder made from your own Jak and Daxter disc: "
          @"\"Ottsel game data\" from PadMint, or OttselUserData from the build scripts.");
    return;
  }
  NSString* destination = [writable_dir() stringByAppendingPathComponent:@"OttselUserData.import"];
  [files removeItemAtPath:destination error:nil];
  NSError* error = nil;
  if (![files copyItemAtPath:source.path toPath:destination error:&error]) {
    Alert(@"Game Data Not Imported", [NSString stringWithFormat:@"Copying failed: %@", error.localizedDescription]);
    return;
  }
  Alert(@"Game Data Copied", @"Quit and reopen Ottsel. It checks the pack on launch and keeps it for later launches.");
}

- (void)jumpTo:(NSString*)continueName {
  NSString* path = [writable_dir() stringByAppendingPathComponent:@"ottsel-warp"];
  [continueName writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:nil];
}

- (NSArray<NSMenuItem*>*)diagnosticItems {
  // Testing: start play at a level's own continue point (game/sce/libpad.cpp, main.gc).
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
  NSMutableArray* levels = [NSMutableArray array];
  for (const auto& level : kLevels) {
    NSString* name = @(level.name);
    [levels addObject:Item(level.title, NO, ^{ [self jumpTo:name]; })];
  }
  return @[
    Item(@"Show Log Over Game", setting("log_overlay"),
         ^{ set_setting("log_overlay", setting("log_overlay") ? 0 : 1); }),
    Item(@"Show Logs in Finder", NO, ^{
      NSURL* log = [NSURL fileURLWithPath:[writable_dir() stringByAppendingPathComponent:@"ottsel-runtime.log"]];
      [NSWorkspace.sharedWorkspace activateFileViewerSelectingURLs:@[ log ]];
    }),
    Submenu(@"Jump to Level (Testing)", levels),
  ];
}

- (NSArray<NSMenuItem*>*)helpItems {
  return @[
    Item(@"Report a Problem on GitHub…", NO, ^{
      NSURLComponents* url =
          [NSURLComponents componentsWithString:[kGitHubURL stringByAppendingString:@"/issues/new"]];
      NSOperatingSystemVersion v = NSProcessInfo.processInfo.operatingSystemVersion;
      url.queryItems = @[
        [NSURLQueryItem queryItemWithName:@"template" value:@"device_report.yml"],
        [NSURLQueryItem queryItemWithName:@"device" value:@"Mac"],
        [NSURLQueryItem queryItemWithName:@"ios"
                                    value:[NSString stringWithFormat:@"macOS %ld.%ld.%ld", (long)v.majorVersion,
                                                                     (long)v.minorVersion, (long)v.patchVersion]],
        [NSURLQueryItem queryItemWithName:@"fps"
                                    value:[NSString stringWithFormat:@"%.0f fps", g_hooks.fps ? g_hooks.fps() : 0.0]],
      ];
      [NSWorkspace.sharedWorkspace openURL:url.URL];
    }),
    Item(@"Join the Discord", NO, ^{ OpenURL(kDiscordURL); }),
    Item(@"Ottsel on GitHub", NO, ^{ OpenURL(kGitHubURL); }),
  ];
}

- (void)install {
  NSMenu* bar = NSApp.mainMenu;
  if (!bar) {
    bar = [[NSMenu alloc] init];
    NSApp.mainMenu = bar;
  }
  // After the application menu, before SDL's Window menu.
  NSInteger at = 1;
  for (NSInteger i = 0; i < bar.numberOfItems; i++) {
    if ([bar itemAtIndex:i].submenu == NSApp.windowsMenu) {
      at = i;
      break;
    }
    at = i + 1;
  }
  for (NSString* title in @[ @"Display", @"Cheats", @"Mods", @"Controls", @"Game Data", @"Diagnostics" ]) {
    NSMenuItem* item = [[NSMenuItem alloc] initWithTitle:title action:nil keyEquivalent:@""];
    NSMenu* menu = [[NSMenu alloc] initWithTitle:title];
    menu.autoenablesItems = NO;
    menu.delegate = self;
    [self menuNeedsUpdate:menu];  // key equivalents (Full Screen) work before the menu is first opened
    item.submenu = menu;
    [bar insertItem:item atIndex:at++];
  }
  NSMenuItem* help = [[NSMenuItem alloc] initWithTitle:@"Help" action:nil keyEquivalent:@""];
  NSMenu* helpMenu = [[NSMenu alloc] initWithTitle:@"Help"];
  helpMenu.autoenablesItems = NO;
  helpMenu.delegate = self;
  help.submenu = helpMenu;
  [bar addItem:help];
  NSApp.helpMenu = helpMenu;
  [self updateTitle];
}
@end

// MARK: - C++ entry points (touch_controls.h, external_display.h)

namespace {
OttselMacMenus* g_menus = nil;
}

void ottsel_touch_install(SDL_Window* window, const OttselTouchHooks& hooks) {
  g_hooks = hooks;
  g_window = window;
  g_menus = [[OttselMacMenus alloc] init];
  [g_menus install];
}

void ottsel_touch_set_hidden(bool) {}

void ottsel_touch_set_tv_mode(bool) {}

void ottsel_external_display_install() {}
