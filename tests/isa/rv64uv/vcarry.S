# Copyright (c) Qualcomm Technologies, Inc. and/or its subsidiaries.
# SPDX-License-Identifier: BSD-3-Clause-Clear

#*****************************************************************************
# vcarry.S — Phase 9: carry/borrow instructions
#
# Test 1: vadc.vvm — 0xFF + 0x01 + carry(1) = 0x101 → low byte = 0x01
# Test 2: vadc.vxm — 0xFE + xs1=1 + carry(0) = 0xFF; lbu=0xFF
# Test 3: vsbc.vvm — 0x05 - 0x03 - borrow(1) = 0x01; lbu=0x01
# Test 4: vmadc.vvm (carry-out WITH carry-in) — 0xFF+0x01+cin=1: sum=0x101 > 0xFF → carry=1
# Test 5: vmadc.vv (carry-out NO carry-in) — 0xFE+0x01=0xFF: no overflow → carry=0
#         then 0xFF+0x01=0x100 > 0xFF → carry=1
# Test 6: vmsbc.vvm (borrow-out WITH borrow-in) — 0x01-0x02-bin=1: 1 < 2+1=3 → borrow=1
# Test 7: vmsbc.vv (borrow-out NO borrow-in) — 0x03-0x01=2: 3>=1 → no borrow=0
# Test 8: vmadc.vi no carry — 0xFE+imm=2=0x100 > 0xFF → carry=1; lbu=1
# Test 9: vadc LMUL=8 group crossing — element 16 verify

#include "riscv_test.h"
#include "test_macros.h"

