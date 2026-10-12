# Third-party notices

Ottsel builds on the projects below. Each keeps its own license and copyright. The full license texts
ship with each project: in the pinned OpenGOAL checkout (`out/jak-project/third-party/`) after step 1 of
the build, and inside the ANGLE download.

## Compiled into the app

| Component | Use | License |
|---|---|---|
| [OpenGOAL](https://github.com/open-goal/jak-project) (pinned `641fb572e`, patched by `patches/ottsel-jak-project.patch`) | GOAL compiler, runtime, renderer, sound and the game's decompiled source | ISC |
| [ANGLE](https://chromium.googlesource.com/angle/angle), prebuilt by [kivy/angle-builder](https://github.com/kivy/angle-builder) `chromium-7151_rev1` | OpenGL ES 3.0 on Metal (`libEGL`, `libGLESv2`, embedded in the app) | BSD-3-Clause |
| [SDL 3](https://github.com/libsdl-org/SDL) | Window, events, controllers, audio output | zlib |
| [libsm64](https://github.com/libsm64/libsm64) (pinned `fd11813`, patched by `patches/libsm64-ottsel-pose.patch`) | Mario for the Play as Mario mod, built from the Super Mario 64 decompilation; his animations, textures and sounds come from the player's own ROM at run time | CC0-1.0 |
| [Zstandard](https://github.com/facebook/zstd) | Decompression | BSD-3-Clause (dual-licensed with GPL-2.0) |
| [{fmt}](https://github.com/fmtlib/fmt) | Text formatting | MIT |
| [Dear ImGui](https://github.com/ocornut/imgui) | OpenGOAL's debug interface | MIT |
| [libco](https://github.com/higan-emu/libco) (from ares) | Coroutines for the IOP kernel | ISC |
| [lzokay](https://github.com/jackoalan/lzokay) | LZO decompression | MIT |
| [stb_image](https://github.com/nothings/stb) | Image loading | MIT or public domain |
| [sse2neon](https://github.com/DLTcollab/sse2neon) | SSE intrinsics on ARM | MIT |
| [nlohmann/json](https://github.com/nlohmann/json) | JSON | MIT |
| [glad](https://github.com/Dav1dde/glad) | Generated OpenGL function loader | See the generated header |

## Used only at build time

| Component | Use | License |
|---|---|---|
| [glslang](https://github.com/KhronosGroup/glslang) | Parses OpenGOAL's desktop shaders | BSD-3-Clause and others (see the project) |
| [SPIRV-Cross](https://github.com/KhronosGroup/SPIRV-Cross) | Emits the GLSL ES 3.00 shaders | Apache-2.0 |
| [XcodeGen](https://github.com/yonaskolb/XcodeGen) | Generates the touch-test and device-signing projects | MIT |

## Game content

Jak and Daxter: The Precursor Legacy is © Sony Interactive Entertainment; developed by Naughty Dog. No
game content is included in this repository. Builds use data extracted from a disc the builder owns.
