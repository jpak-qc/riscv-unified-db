<!--
Copyright (c) Qualcomm Technologies, Inc. and/or its subsidiaries.
SPDX-License-Identifier: BSD-3-Clause-Clear
-->

# ISS Recovery Log

## Session Metadata
- Mode: Approval-per-step (`1`)
- Goal: Recover ISS/Trusim runtime and get `rv64-riscv-tests` running reliably.

## Baseline Failure (Captured)
- Command:
  - `./gen/cpp_hart_gen/rv64_Debug/build/iss -m rv64 -c cfgs/rv64-riscv-tests.yaml`
- Output summary:
  - Config JSON is printed.
  - Process aborts with `udb::ElfReader::ElfException`.
  - Error text: `Could not open ELF file`.
- Initial root-cause hypothesis:
  - Positional `elf_file` argument is missing.
  - ISS still constructs `ElfReader` in run path and fails when no valid ELF is provided.

## Preferences / Constraints
- Recovery track: `clean` path (after preserving WIP).
- Primary target: `rv64` first, then `rv64-riscv-tests` execution.
- Mentor guidance captured:
  - Start with `CONFIG=rv64`.
  - Build tests with `./do build_riscv_tests CONFIG=rv64 BUILD_TYPE=DEBUG`.
  - Ensure RISC-V toolchain is present for generating test ELFs.

## Task Journal

### Entry Template
- Timestamp:
- Step ID:
- Command:
- Output summary:
- Decision:
- Next action:

### Entry 01
- Timestamp: `2026-06-24`
- Step ID: `S1`
- Command: Initialize `ISS_RECOVERY_LOG.md` and capture baseline failure context.
- Output summary: Log file created with baseline, constraints, and journal template.
- Decision: Proceed to read-only drift inventory before any state-changing cleanup.
- Next action: Collect branch/remote/status snapshot and categorize local drift.

### Entry 02
- Timestamp: `2026-06-24`
- Step ID: `S2`
- Command:
  - `git rev-parse --abbrev-ref HEAD`
  - `git remote -v`
  - `git status --short`
  - `git diff --stat`
  - `ls -la bin/bash bin/bash.broken`
  - `git ls-tree HEAD bin/bash`
  - `git diff -- ext/riscv-tests`
- Output summary:
  - Branch: `main`
  - Remotes: `origin` points to your fork (`jpak-qc/riscv-unified-db`), `upstream` points to official `riscv/riscv-unified-db`.
  - Drift detected:
    - 20 tracked changes (large modifications under `backends/cpp_hart_gen/...`)
    - Tracked deletion: `bin/bash`
    - Untracked replacement: `bin/bash.broken`
    - Submodule pointer drift: `ext/riscv-tests` moved from `f443f448...` to `34e6b6d1...`
    - Additional untracked files including local test artifacts and this log file.
- Decision:
  - Proceed with clean-path preservation strategy before restoring workspace state.
  - Keep fork/branch history intact; only clean local working tree after explicit preservation step.
- Next action:
  - Propose exact preservation command set (stash/patch/branch) and request approval before any cleanup.

### Entry 03
- Timestamp: `2026-06-24`
- Step ID: `S3`
- Command:
  - `git switch -c wip/iss-recovery-preclean-20260624`
  - `git add -u`
  - `git commit -m "WIP: pre-clean ISS source snapshot (tracked only)"`
  - `git status --short`
  - `git rev-parse --short HEAD`
  - `git status -sb`
- Output summary:
  - WIP preservation branch created: `wip/iss-recovery-preclean-20260624`.
  - Snapshot commit created: `71e7e6cf`.
  - Commit contains tracked changes only (20 files changed), including tracked submodule pointer update and tracked deletion of `bin/bash`.
  - Untracked files were intentionally **not** committed (e.g., `ISS_RECOVERY_LOG.md`, `bin/bash.broken`, local binaries/artifacts).
  - Current branch remains `wip/iss-recovery-preclean-20260624` with untracked files still present.
- Decision:
  - Preservation checkpoint achieved; source deltas are recoverable by commit hash/branch.
  - Next clean step must explicitly decide handling for untracked files and wrapper restoration.
- Next action:
  - Request approval to switch back to `main` and perform controlled cleanup/reset for tracked files and submodule pointer.