RVTEST_RV64UV
RVTEST_CODE_BEGIN

  # Test 1: vadc.vvm — pre-load v0 mask (carry-in=1 for elem0), 0xFF+0x01+1=0x01 (carry out)
  TEST_CASE(1, x2, 0x01, \
    li x6,2; vsetvli x7,x6,e8,m1; \
    la x5,carry1; vle8.v v0,(x5); \
    la x5,src_ff; vle8.v v2,(x5); la x5,src_01; vle8.v v3,(x5); \
    vadc.vvm v4,v2,v3,v0; la x5,result; vse8.v v4,(x5); lbu x2,(x5); )

  # Test 2: vadc.vxm — carry-in=0 for all, 0xFE+1=0xFF
  TEST_CASE(2, x2, 0xFF, \
    li x6,2; vsetvli x7,x6,e8,m1; \
    la x5,carry0; vle8.v v0,(x5); \
    la x5,src_fe; vle8.v v2,(x5); \
    li x5,1; vadc.vxm v4,v2,x5,v0; la x5,result; vse8.v v4,(x5); lbu x2,(x5); )

  # Test 3: vsbc.vvm — borrow-in=1: 0x05-0x03-1=0x01
  TEST_CASE(3, x2, 0x01, \
    li x6,2; vsetvli x7,x6,e8,m1; \
    la x5,carry1; vle8.v v0,(x5); \
    la x5,src_05; vle8.v v2,(x5); la x5,src_03; vle8.v v3,(x5); \
    vsbc.vvm v4,v2,v3,v0; la x5,result; vse8.v v4,(x5); lbu x2,(x5); )

  # Test 4: vmadc.vvm carry-out WITH carry-in — 0xFF+0x01+1=0x101: carry=1; lbu=1
  TEST_CASE(4, x2, 2, \
    li x6,2; vsetvli x7,x6,e8,m1; \
    la x5,carry1; vle8.v v0,(x5); \
    la x5,src_ff; vle8.v v2,(x5); la x5,src_01; vle8.v v3,(x5); \
    li x6,2; vsetvli x7,x6,e8,m8; la x5,zeros; vle8.v v4,(x5); \
    li x6,2; vsetvli x7,x6,e8,m1; \
    vmadc.vvm v4,v2,v3,v0; \
    vmv1r.v v0,v4; vcpop.m x2,v0; )

  # Test 5: vmadc.vv no carry — [0xFE,0xFF]+[0x01,0x01]=[0xFF(no carry),0x100(carry)]
  # result mask: bit0=0, bit1=1 → vcpop=1
  TEST_CASE(5, x2, 1, \
    li x6,2; vsetvli x7,x6,e8,m1; \
    la x5,src_feff; vle8.v v2,(x5); la x5,src_01; vle8.v v3,(x5); \
    li x6,2; vsetvli x7,x6,e8,m8; la x5,zeros; vle8.v v4,(x5); \
    li x6,2; vsetvli x7,x6,e8,m1; \
    vmadc.vv v4,v2,v3; \
    vmv1r.v v0,v4; vcpop.m x2,v0; )

  # Test 6: vmsbc.vvm borrow WITH borrow-in — 0x01-0x02-1: 1<3 → borrow=1; vcpop=1
  TEST_CASE(6, x2, 2, \
    li x6,2; vsetvli x7,x6,e8,m1; \
    la x5,carry1; vle8.v v0,(x5); \
    la x5,src_01; vle8.v v2,(x5); la x5,src_02; vle8.v v3,(x5); \
    li x6,2; vsetvli x7,x6,e8,m8; la x5,zeros; vle8.v v4,(x5); \
    li x6,2; vsetvli x7,x6,e8,m1; \
    vmsbc.vvm v4,v2,v3,v0; \
    vmv1r.v v0,v4; vcpop.m x2,v0; )

  # Test 7: vmsbc.vv no borrow — [0x03,0x01]-[0x01,0x03]: 3>=1 no borrow; 1<3 borrow
  # result: bit0=0, bit1=1 → vcpop=1
  TEST_CASE(7, x2, 1, \
    li x6,2; vsetvli x7,x6,e8,m1; \
    la x5,src_0301; vle8.v v2,(x5); la x5,src_0103; vle8.v v3,(x5); \
    li x6,2; vsetvli x7,x6,e8,m8; la x5,zeros; vle8.v v4,(x5); \
    li x6,2; vsetvli x7,x6,e8,m1; \
    vmsbc.vv v4,v2,v3; \
    vmv1r.v v0,v4; vcpop.m x2,v0; )

  # Test 8: vmadc.vi no carry — 0xFE+imm=2=0x100 → carry=1; 0x01+2=0x03 no carry
  # result: bit0=1, bit1=0 → vcpop=1
  TEST_CASE(8, x2, 1, \
    li x6,2; vsetvli x7,x6,e8,m1; \
    la x5,src_fe01; vle8.v v2,(x5); \
    li x6,2; vsetvli x7,x6,e8,m8; la x5,zeros; vle8.v v4,(x5); \
    li x6,2; vsetvli x7,x6,e8,m1; \
    vmadc.vi v4,v2,2; \
    vmv1r.v v0,v4; vcpop.m x2,v0; )

  # Test 9: vadc LMUL=8 group crossing — element 16: 0x03+0x04+carry=0 = 0x07
  TEST_CASE(9, x2, 0x07, \
    li x6,20; vsetvli x7,x6,e8,m8; \
    la x5,carry0; vle8.v v0,(x5); \
    la x5,lmul8_a; vle8.v v8,(x5); la x5,lmul8_b; vle8.v v16,(x5); \
    vadc.vvm v24,v8,v16,v0; la x5,result; vse8.v v24,(x5); lbu x2,16(x5); )

  TEST_PASSFAIL

RVTEST_CODE_END

.data
  .balign 8
carry1:  .byte 0x01,0x01,0x00,0x00,0x00,0x00,0x00,0x00  # bits 0,1 set
carry0:  .fill 8, 1, 0x00
src_ff:  .byte 0xFF, 0xFF
src_fe:  .byte 0xFE, 0xFE
src_01:  .byte 0x01, 0x01
src_02:  .byte 0x02, 0x02
src_03:  .byte 0x03, 0x03
src_05:  .byte 0x05, 0x05
src_feff:.byte 0xFE, 0xFF
src_fe01:.byte 0xFE, 0x01
src_0301:.byte 0x03, 0x01
src_0103:.byte 0x01, 0x03
zeros:   .fill 16, 1, 0x00
lmul8_a: .byte 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0x03,1,1,1
lmul8_b: .byte 2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,0x04,2,2,2

RVTEST_DATA_BEGIN
  .balign 8
result: .fill 32, 1, 0x00
RVTEST_DATA_END
