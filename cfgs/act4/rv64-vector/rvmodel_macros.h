// rvmodel_macros.h for UDB ISS (rv64-vector config)
// Uses standard HTIF tohost/fromhost termination via 64-bit writes.
// UDB ISS reads tohost as a 64-bit HTIF command:
//   bits [7:0]  = device  (0 = SysCall)
//   bits [15:8] = command (93 = exit for device 0)
//   bits [63:16] = payload ((testnum << 1) | 1; payload=0 means pass)
// Pass: write 0x0000000000000001 (device=0, cmd=0, payload=1 -> exit code 0)
// Fail: write 0x0000000000000003 (payload=3 -> exit code 1)
//
// Note: We bypass the ecall path and write directly to tohost to avoid
// needing a full syscall handler. The UDB ISS monitors tohost writes.

#ifndef RVMODEL_MACROS_H
#define RVMODEL_MACROS_H

// tohost/fromhost symbols in .tohost section
#define RVMODEL_DATA_SECTION \
    .pushsection .tohost,"aw",@progbits; \
    .balign 8; .global tohost; tohost: .dword 0; \
    .balign 8; .global fromhost; fromhost: .dword 0; \
    .popsection;

// Enable the full ACT4 trap handler infrastructure (RVTEST_TRAP_PROLOG/EPILOG/HANDLER).
// Without this, RVTEST_BOOT_TO_MMODE skips setting up mtvec, and the zero-fill
// alignment padding before exit_cleanup (LA macro .p2align 5 = c.unimp bytes)
// immediately traps at startup with mtvec=0 → infinite trap loop.
// All compliant reference models (Sail, Whisper, QEMU) define this.
#define STANDARD_SM_SUPPORTED

// GCC 13 does not recognize the 'mnstatus' CSR name (added in GCC 15 with Smrnmi).
// rvtest_setup.h emits 'csrw mnstatus, zero' when SMRNMI_SUPPORTED is defined.
// Undefine it here so the boot code skips that instruction; our ISS is still
// Smrnmi-compliant but this avoids the assembler "unknown CSR" error with GCC 13.
#undef SMRNMI_SUPPORTED

// No DUT-specific boot needed — ISS starts in M-mode ready to execute.
// #define RVMODEL_BOOT

// Terminate with PASS: write 64-bit value 1 to tohost.
// UDB HTIF: device=0, command=0, payload=1 (payload>>1 == 0 → ExitSuccess)
#define RVMODEL_HALT_PASS \
    li   t0, 1;                           \
    la   t1, tohost;                      \
    sd   t0, 0(t1);                       \
    1: j 1b;                              \

// Terminate with FAIL: write 64-bit value 3 to tohost.
// UDB HTIF: device=0, command=0, payload=3 (payload>>1 == 1 → ExitFailure, test #1)
// ACT4 tests write a specific test number — this macro is called with no args by the framework.
#define RVMODEL_HALT_FAIL \
    li   t0, 3;                           \
    la   t1, tohost;                      \
    sd   t0, 0(t1);                       \
    1: j 1b;                              \

// IO macros — no console available in UDB ISS bare-metal; leave as no-ops.
#define RVMODEL_IO_INIT(_R1, _R2, _R3)
#define RVMODEL_IO_WRITE_STR(_R1, _R2, _R3, _STR_PTR)
#define RVMODEL_DATA_BEGIN
#define RVMODEL_DATA_END

// Timer and interrupt macros — no interrupt/timer support in UDB bare-metal ISS.
// Define as no-ops to satisfy check_defines.h requirements.
#define RVMODEL_INTERRUPT_LATENCY  0
#define RVMODEL_TIMER_INT_SOON_DELAY  0
#define RVMODEL_MTIME_ADDRESS  0
#define RVMODEL_MTIMECMP_ADDRESS  0
#define RVMODEL_SET_MEXT_INT(_R1, _R2)
#define RVMODEL_CLR_MEXT_INT(_R1, _R2)
#define RVMODEL_SET_MSW_INT(_R1, _R2)
#define RVMODEL_CLR_MSW_INT(_R1, _R2)
#define RVMODEL_SET_SEXT_INT(_R1, _R2)
#define RVMODEL_CLR_SEXT_INT(_R1, _R2)
#define RVMODEL_SET_SSW_INT(_R1, _R2)
#define RVMODEL_CLR_SSW_INT(_R1, _R2)
#define RVMODEL_MSIP_ADDRESS  0

#endif // RVMODEL_MACROS_H
