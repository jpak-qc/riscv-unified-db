# Copyright (c) Qualcomm Technologies, Inc. and/or its subsidiaries.
# SPDX-License-Identifier: BSD-3-Clause-Clear

#*****************************************************************************
# vcmp_mask.S — Phase 6: compare, mask logical, mask ops
# Built with IGNOREUNDEFINED=YES to avoid UndefinedValueError on uninitialized
# mask destination registers (the ISS srcRegs() conservatively lists vd as a
# source for compare instructions due to the mask guard static analysis).
#
# Test 1: vcpop.m — 4 set bits in 0x0F, vl=4
# Test 2: vfirst.m — first set bit in 0x06, vl=4 → index 1
# Test 3: viota.m — running count, element 1 = 1
# Test 4: vid.v — element index, byte 2 = 2
# Test 5: vmseq.vv — [1,2,3,4]==[1,2,0,4] → 3 equal → vcpop=3
# Test 6: vmand.mm — 0x0F & 0x55 = 0x05 → 2 set bits → vcpop=2

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

  # Tests 5-6 require IGNOREUNDEFINED=YES build — without it the ISS aborts
  # on uninitialized mask destination registers before execute() is called.
  TEST_CASE(5, x2, 3, \
    li x6,4; vsetvli x7,x6,e8,m1; \
    la x5,cmp_a; vle8.v v2,(x5); la x5,cmp_b; vle8.v v3,(x5); \
    vmseq.vv v0,v2,v3; \
    vcpop.m x2,v0; )

  TEST_CASE(6, x2, 2, \
    li x6,8; vsetvli x7,x6,e8,m1; \
    la x5,zeros; vle8.v v0,(x5); \
    la x5,mask_a; vle8.v v2,(x5); la x5,mask_b; vle8.v v3,(x5); \
    vmand.mm v0,v2,v3; \
    vcpop.m x2,v0; )

  # LMUL=8 group-crossing: vid.v element 16 = 16 (index value), SEW=8
  TEST_CASE(7, x2, 16, \
    li x6,20; vsetvli x7,x6,e8,m8; \
    vid.v v8; \
    la x5,result; vse8.v v8,(x5); lbu x2,16(x5); )

  TEST_PASSFAIL

RVTEST_CODE_END

.data
  .balign 8
cmp_a:  .byte 0x01, 0x02, 0x03, 0x04
cmp_b:  .byte 0x01, 0x02, 0x00, 0x04
mask_a: .byte 0x0F, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
mask_b: .byte 0x55, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
zeros:  .fill 8, 1, 0x00
mask_c: .byte 0x0F, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
mask_d: .byte 0x06, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
mask_e: .byte 0x0B, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00

RVTEST_DATA_BEGIN
  .balign 8
result: .fill 24, 1, 0xff
RVTEST_DATA_END
