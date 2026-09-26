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
