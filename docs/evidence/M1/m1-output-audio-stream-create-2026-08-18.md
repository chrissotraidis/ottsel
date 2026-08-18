# M1 output-only audio stream creation boundary

Date: 2026-08-18

## Scope

This is an output-only audio diagnosis. No microphone permission was accepted
or required. The test selected `MacBook Air Speakers`; Cubeb's input device and
input stream parameters are both null.

## App-path result

An explicit local app-launcher opt-in removed `-nosound` and set
`OTTSEL_ENABLE_HOST_AUDIO=1`. The launch reached:

```text
OTTSEL AUDIO: opening output-only Cubeb stream (no input device or input parameters)
OTTSEL AUDIO: cubeb_init result=0
OTTSEL AUDIO: output latency result=0 frames=128
OTTSEL AUDIO: selected explicit output device 'MacBook Air Speakers'
OTTSEL AUDIO: creating output stream
```

It made no progress past stream creation. No permission dialog appeared; the
Computer Use inspection timed out because the main app thread was blocked.

## Native stack and contrast

`sample` of the live process showed this exact synchronous stack:

```text
snd::Player::InitCubeb
  cubeb_stream_init
    audiounit_setup_stream
      AudioComponentInstanceNew
        AudioDeviceCreateIOProcID
          HALC_ProxyIOContext::_TellServerAboutStreamUsage
            mach_msg
```

A direct `gk` process with the same environment and device selection reached
the same final `creating output stream` line within twelve seconds. The app
wrapper therefore is not the cause. The current application must retain its
bounded `-nosound` test containment until a different output backend/session
or a non-blocking recovery design is proven. This does not close the audible
audio product gate.
