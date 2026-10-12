# Patches

`ottsel-jak-project.patch` is the entire Ottsel delta against `open-goal/jak-project` at
`641fb572e876750d8618434d9f7c1a531b43b366`: tracked edits and every new file.

```sh
git clone https://github.com/open-goal/jak-project out/jak-project
git -C out/jak-project checkout 641fb572e876750d8618434d9f7c1a531b43b366
git -C out/jak-project apply --binary ../../patches/ottsel-jak-project.patch
```

Refresh it whenever nested source changes and commit it with that change:

```sh
scripts/snapshot-jak-project.sh write    # rewrites the patch, then verifies
scripts/snapshot-jak-project.sh verify   # PASS iff pin + patch == live nested tree
```

The per-change overlay patches used before 2026-09-24 are in git history.

`libsm64-ottsel-pose.patch` changes [libsm64](https://github.com/libsm64/libsm64) at
`fd11813208272b4271d92bd92feb8f3fdbe61be5` so Mario can be posed from Jak's state without his own physics
(`sm64_mario_pose`) and keeps his cap on. `scripts/build-ios.sh` clones libsm64 at that commit into
`out/third_party/libsm64` and applies the patch; edit the patch itself to change it.