### Entry 04
- Timestamp: `2026-06-24`
- Step ID: `S4`
- Command:
  - `git switch main`
  - `git reset --hard HEAD`
  - `git submodule update --init --recursive ext/riscv-tests`
  - `git status --short`
  - `ls -la bin/bash bin/bash.broken`
- Output summary:
  - Switched back to `main` (up to date with `origin/main`).
  - Tracked files reset to `HEAD` (`34a77668`), removing tracked cpp_hart_gen drift from working tree.
  - `ext/riscv-tests` reset to pinned commit `f443f448...`.
  - `bin/bash` restored as tracked file; `bin/bash.broken` remains untracked.
  - Remaining drift is untracked content only (plus submodule dirty marker indicating local content inside `ext/riscv-tests`).
- Decision:
  - Source baseline is now coherent for tracked files; proceed to handle untracked clutter safely before rebuild.
- Next action:
  - Propose a conservative untracked cleanup plan that preserves this journal and only deletes known-generated/local artifacts.

### Entry 05
- Timestamp: `2026-06-24`
- Step ID: `S5`
- Command:
  - `rm -f -- bin/bash.broken compile_commands.json config_schema.json linker.ld rv64ui-p-add rv64ui-p-add.bin test.c 'udb::InstructionTracer::m_pHart’,' '’'`
  - `git status --short`
- Output summary:
  - Removed approved untracked/local artifact files from repo root.
  - Preserved `ISS_RECOVERY_LOG.md` intentionally.
  - Post-clean status now shows only:
    - `?? ISS_RECOVERY_LOG.md`
    - `? ext/riscv-tests` (submodule still marked dirty internally)
- Decision:
  - Workspace is mostly clean; only journal file and submodule-internal dirt remain.
- Next action:
  - Inspect submodule dirt source and choose whether to clean inside `ext/riscv-tests` before rebuilding.

### Entry 06
- Timestamp: `2026-06-24`
- Step ID: `S6`
- Command:
  - `git -C ext/riscv-tests status --short`
  - `git -C ext/riscv-tests rev-parse --short HEAD`
  - `git -C ext/riscv-tests clean -ndx`
- Output summary:
  - Submodule HEAD is pinned correctly at `f443f44`.
  - Dirty marker source is untracked generated artifacts in submodule (sample: `isa/hypervisor-*`, plus many benchmark/ISA test binaries and dumps).
  - Dry-run clean confirms files are removable generated outputs (no tracked modifications reported).
- Decision:
  - Safe to clean submodule untracked/generated files before rebuilding.
- Next action:
  - Request approval for `git -C ext/riscv-tests clean -fdx` to make submodule clean and reproducible.

### Entry 07
- Timestamp: `2026-06-24`
- Step ID: `S7`
- Command:
  - `git -C ext/riscv-tests clean -fdx`
  - `git status --short`
- Output summary:
  - Removed generated/untracked artifacts from `ext/riscv-tests` working tree.
  - Top-level repo status now shows only `?? ISS_RECOVERY_LOG.md`.
- Decision:
  - Workspace is clean and reproducible enough to proceed with environment/tooling validation and canonical rebuild.
- Next action:
  - Verify toolchain/wrapper assumptions (`.toolchain-local`, `bin/setup`/`bin/doctor` context) before running canonical build.

### Entry 08
- Timestamp: `2026-06-24`
- Step ID: `S8`
- Command:
  - `cat .toolchain-local`
  - `ls -la bin/bash`
  - `./do --tasks`
  - `./bin/doctor --help`
- Output summary:
  - Toolchain mode: `UDB_TOOLCHAIN_CONTAINER=0` (native).
  - Wrapper integrity: tracked `bin/bash` exists and is executable.
  - `./do` task loader works and enumerates tasks successfully.
  - `./bin/doctor --help` executes environment checks and reports all key prerequisites/toolchains healthy, including native C++ requirements.
- Decision:
  - Environment/tooling assumptions validated for canonical native rebuild.
- Next action:
  - Run mentor-aligned canonical build: `./do build:iss CONFIG=rv64 BUILD_TYPE=DEBUG`.

### Entry 09
- Timestamp: `2026-06-24`
- Step ID: `S9`
- Command:
  - `./do build:iss CONFIG=rv64 BUILD_TYPE=DEBUG`
  - `ls -la gen/cpp_hart_gen/rv64_Debug/build/iss`
