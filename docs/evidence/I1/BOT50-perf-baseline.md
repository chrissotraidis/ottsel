# BOT50 — what actually limits the iPad frame rate

Live on the iOS 18.5 Simulator (iPad Pro 11-inch M4, UDID 08636791-…) at HEAD
96a0a7d plus the BOT50 working tree. Every number is from a run.

## Headline

The engine advances ~9.3 chains/s, not ~1 fps; the earlier "~1.01 s fixed wait
per frame" is refuted. Two measured changes reached ~12.0/s (+28%).

| build                       | chains/s | evidence |
|-----------------------------|----------|----------|
| BOT49 + CLUT-window split   | 9.33     | /tmp/b51/log.txt |
| + pooled vertex buffers     | 11.67    | /tmp/b51/log3.txt |
| + strided mesh-texture hash | 12.32    | /tmp/b51/log5.txt |
| + counter fix (instrument)  | 11.79    | /tmp/b51/log7.txt, within noise |

## The limiter is the game thread's DMA chain, not the present

`sample` 5 s / 2453 samples: 99% of the game thread sits under
`ott sel_ios_run_boot` -> `arg_call_arm64` -> `send_gfx_dma_chain`. The main
thread is not the limiter — 43% of it is `SDL_SYS_DelayNS` on the 60 Hz cap.

| samples | % | frame |
|---|---|---|
| 562 | 24.2% | `decode_texture_pixels_raw` |
| 504 | 21.7% | `render_mobile_sprite_group0` |
| 353 | 15.2% | `__psynch_cvwait` (`gfx_vsync`) |
| 236 | 10.1% | `access` — game-side, see finding 3 |
| 138 | 5.9% | `mach_msg2_trap` |

## Three measured findings

1. Per-batch `newBufferWithLength:` was pure Simulator XPC: Sky and Direct
   allocated a fresh `MTLBuffer` per batch per frame, each a synchronous
   round-trip to MTLSimDriver. Paths of 170 + 142 samples (~18 ms/chain) vanished
   after pooling into a recycle list refilled from the completion handler.

2. `cachedMeshTexture:` hashed every pixel of every tile every frame — a full
   FNV-1a over ~29 MB/frame, the largest single source-line cost (249 samples,
   10.2%). The hash only proposes a key and hits still `memcmp` the retained
   bytes, so a 64-byte stride is safe: cost 48 samples / 2.1%, hits held 98.9%.

3. `access()` is the game's own probes: 104 of 236 samples run under
   `sp_launch_particles_var` -> `particle_adgif`, not our trigger files.

## The CLUT-window split is correct but not decisive

The instrument was lying: `++g_vram_decode_evicted` sat outside the eviction
loop, so it counted invalidations and printed a `changed`-identical 998, which
made the split look decisive. Corrected: ~26.4 memos die per changed page
(evicted 71506 / invalidations 2730). The ~169 misses/chain are genuine: the
cache already runs 99.5% hits, so `kOttselMobileDmaDecodeBudget` (512,
mobile_scene_policy.h:183) is the unproven knob, and it risks asset loss.

## Frozen / out of scope

Overlay rectangles from `build_touch_overlay` (main.cpp:629-641) remain; the
touch frontend is frozen. Gate N1 is unproven — input reaches the PC title menu,
not Village1 gameplay. Nothing here is playability proof.
