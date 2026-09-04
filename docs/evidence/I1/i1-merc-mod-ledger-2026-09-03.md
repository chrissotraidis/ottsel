# I1 Merc runtime-mod ledger — 2026-09-03

Question: is Jak invisible because native Merc ignores runtime mod vertices?

Upstream only replaces `all_draws` with `mod.mod_draw` when packet bitflags
request model mod or PC blerc and the effect has mod draws. Native currently
uses static `all_draws`, so the packet flags must be checked before changing
that path.

Runtime: iPad Pro M4 Simulator
`08636791-2675-4675-8335-EF72EF954DCF`, signed binary SHA-256
`507956821f83ae6a89c0a2616d54d62edd9e254f18e15fa945955fa3eb75fb4f`.

`eichar-lod0` repeatedly reported `bitflags=0x00`,
`model-uses-mod=false`, `model-uses-blerc=false`, `effects=4`,
`mod-effects=3`, `mod-draws=7`, and `all-draws=13`.

Result: OPEN, hypothesis falsified for this actor. Upstream also uses the
static draw list in this packet state, so implementing mod-draw replacement
would be an unrelated change. Continue with the matrix/coordinate contract.
