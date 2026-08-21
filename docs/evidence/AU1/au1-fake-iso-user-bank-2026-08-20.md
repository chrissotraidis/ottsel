# AU1 fake-ISO user-bank probe — 2026-08-20

## Result

The signed iPad Simulator diagnostic build loaded the validated user-pack
`SBK/COMMON.SBK` through the Jak 1 `fake_iso` / `FS_LoadSoundBank` path. It
requested bank sound 0 with handle 1 and produced nonzero PCM from the iOS
playback substrate (`pcm-peak=2831`). The app-owned fault log was 0 bytes.

This is a bounded bank-loading and mixer proof, not AU1 completion. Full
IOP/OVERLORD request and callback routing, MUS/VAG streaming, pause/resume,
route/interruption behavior, normal Metal playability, and physical-device
audio remain open. The run also retained two known RAMDISK invalid-read
diagnostics unrelated to this probe.

## Reproduction

- Build: `scripts/build-ios.sh`
- App binary SHA-256: `c4527732fcb059a7a1387cfee206976490104434f8265c22d0ed805621f7cab2`
- Simulator: iPad Pro 11-inch (M4), iOS 18.5
- UDID: `08636791-2675-4675-8335-EF72EF954DCF`
- Flags: `OTTSEL_DISABLE_METAL=1`, `OTTSEL_AUDIO_BANK_PROBE=1`
- Input: validated local test pack delivered into the app sandbox for this
  diagnostic run; this is not legal Files UI delivery proof.

## Runtime evidence

The app-owned runtime log recorded:

```text
OTTSEL AUDIO: fake-ISO bank probe loaded .../OttselUserData/SBK/COMMON.SBK offset=20480 bytes=831360
OTTSEL AUDIO: bank probe requested bank-sound=0 handle=1
OTTSEL AUDIO: mixed 48000 frames (window 8), pcm-peak=2831
```

The copied full log is `/tmp/ottsel-au1-fakeiso-2026-08-20.log`.
