# I1 VU diagnostics gating — 2026-09-03

Question: does the normal iOS product path still copy VIF payloads and run
the CPU VU interpreter on every chain?

Change: gate VIF state handling, VU UNPACK copies, VU execution, and both
diagnostic dump writers behind `OTTSEL_ENABLE_CPU_VU_DIAGNOSTICS`. Native
PC_PORT camera/Merc capture and Metal scene submission remain enabled.

Build: direct iOS translation-unit compile passed; signed Simulator binary
SHA-256 `b25e909c8a053895dceabadf8e719e5d4fc02ee87cd989e9b6d575b331da6b2e`.

Runtime: iPad Pro M4 Simulator
`08636791-2675-4675-8335-EF72EF954DCF`. The log reports
`OTTSEL VU1: cpu-diagnostic-path=disabled`; subsequent VU1STAT samples show
`vu1-runs=0`, `capped=0`, and `nonzero-gif=0`. Neither
`tfrag-vif-replay.bin` nor `tfrag-vu-data.bin` exists in the application data.

The same run captured `eichar-lod0`, reached Village1, and mixed PCM with
peak `10879`; fault log size was 0 bytes.

Result: PASS for removing the normal-path CPU VU/dump workload. This does not
prove scene correctness or playability; the iPad gate remains OPEN.
