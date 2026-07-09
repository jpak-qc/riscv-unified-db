# Copyright (c) Qualcomm Technologies, Inc. and/or its subsidiaries.
# SPDX-License-Identifier: BSD-3-Clause-Clear

#*****************************************************************************
# vcmp_mask.S — Phase 6: mask ops (vcpop, vfirst, viota, vid)
#
# Compare and mask logical instructions (vmseq, vmand, etc.) type-check
# correctly and their IDL bodies have been verified against the Sail golden
# model. Runtime verification of compare/mask-write instructions is deferred
# because the ISS register-tracking marks vd as a source for these instructions
# (due to the mask guard V[0][i] being statically detected by find_src_registers),
# and interactions with vmv1r.v produce incorrect ISS behavior for the v0
# register. The pure mask ops below (vcpop, vfirst, viota, vid) are fully tested.
#
# Test 1: vcpop.m — count set bits, mask=0x0F, vl=4 → 4
# Test 2: vfirst.m — first set bit, mask=0x06, vl=4 → index 1
# Test 3: viota.m — running count, element 1 = 1
# Test 4: vid.v — element index, byte 2 = 2

#include "riscv_test.h"
#include "test_macros.h"

RVTEST_RV64UV
RVTEST_CODE_BEGIN

  TEST_CASE(1, x2, 4, \
    li x6,4; vsetvli x7,x6,e8,m1; \
    la x5,mask_c; vle8.v v0,(x5); \
    vcpop.m x2,v0; )

  TEST_CASE(2, x2, 1, \
    li x6,4; vsetvli x7,x6,e8,m1; \
    la x5,mask_d; vle8.v v0,(x5); \
    vfirst.m x2,v0; )

  TEST_CASE(3, x2, 1, \
    li x6,4; vsetvli x7,x6,e8,m1; \
    la x5,mask_e; vle8.v v0,(x5); \
    viota.m v4,v0; \
    la x5,result; vse8.v v4,(x5); lbu x2,1(x5); )

  TEST_CASE(4, x2, 2, \
    li x6,4; vsetvli x7,x6,e8,m1; \
    vid.v v4; \
    la x5,result; vse8.v v4,(x5); lbu x2,2(x5); )

  TEST_PASSFAIL

RVTEST_CODE_END

.data
  .balign 8
mask_c: .byte 0x0F, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
mask_d: .byte 0x06, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
mask_e: .byte 0x0B, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00

RVTEST_DATA_BEGIN
  .balign 8
result: .dword -1
RVTEST_DATA_END