- Output summary:
  - Canonical rv64 debug ISS build completed successfully (`Built target iss`).
  - Build emits expected/generated warnings in cfg/IDL-heavy code paths (e.g., narrowing and non-void return warnings), but no fatal errors.
  - ISS artifact exists and is executable at `gen/cpp_hart_gen/rv64_Debug/build/iss`.
- Decision:
  - Canonical build checkpoint achieved; proceed to build riscv-tests ELF payloads.
- Next action:
  - Run mentor-directed test payload build: `./do build_riscv_tests CONFIG=rv64 BUILD_TYPE=DEBUG`.

### Entry 10
- Timestamp: `2026-06-24`
- Step ID: `S10`
- Command:
  - `./do build_riscv_tests CONFIG=rv64 BUILD_TYPE=DEBUG`
- Output summary:
  - Build failed while compiling riscv-tests vector environment sources.
  - Compiler invocation used `bin/riscv64-unknown-elf-gcc` and include path `-I/usr/include/newlib`.
  - Fatal errors:
    - `fatal error: string.h: No such file or directory` from `ext/riscv-tests/env/v/string.c`
    - `fatal error: string.h: No such file or directory` from `ext/riscv-tests/env/v/vm.c`
  - `make` exited with error status 2; rake task aborted.
- Decision:
  - ISS build is healthy, but riscv-tests payload generation is blocked by missing C library headers/toolchain sysroot mismatch.
- Next action:
  - Run targeted toolchain diagnostics (read-only) to locate newlib/sysroot headers and correct cross-compiler configuration.

### Entry 11
- Timestamp: `2026-06-24`
- Step ID: `S11`
- Command:
  - `./bin/riscv64-unknown-elf-gcc -v`
  - `./bin/riscv64-unknown-elf-gcc -print-sysroot`
  - `./bin/riscv64-unknown-elf-gcc -print-search-dirs`
  - `ls -la /usr/include/newlib`
  - `ls -la /usr/riscv64-unknown-elf/include`
  - `ls -la /usr/lib/riscv64-unknown-elf`
  - `ls -la /usr/lib/gcc/riscv64-unknown-elf/13.2.0/include`
  - `dpkg -l | grep -E "riscv64-unknown-elf|newlib"`
  - `ls -la /home/josepak/riscv/riscv64-unknown-elf/include`
  - `sed -n '1,220p' bin/riscv64-unknown-elf-gcc`
- Output summary:
  - Active compiler wrapper resolves to system `/usr/bin/riscv64-unknown-elf-gcc`.
  - Compiler is configured `--without-newlib` and reports empty sysroot.
  - `-I/usr/include/newlib` path used by build does not exist on this machine.
  - Installed apt packages include only `gcc-riscv64-unknown-elf` + `binutils-riscv64-unknown-elf` (no newlib-dev package present).
  - A separate user-built toolchain **does** exist at `/home/josepak/riscv/riscv64-unknown-elf/include` with `string.h` available.
  - Wrapper currently prefers first native compiler in `PATH`; it does not force use of `/home/josepak/riscv/bin`.
- Decision:
  - Root cause identified: selected compiler lacks newlib headers expected by riscv-tests Makefile.
  - Two viable fixes:
    1) Install matching riscv newlib headers for system compiler, or
    2) Prepend `/home/josepak/riscv/bin` in `PATH` so wrapper picks user-built toolchain with newlib.
- Next action:
  - Request approval for low-risk runtime-scope PATH override test (`PATH=/home/josepak/riscv/bin:$PATH ./do build_riscv_tests ...`) before any persistent config changes.

### Entry 12
- Timestamp: `2026-06-24`
- Step ID: `S12`
- Command:
  - `PATH=/home/josepak/riscv/bin:$PATH ./bin/riscv64-unknown-elf-gcc -v`
  - `PATH=/home/josepak/riscv/bin:$PATH ./do build_riscv_tests CONFIG=rv64 BUILD_TYPE=DEBUG`
  - `ls -la ext/riscv-tests/isa/rv64ui-p-add`
- Output summary:
  - PATH override successfully switched wrapper-selected compiler to `/home/josepak/riscv/bin/riscv64-unknown-elf-gcc` (GCC 16.1.0, configured `--with-newlib`).
  - `build_riscv_tests` completed successfully under the overridden PATH and generated test payload binaries/dumps.
  - Verified representative payload exists: `ext/riscv-tests/isa/rv64ui-p-add`.
