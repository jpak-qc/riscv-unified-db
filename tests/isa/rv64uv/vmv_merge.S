# Copyright (c) Qualcomm Technologies, Inc. and/or its subsidiaries.
# SPDX-License-Identifier: BSD-3-Clause-Clear

#*****************************************************************************
# vmv_merge.S
#-----------------------------------------------------------------------------
# Phase 3 proof: vmv.v.v, vmv.v.x, vmerge.vvm, vmv2r.v
#
# Test 1: vmv.v.v — copy register (EEW=8, LMUL=1, vl=4)
#   Load [0x01,0x02,0x03,0x04] into v2, vmv.v.v v4, v2, store, lw = 0x04030201
#
# Test 2: vmv.v.x — broadcast scalar 0x55 (EEW=8, LMUL=1, vl=4)
#   Store, lw = 0x55555555
#
# Test 3: vmerge.vvm — mask=0x05 (bits 0,2 set; bits 1,3 clear)
#   vs2=[0x10,0x20,0x30,0x40], vs1=[0xAA,0xBB,0xCC,0xDD]
#   result: [0xAA,0x20,0xCC,0x40] → lw = 0x40CC20AA
#
# Test 4: vmv2r.v — copy 2 whole registers
#   Fill first register of the group (LMUL=1 vl=4) with [0xDE,0xAD,0xBE,0xEF],
#   then vmv2r.v v4, v2, store v4, lw = 0xEFBEADDE

#include "riscv_test.h"
#include "test_macros.h"

RVTEST_RV64UV
RVTEST_CODE_BEGIN

  # Test 1: vmv.v.v
  TEST_CASE(1, x2, 0x0000000004030201, \
    li      x6, 4; \
    vsetvli x7, x6, e8, m1; \
    la      x5, src_vmv; \
    vle8.v  v2, (x5); \
    vmv.v.v v4, v2; \
    la      x5, result; \
    vse8.v  v4, (x5); \
    lw      x2, (x5); \
    )

  # Test 2: vmv.v.x (broadcast 0x55)
  TEST_CASE(2, x2, 0x0000000055555555, \
    li      x6, 4; \
    vsetvli x7, x6, e8, m1; \
    li      x5, 0x55; \
    vmv.v.x v4, x5; \
    la      x5, result; \
    vse8.v  v4, (x5); \
    lw      x2, (x5); \
    )

  # Test 3: vmerge.vvm (mask=0x05 → lanes 0,2 from vs1; lanes 1,3 from vs2)
  TEST_CASE(3, x2, 0x0000000040CC20AA, \
    li      x6, 4; \
    vsetvli x7, x6, e8, m1; \
    la      x5, mask_05; \
    vle8.v  v0, (x5); \
    la      x5, src_vs2; \
    vle8.v  v2, (x5); \
    la      x5, src_vs1; \
    vle8.v  v3, (x5); \
    vmerge.vvm v4, v2, v3, v0; \
    la      x5, result; \
    vse8.v  v4, (x5); \
    lw      x2, (x5); \
    )

  # Test 4: vmv2r.v — load 4 bytes into v2 (LMUL=1, vl=4), vmv2r copies
  # both registers of the group. Store and read back the first 4 bytes.
  # 0xEFBEADDE has bit31 set → lw sign-extends to 0xFFFFFFFFEFBEADDE
  TEST_CASE(4, x2, 0xFFFFFFFFEFBEADDE, \
    li      x6, 4; \
    vsetvli x7, x6, e8, m1; \
    la      x5, src_dead; \
    vle8.v  v2, (x5); \
    vmv2r.v v4, v2; \
    la      x5, result; \
    vse8.v  v4, (x5); \
    lw      x2, (x5); \
    )

  TEST_PASSFAIL

RVTEST_CODE_END

.data
  .balign 8
src_vmv:  .byte 0x01, 0x02, 0x03, 0x04
src_vs2:  .byte 0x10, 0x20, 0x30, 0x40
src_vs1:  .byte 0xAA, 0xBB, 0xCC, 0xDD
mask_05:  .byte 0x05, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
src_dead: .byte 0xDE, 0xAD, 0xBE, 0xEF

RVTEST_DATA_BEGIN
  .balign 8
result: .dword -1
RVTEST_DATA_END
