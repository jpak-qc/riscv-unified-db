# Copyright (c) Qualcomm Technologies, Inc. and/or its subsidiaries.
# SPDX-License-Identifier: BSD-3-Clause-Clear

#*****************************************************************************
# vint_arith.S
#-----------------------------------------------------------------------------
# Phase 4: integer arithmetic family (vadd/vsub/vrsub/vand/vor/vxor/vmin/vminu/vmax/vmaxu)
# SEW=8, LMUL=1, vl=2 throughout. Use `lb` to read a single byte to avoid
# needing to initialize the result buffer or account for sign-extension of
# unwritten bytes in a 4-byte lw.
#
# Test 1: vadd.vi — v2=[0x10,0x20]+3 = [0x13,0x23]; lb byte0 = 0x13
# Test 2: vsub.vx — v2=[0x10,0x20]-3 = [0x0D,0x1D]; lb byte0 = 0x0D
# Test 3: vrsub.vi— 0x0F-[0x03,0x05] = [0x0C,0x0A]; lb byte0 = 0x0C
# Test 4: vand.vv — [0x3C,0x55]&[0x0F,0xAA]=[0x0C,0x00]; lb byte0=0x0C
# Test 5: vor.vx  — [0x10,0x20]|0x0F=[0x1F,0x2F]; lb byte1=0x2F (sign-ext: 0x2F)
# Test 6: vxor.vi — [0xFF,0x00]^0x0F=[0xF0,0x0F]; lb byte0 signed=0xFFFFFFFFFFFFFFF0
# Test 7: vmin.vv (signed) — [0xFE,0x02] vs [0x01,0x01]: -2<1→0xFE; 2>1→0x01;
#   lb byte0 signed: 0xFE signed = -2 = 0xFFFFFFFFFFFFFFFE
# Test 8: vminu.vv(unsigned)— [0xFE,0x02] vs [0x01,0x01]: min=0x01,0x01; lb byte0=0x01
# Test 9: vmax.vx (signed) — [0xFE,0x02] vs 1: max(−2,1)=1; max(2,1)=2; lb byte0=0x01
# Test 10:vmaxu.vv(unsigned)— [0xFE,0x02] vs [0x01,0x01]: max=0xFE,0x02; lb byte0 signed=-2

#include "riscv_test.h"
#include "test_macros.h"

RVTEST_RV64UV
RVTEST_CODE_BEGIN

  TEST_CASE(1, x2, 0x13, \
    li x6,2; vsetvli x7,x6,e8,m1; la x5,src_a; vle8.v v2,(x5); \
    vadd.vi v4,v2,3; la x5,result; vse8.v v4,(x5); lbu x2,(x5); )

  TEST_CASE(2, x2, 0x0D, \
    li x6,2; vsetvli x7,x6,e8,m1; la x5,src_a; vle8.v v2,(x5); \
    li x5,3; vsub.vx v4,v2,x5; la x5,result; vse8.v v4,(x5); lbu x2,(x5); )

  TEST_CASE(3, x2, 0x0C, \
    li x6,2; vsetvli x7,x6,e8,m1; la x5,src_g; vle8.v v2,(x5); \
    vrsub.vi v4,v2,0x0F; la x5,result; vse8.v v4,(x5); lbu x2,(x5); )

  TEST_CASE(4, x2, 0x0C, \
    li x6,2; vsetvli x7,x6,e8,m1; la x5,src_b; vle8.v v2,(x5); \
    la x5,src_c; vle8.v v3,(x5); \
    vand.vv v4,v2,v3; la x5,result; vse8.v v4,(x5); lbu x2,(x5); )

  TEST_CASE(5, x2, 0x2F, \
    li x6,2; vsetvli x7,x6,e8,m1; la x5,src_a; vle8.v v2,(x5); \
    li x5,0x0F; vor.vx v4,v2,x5; la x5,result; vse8.v v4,(x5); lbu x2,1(x5); )

  TEST_CASE(6, x2, 0xFFFFFFFFFFFFFFF0, \
    li x6,2; vsetvli x7,x6,e8,m1; la x5,src_d; vle8.v v2,(x5); \
    vxor.vi v4,v2,0x0F; la x5,result; vse8.v v4,(x5); lb x2,(x5); )

  TEST_CASE(7, x2, 0xFFFFFFFFFFFFFFFE, \
    li x6,2; vsetvli x7,x6,e8,m1; la x5,src_e; vle8.v v2,(x5); \
    la x5,src_f; vle8.v v3,(x5); \
    vmin.vv v4,v2,v3; la x5,result; vse8.v v4,(x5); lb x2,(x5); )

  TEST_CASE(8, x2, 0x01, \
    li x6,2; vsetvli x7,x6,e8,m1; la x5,src_e; vle8.v v2,(x5); \
    la x5,src_f; vle8.v v3,(x5); \
    vminu.vv v4,v2,v3; la x5,result; vse8.v v4,(x5); lbu x2,(x5); )

  TEST_CASE(9, x2, 0x01, \
    li x6,2; vsetvli x7,x6,e8,m1; la x5,src_e; vle8.v v2,(x5); \
    li x5,1; vmax.vx v4,v2,x5; la x5,result; vse8.v v4,(x5); lbu x2,(x5); )

  TEST_CASE(10, x2, 0xFFFFFFFFFFFFFFFE, \
    li x6,2; vsetvli x7,x6,e8,m1; la x5,src_e; vle8.v v2,(x5); \
    la x5,src_f; vle8.v v3,(x5); \
    vmaxu.vv v4,v2,v3; la x5,result; vse8.v v4,(x5); lb x2,(x5); )

  # LMUL=8 group-crossing: vsub.vv at vl=20, element 16 = 0x10-0x01=0x0F
  TEST_CASE(11, x2, 0x0F, \
    li x6,20; vsetvli x7,x6,e8,m8; \
    la x5,lmul8_a; vle8.v v8,(x5); la x5,lmul8_b; vle8.v v16,(x5); \
    vsub.vv v24,v8,v16; \
    la x5,result; vse8.v v24,(x5); lbu x2,16(x5); )

  TEST_PASSFAIL

RVTEST_CODE_END

.data
  .balign 4
src_a: .byte 0x10, 0x20
src_b: .byte 0x3C, 0x55
src_c: .byte 0x0F, 0xAA
src_d: .byte 0xFF, 0x00
src_e: .byte 0xFE, 0x02
src_f: .byte 0x01, 0x01
src_g: .byte 0x03, 0x05
lmul8_a: .byte 0x01,0x02,0x03,0x04,0x05,0x06,0x07,0x08,0x09,0x0a,0x0b,0x0c,0x0d,0x0e,0x0f,0x10,0x10,0x11,0x12,0x13
lmul8_b: .byte 0x01,0x01,0x01,0x01,0x01,0x01,0x01,0x01,0x01,0x01,0x01,0x01,0x01,0x01,0x01,0x01,0x01,0x01,0x01,0x01

RVTEST_DATA_BEGIN
  .balign 8
result: .fill 24, 1, 0xff
RVTEST_DATA_END