- Decision:
  - Toolchain blocker is resolved via non-persistent PATH override; proceed to ISS runtime validation using generated payloads.
- Next action:
  - Run ISS with explicit positional ELF using the known-good pair:
    `./gen/cpp_hart_gen/rv64_Debug/build/iss -m rv64 -c cfgs/rv64-riscv-tests.yaml ext/riscv-tests/isa/rv64ui-p-add`.

### Entry 13
- Timestamp: `2026-06-24`
- Step ID: `S13`
- Command:
  - `./gen/cpp_hart_gen/rv64_Debug/build/iss -m rv64 -c cfgs/rv64-riscv-tests.yaml ext/riscv-tests/isa/rv64ui-p-add`
- Output summary:
  - ELF file is now successfully opened/parsed (previous `Could not open ELF file` error no longer appears).
  - Runtime now fails later with:
    - `terminate called after throwing an instance of 'udb::UndefinedValueError'`
    - `what(): Cannot compare unknown value`
- Decision:
  - Original ELF-argument problem is resolved.
  - Current blocker shifts to runtime model behavior with unknown-value comparisons (not file-path/ELF loading).
- Next action:
  - Request approval for a targeted runtime mitigation test by rebuilding ISS with `IGNOREUNDEFINED=YES` and rerunning the same ELF.

### Entry 14
- Timestamp: `2026-06-24`
- Step ID: `S14`
- Command:
  - `./do build:iss CONFIG=rv64 BUILD_TYPE=DEBUG IGNOREUNDEFINED=YES`
  - `./gen/cpp_hart_gen/rv64_Debug/build/iss -m rv64 -c cfgs/rv64-riscv-tests.yaml ext/riscv-tests/isa/rv64ui-p-add`
- Output summary:
  - Rebuild with `IGNOREUNDEFINED=YES` completed successfully (`Built target iss`).
  - Re-run on same ELF still throws identical exception:
    - `udb::UndefinedValueError`
    - `Cannot compare unknown value`
- Decision:
  - `IGNOREUNDEFINED=YES` did not mitigate current runtime failure for this path.
  - Runtime issue likely originates in generated model logic/config semantics rather than simple build flag handling.
- Next action:
  - Request approval for focused triage run using `--trace inst` (and optionally `--trace mem`) plus alternate known test ELF(s) to isolate whether failure is test-specific or systemic.

### Entry 15
- Timestamp: `2026-06-24`
- Step ID: `S15`
- Command:
  - `./gen/cpp_hart_gen/rv64_Debug/build/iss -m rv64 -c cfgs/rv64-riscv-tests.yaml ext/riscv-tests/isa/rv64ui-p-add`
  - `./gen/cpp_hart_gen/rv64_Debug/build/iss -m rv64 -c cfgs/rv64-riscv-tests.yaml ext/riscv-tests/isa/rv64ui-p-addi`
  - `./gen/cpp_hart_gen/rv64_Debug/build/iss -m rv64 -c cfgs/rv64-riscv-tests.yaml ext/riscv-tests/isa/rv64ui-p-simple`
- Output summary:
  - `rv64ui-p-add`   -> throws `udb::UndefinedValueError (Cannot compare unknown value)`
  - `rv64ui-p-addi`  -> throws `udb::UndefinedValueError (Cannot compare unknown value)`
  - `rv64ui-p-simple`-> throws `udb::UndefinedValueError (Cannot compare unknown value)`
- Decision:
  - Failure reproduces across multiple basic rv64ui tests; issue appears systemic for current build/config path, not single-test-specific.
- Next action:
  - Request approval for one high-signal diagnostic run with tracing (`--trace inst`) and canonical rv64 config to capture earliest observable execution before exception.

### Entry 16
- Timestamp: `2026-06-24`
- Step ID: `S16`
- Command:
  - `./gen/cpp_hart_gen/rv64_Debug/build/iss -m rv64 -c cfgs/rv64-riscv-tests.yaml -t inst ext/riscv-tests/isa/rv64ui-p-add`
- Output summary:
  - Command fails with `udb::ElfReader::ElfException` (`Could not open ELF file`) when `-t inst` is added in this form.
  - No instruction trace lines are emitted before failure.
