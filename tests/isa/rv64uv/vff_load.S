# Copyright (c) Qualcomm Technologies, Inc. and/or its subsidiaries.
# SPDX-License-Identifier: BSD-3-Clause-Clear

#*****************************************************************************
# vff_load.S
#
# Tests for vle8ff.v / vle16ff.v / vle32ff.v / vle64ff.v fault-only-first
# semantics: element i>0 faults -> CSR[vl] trimmed to i; element 0 faults
# -> raises normally (forward progress guarantee).
#
# Fault trigger mechanism:
#   - EXTRA_INIT (runs while still in M-mode, before mret) does two things:
#       1. Sets MPP=M (bits 12:11 = 11) in mstatus so the mret stays in
#          M-mode.  This is essential: U-mode instruction fetches go through
#          PMP too, so a restricted PMP that only covers ff_data would kill
#          instruction fetches from the code text region.  Staying in M-mode
#          means instruction fetches bypass PMP (NoMatch -> allow).
#       2. Programs a TOR PMP entry covering [ff_data, ff_data+4096).
#          Addresses >= ff_data+4096 are NoMatch -> denied in U-mode.
#   - In each fault test case, MPRV=1 + MPP=U are set before the vector
#     load.  effective_ldst_mode() sees mode()==M and MPRV=1/MPP=U, so it
#     returns U-mode for PMP purposes.  Data accesses use U-mode PMP
#     semantics while instruction fetches remain in M-mode (bypass PMP).
#   - After the load, MPRV is cleared.
#
# Test 1: vle8ff.v trim -- SEW=8, base=ff_data+4094, vl=4.
#   elem 0 @ ff_data+4094 (in PMP range -> ok)
#   elem 1 @ ff_data+4095 (in PMP range -> ok)
#   elem 2 @ ff_data+4096 (NoMatch -> FAULT) -> vl trimmed to 2.
# Test 2: vle8ff.v no-fault -- base=ff_data, vl=4, all elements ok.
#   vl must remain 4.
# Test 3: vle16ff.v trim -- SEW=16, base=ff_data+4092, vl=4.
#   elem 0 @ ff_data+4092, elem 1 @ ff_data+4094 (both ok),
#   elem 2 @ ff_data+4096 (FAULT) -> vl trimmed to 2.
# Test 4: vle8ff.v elem 0 faults -> RAISE (caught by mtvec_handler).
#   base = ff_data+4096, elem 0 is immediately out of PMP range.

# EXTRA_INIT is called inside reset_vector while in M-mode, before mret.
# Default is empty; we redefine it after the include.
#include "riscv_test.h"
#include "test_macros.h"

#undef EXTRA_INIT
#define EXTRA_INIT \
  /* Keep MPP=M so mret stays in M-mode (protects instruction fetches). */ \
  li  t0, MSTATUS_MPP;  csrrs zero, mstatus, t0; \
  /* Program PMP: TOR [ff_data, ff_data+4096) with R|W|X. */ \
  jal ra, setup_pmp;

# Macros to enable/disable MPRV with MPP=U for U-mode data access semantics.
# effective_ldst_mode() returns U when mode()==M and MPRV=1 and MPP=0b00.
# Use t3 (x28) to avoid clobbering t0 (x5) which is often used as vector base.
#define MPRV_ON  li t3, MSTATUS_MPRV; csrrs zero, mstatus, t3
#define MPRV_OFF li t3, MSTATUS_MPRV; csrrc zero, mstatus, t3
# Clear MPP bits -> MPP=U (needed before MPRV_ON for effective_ldst_mode).
#define MPP_U    li t3, MSTATUS_MPP;  csrrc zero, mstatus, t3

# mtvec_handler: catches the access fault from test 4 (elem 0 faults).
# It verifies that the normal load-access-fault trap was taken at the vector
# instruction, then clears MPRV, skips that instruction, and returns to M-mode.
.global mtvec_handler
mtvec_handler:
  csrr  t4, mcause
  li    t5, CAUSE_LOAD_ACCESS
  bne   t4, t5, 1f
  csrr  t4, mepc
  la    t5, test4_faulting_vle
  bne   t4, t5, 1f
  li    x20, 1
  j     2f
1:
  li    x20, 2
2:
  li    t3, MSTATUS_MPRV
  csrrc zero, mstatus, t3
  csrr  t3, mepc
  addi  t3, t3, 4
  csrw  mepc, t3
  mret

RVTEST_RV64UV
RVTEST_CODE_BEGIN

  # ---------------------------------------------------------------
  # Test 1: vle8ff.v trim -- elem 2 faults.  Expected vl = 2.
  # ---------------------------------------------------------------
  TEST_CASE(1, x2, 2, \
    MPP_U; \
    li  x6, 4; vsetvli x7, x6, e8, m1; \
    la  x5, ff_data; li t1, 4094; add x5, x5, t1; \
    MPRV_ON; vle8ff.v v2, (x5); MPRV_OFF; \
    csrr x2, vl; )

  # ---------------------------------------------------------------
  # Test 2: vle8ff.v no fault -- all 4 elements in PMP range.  Expected vl = 4.
  # ---------------------------------------------------------------
  TEST_CASE(2, x2, 4, \
    MPP_U; \
    li  x6, 4; vsetvli x7, x6, e8, m1; \
    la  x5, ff_data; \
    MPRV_ON; vle8ff.v v3, (x5); MPRV_OFF; \
    csrr x2, vl; )

  # ---------------------------------------------------------------
  # Test 3: vle16ff.v trim -- SEW=16, elem 2 faults.  Expected vl = 2.
  # ---------------------------------------------------------------
  TEST_CASE(3, x2, 2, \
    MPP_U; \
    li  x6, 4; vsetvli x7, x6, e16, m1; \
    la  x5, ff_data; li t1, 4092; add x5, x5, t1; \
    MPRV_ON; vle16ff.v v4, (x5); MPRV_OFF; \
    csrr x2, vl; )

  # ---------------------------------------------------------------
  # Test 4: elem 0 faults -> must RAISE.  mtvec_handler sets x20=1.
  # ---------------------------------------------------------------
  TEST_CASE(4, x20, 1, \
    li  x20, 0; \
    MPP_U; \
    li  x6, 4; vsetvli x7, x6, e8, m1; \
    la  x5, ff_data; li t1, 4096; add x5, x5, t1; \
    MPRV_ON; test4_faulting_vle: vle8ff.v v5, (x5); MPRV_OFF; )

  TEST_PASSFAIL

# PMP setup subroutine -- called by EXTRA_INIT while in M-mode.
# Clears all PMP entries, then creates a TOR entry 1 covering
# [ff_data, ff_data+4096) with R|W|X.  All other addresses are
# NoMatch -> denied when accessed in U-mode (via MPRV).
setup_pmp:
  csrwi pmpcfg0, 0
  csrwi pmpcfg2, 0
  la    t0, ff_data;          srli t0, t0, 2; csrw pmpaddr0, t0
  la    t0, ff_data; li t1, 4096; add t0, t0, t1; srli t0, t0, 2; csrw pmpaddr1, t0
  li    t0, (PMP_TOR | PMP_R | PMP_W | PMP_X) << 8
  csrw  pmpcfg0, t0
  ret

RVTEST_CODE_END

RVTEST_DATA_BEGIN
  .balign 4096
ff_data:
  .fill 4096, 1, 0xAB
RVTEST_DATA_END
