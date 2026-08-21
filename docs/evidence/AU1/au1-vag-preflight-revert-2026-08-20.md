# AU1 VAG decoder preflight rollback — 2026-08-20

The bounded diagnostic experiment called `snd::Voice::Run()` directly 4096
times before submitting the voice, intending to measure a decoder-only peak.
It logged `preflight-peak=1` with initial decoded samples `0, 0, 0, 0`, which
contradicted an independent raw ADPCM calculation and did not isolate a safe
product boundary. The same replay later wrote a signal-11 fault log during the
normal GOAL boot path.

The direct preflight loop was removed immediately. The retained implementation
only submits the voice after chunk reads; the last clean bounded transport
identity remains app SHA-256
`18b61871f3c32b108de0182390e1d07a4d9f26d34de21cf5a929aad07a7c7c39`, with
build, codesign, focused 8/8 tests, and diff checks passing. The failed
preflight is not a playback or decoder pass. A future decoder fix must use an
isolated fixture runner or a properly bounded streaming voice, not direct
pre-consumption of the live voice.