- Decision:
  - Trace option invocation likely malformed/ambiguous for CLI11 parsing in this binary (possible option/positional interaction).
  - This does **not** invalidate prior result that plain explicit ELF invocation loads the file and reaches runtime `UndefinedValueError`.
- Next action:
  - Request approval for a corrected trace invocation form (e.g., `--trace inst`) and/or alternate argument ordering to isolate parser behavior before deeper runtime debugging.

### Entry 17
- Timestamp: `2026-06-24`
- Step ID: `S17`
- Command:
  - `./gen/cpp_hart_gen/rv64_Debug/build/iss --trace inst -m rv64 -c cfgs/rv64-riscv-tests.yaml ext/riscv-tests/isa/rv64ui-p-add`
  - `timeout 5 ./gen/cpp_hart_gen/rv64_Debug/build/iss -m rv64 -c cfgs/rv64-riscv-tests.yaml ext/riscv-tests/isa/rv64ui-p-add --trace inst`
- Output summary:
  - Corrected trace invocations emit instruction trace lines immediately (ELF is successfully loaded in both forms).
  - No immediate `Could not open ELF file` appears with these corrected forms.
  - Short run with trailing `--trace inst` (timed 5s) confirms parser accepts alternate ordering too.
- Decision:
  - Step `S16` ELF-open error was caused by argument parsing of `-t inst <elf>` form (ELF path consumed as extra trace token), not by filesystem/ELF corruption.
  - Runtime UndefinedValueError remains unresolved and likely occurs later in execution.
- Next action:
  - Request approval for focused trace-to-file capture to identify the last executed instruction/state before `udb::UndefinedValueError`.

### Entry 18
- Timestamp: `2026-06-24`
- Step ID: `S18`
- Command:
  - Edit `backends/cpp_hart_gen/cpp/src/GDBServer.cpp`
- Output summary:
  - Applied minimal protocol-stability fixes in backend source only:
    - `GetSupportedString()` feature table iteration bound changed from byte-size to element-count.
    - `GDBPacket::Write(const std::string&)` now enforces response buffer bounds.
- Decision:
  - Scope kept intentionally narrow to GDB remote-protocol plumbing; no ISA/model semantics changed in this step.
- Next action:
  - Rebuild ISS and run debugger handshake validation.

### Entry 19
- Timestamp: `2026-06-24`
- Step ID: `S19`
- Command:
  - `./do build:iss CONFIG=rv64 BUILD_TYPE=DEBUG`
  - Attach probe with remote packet debug enabled (`target remote 127.0.0.1:<port>`)
- Output summary:
  - Build succeeded.
  - Handshake-level blocker resolved:
    - `qSupported` response no longer contains unrecognized `timeout` token.
    - `vMustReplyEmpty` receives correct empty reply.
  - New blocker surfaced after handshake on initial register fetch (`g` packet):
    - ISS aborted with `Cannot convert value with unknowns to a native C++ type`.
- Decision:
  - Original GDB negotiation issue is fixed.
  - Follow-up needed in ISS register read path to avoid abort when model holds unknown values pre-execution.
- Next action:
  - Add guarded reads for GPR register fetch callbacks used by GDB.

### Entry 20
- Timestamp: `2026-06-24`
- Step ID: `S20`
- Command:
  - Edit `backends/cpp_hart_gen/cpp/src/iss.cpp`
  - `./do build:iss CONFIG=rv64 BUILD_TYPE=DEBUG`
- Output summary:
  - Added exception-safe fallback (`0`) for unknown GPR values in:
    - `OnReadGPR`
    - `OnReadSingleRegister` (GPR path)
  - Build succeeded.
  - GDB attach remains stable; `g` packet no longer aborts ISS.
- Decision:
  - Register-read crash is mitigated for debugger bring-up.
  - Additional debugger usability blockers remained (`x/i $pc` memory reads returned `E01`, and `si` returned an inconsistent run/stop interaction).
- Next action:
  - Patch debugger memory access path and single-step stop notification semantics.

### Entry 21
- Timestamp: `2026-06-24`
- Step ID: `S21`
- Command:
  - Edit `backends/cpp_hart_gen/cpp/src/iss.cpp`
  - `./do build:iss CONFIG=rv64 BUILD_TYPE=DEBUG`
  - GDB validation run (`info reg pc`, `x/i $pc`, `si`, `x/i $pc`)
