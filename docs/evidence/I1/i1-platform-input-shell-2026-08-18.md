# I1 platform-input seam — iPad Pro 11-inch (M4) Simulator

Date: 2026-08-18

## Scope

This is an input-platform checkpoint, not an iPadOS playability or renderer
pass. The macOS `gk` runtime was stopped before booting the single iPad
Simulator. The app was built with `scripts/build-ios.sh`, ad-hoc signed,
installed, and launched through `simctl` on iPad Pro 11-inch (M4), UDID
`08636791-2675-4675-8335-EF72EF954DCF`.

## Change and regression

`game/sce/ottsel_platform_input.{h,cpp}` defines a completed DualShock state
for hosts without a desktop `Display`/`InputManager`. `scePadRead` samples that
state only when the desktop input manager is absent. The iOS shell maps the
same external keyboard and SDL Game Controller defaults as the macOS path, and
clears the state on backgrounding. The focused host regression passed:

```text
PlatformInput.CarriesCanonicalButtonsPressureAndNeutralState
PlatformInput.LatchesBriefDigitalPressAcrossPadReads
```

The iOS build and strict bundle signature verification completed after the
change. `UIApplicationSupportsIndirectInputEvents` is present in the bundle;
the preceding Simulator launch had explicitly reported that it was required
for mouse input.

## Live input evidence

Simulator delivers a keyboard down/up pair before the independent GOAL thread
can necessarily poll it. The mobile bridge therefore now latches each digital
keyboard down edge for eight `scePadRead` samples, matching the repaired macOS
keyboard policy while leaving held input and release state unchanged.

With Simulator keyboard capture enabled, one Return press was delivered into
the active iPad app. The host boundary recorded the down/up pair and the GOAL
consumer accepted the retained edge:

```text
OTTSEL MOBILE INPUT: source=keyboard event=1 buttons=0x8 left=(127, 127)
right=(127, 127) cross-pressure=0
OTTSEL MOBILE INPUT: source=keyboard event=2 buttons=0x0 left=(127, 127)
right=(127, 127) cross-pressure=0
OTTSEL TITLE: start edge in title-wait abs= rel= progress=#f
```

One Space press was likewise delivered into the active app:

```text
OTTSEL MOBILE INPUT: source=keyboard buttons=0x4000 left=(127, 127)
right=(127, 127) cross-pressure=255
OTTSEL MOBILE INPUT: source=keyboard buttons=0x0 left=(127, 127)
right=(127, 127) cross-pressure=0
```

This proves canonical Start and Cross delivery, Cross pressure, and neutral
release at the host-to-`scePadRead` boundary. It also proves that a normal
keyboard title tap reaches GOAL rather than relying on the synthetic debug
injector. It does not yet prove a visible Jak menu or gameplay action because
the product UI/renderer is still incomplete on mobile.

## Visible state and remaining work

`i1-platform-input-shell-2026-08-18.png` is a live Simulator capture. It is
black/diagnostic rather than a recognizable Jak scene. The no-emit dispatcher
was advancing, but the old shell renderer remains diagnostic-only. The next
mobile gate is to replace that product-path renderer boundary with the proven
desktop bucket-renderer architecture, then repeat input/lifecycle testing
against a visible game scene.