- Output summary:
  - Added explicit single-step halt notification after `STATE_SINGLE_STEP` execution.
  - Added VA-translation fallback to direct SoC memory access in GDB read/write memory callbacks.
  - Initial validation still returned `E01` on memory reads.
  - Root cause identified in return-value handling:
    - `memcpy_to_host`/`memcpy_from_host` return positive byte counts on success, not `0`.
  - Corrected success checks from `== 0` to `>= 0`.
  - Rebuilt and re-validated successfully:
    - `qSupported` clean
    - `vMustReplyEmpty` clean
    - `x/i $pc` now works (instruction bytes and disassembly returned)
    - `si` now returns stop reply and advances `pc` (`0x80000000` -> `0x80000050`)
- Decision:
  - Lab-3-style debugger flow is now operational for attach, inspect, and single-step.
- Next action:
  - Run continuity checks for non-GDB execution path and update tomorrow playbook caveats.

### Entry 22
- Timestamp: `2026-06-24`
- Step ID: `S22`
- Command:
  - `timeout 5 ./gen/cpp_hart_gen/rv64_Debug/build/iss -m rv64 -c cfgs/rv64-riscv-tests.yaml ext/riscv-tests/isa/rv64ui-p-add --trace inst`
  - `./gen/cpp_hart_gen/rv64_Debug/build/iss -m rv64 -c cfgs/rv64-riscv-tests.yaml ext/riscv-tests/isa/rv64ui-p-add`
- Output summary:
  - Instruction trace path remains functional and emits expected trace lines.
  - Plain non-GDB run on `rv64ui-p-add` now reports `SUCCESS - Pass`.
- Decision:
  - Current ISS runtime state is materially improved from earlier session baseline.
  - Prior `UndefinedValueError` caveat is no longer reproducible on this representative rv64ui payload in the current build.
- Next action:
  - Preserve changes as source-only commit candidates and keep generated/build artifacts out of commit set.

## Tomorrow Demo Playbook (High Priority)

### Why this matters
- This section is the **minimum high-level flow** for tomorrow’s session:
  1) build ELFs,
  2) run them through the ISS,
  3) attach RISC-V debugger,
  4) single-step code.
- Current status supports the demo flow; known caveat is a later runtime `UndefinedValueError`.

### Repo ownership verification
- ISS debugger flow is in **this repository** (`riscv-unified-db`), not another repo:
  - ISS usage + GDB flags documented in `backends/cpp_hart_gen/README.adoc` (`-g`, `--halt`, `-p`).
  - Build/test/run tasks in `backends/cpp_hart_gen/tasks.rake` (`task iss`, `build_riscv_tests`, `riscv_tests`).

### Copy/paste workflow (tomorrow)
1. Build ISS (canonical)
- `./do build:iss CONFIG=rv64 BUILD_TYPE=DEBUG`

2. Build riscv-tests ELFs (toolchain workaround active)
- `PATH=/home/josepak/riscv/bin:$PATH ./do build_riscv_tests CONFIG=rv64 BUILD_TYPE=DEBUG`

3. Run ISS with a known test ELF
- `./gen/cpp_hart_gen/rv64_Debug/build/iss -m rv64 -c cfgs/rv64-riscv-tests.yaml ext/riscv-tests/isa/rv64ui-p-add`

4. Launch ISS as GDB server (halt before execution)
- `./gen/cpp_hart_gen/rv64_Debug/build/iss -m rv64 -c cfgs/rv64-riscv-tests.yaml -g --halt -p 2159 ext/riscv-tests/isa/rv64ui-p-add`

5. Attach RISC-V debugger and single-step
- `/home/josepak/riscv/bin/riscv64-unknown-elf-gdb ext/riscv-tests/isa/rv64ui-p-add`
- In gdb:
  - `target remote 127.0.0.1:2159`
  - `info reg pc`
  - `x/i $pc`
  - `si`
  - `x/i $pc`

### Known caveats (current)
- GDB attach/step path is now stable in this environment:
  - `qSupported` negotiation succeeds without `timeout` token warnings.
  - `vMustReplyEmpty` negotiation succeeds.
  - `x/i $pc` and `si` both function in the validated smoke test.
- Keep using the riscv toolchain PATH override when rebuilding test ELFs.
- Avoid committing generated/build outputs; commit backend source changes only.
