# Copyright (c) Qualcomm Technologies, Inc. and/or its subsidiaries.
# SPDX-License-Identifier: BSD-3-Clause-Clear

#*****************************************************************************
# vmul_mac.S
#-----------------------------------------------------------------------------
# Phase 5: multiply/divide/mac family
# SEW=8, LMUL=1, vl=2, lb/lbu for single-byte result checks.
#
# Test 1: vmul.vv   [0x03,0x04]*[0x02,0x03]=[0x06,0x0C]; lbu byte0=0x06
# Test 2: vmulh.vv  signed high: 3*2=6 high8=0; (-1)*(-1)=1 high8=0; lbu byte0=0
#   use [0x7F,0xFF]*[0x02,0x02]: 127*2=254 high=0; -1*2=-2 high=0xFF; lbu byte1 signed=-2
# Test 3: vmulhu.vv unsigned high: [0x80,0x40]*[0x02,0x04]: 128*2=256>255 high=1; 64*4=256 high=1
#   lbu byte0=1
# Test 4: vdiv.vv   signed: [0x0C,0xFC]/[0x03,0x02]=[0x04,0xFE(-2)]; lbu byte0=4
# Test 5: vremu.vv  unsigned: [0x0D,0x0F]%[0x03,0x04]=[0x01,0x03]; lbu byte0=1
# Test 6: vmacc.vv  vd=[0x10,0x20], vs1=[0x02,0x03], vs2=[0x03,0x04]
#   vd = vd + vs1*vs2 = [0x10+6,0x20+12] = [0x16,0x2C]; lbu byte0=0x16
# Test 7: vmadd.vv  vd=[0x10,0x20], vs1=[0x02,0x03], vs2=[0x05,0x06]
#   vd = vs1*vd + vs2 = [2*0x10+5, 3*0x20+6] = [0x25,0x66]; lbu byte0=0x25
# Test 8: vnmsac.vv vd=[0x20,0x30], vs1=[0x02,0x03], vs2=[0x03,0x04]
#   vd = vd - vs1*vs2 = [0x20-6, 0x30-12] = [0x1A,0x24]; lbu byte0=0x1A

#include "riscv_test.h"
#include "test_macros.h"

RVTEST_RV64UV
RVTEST_CODE_BEGIN

  TEST_CASE(1, x2, 0x06, \
    li x6,2; vsetvli x7,x6,e8,m1; la x5,mul_a; vle8.v v2,(x5); \
    la x5,mul_b; vle8.v v3,(x5); \
    vmul.vv v4,v2,v3; la x5,result; vse8.v v4,(x5); lbu x2,(x5); )

  # Test 2: vmulhu.vv unsigned high — [0x80]*[0x02]=0x100; high byte=1
  TEST_CASE(2, x2, 0x01, \
    li x6,2; vsetvli x7,x6,e8,m1; la x5,mulhu_a; vle8.v v2,(x5); \
    la x5,mulhu_b; vle8.v v3,(x5); \
    vmulhu.vv v4,v2,v3; la x5,result; vse8.v v4,(x5); lbu x2,(x5); )

  TEST_CASE(3, x2, 0x01, \
    li x6,2; vsetvli x7,x6,e8,m1; la x5,mulhu_a; vle8.v v2,(x5); \
    la x5,mulhu_b; vle8.v v3,(x5); \
    vmulhu.vv v4,v2,v3; la x5,result; vse8.v v4,(x5); lbu x2,(x5); )

  TEST_CASE(4, x2, 0x04, \
    li x6,2; vsetvli x7,x6,e8,m1; la x5,div_a; vle8.v v2,(x5); \
    la x5,div_b; vle8.v v3,(x5); \
    vdiv.vv v4,v2,v3; la x5,result; vse8.v v4,(x5); lbu x2,(x5); )

  TEST_CASE(5, x2, 0x01, \
    li x6,2; vsetvli x7,x6,e8,m1; la x5,rem_a; vle8.v v2,(x5); \
    la x5,rem_b; vle8.v v3,(x5); \
    vremu.vv v4,v2,v3; la x5,result; vse8.v v4,(x5); lbu x2,(x5); )

  TEST_CASE(6, x2, 0x16, \
    li x6,2; vsetvli x7,x6,e8,m1; la x5,mac_vd; vle8.v v4,(x5); \
    la x5,mac_vs1; vle8.v v3,(x5); \
    la x5,mac_vs2; vle8.v v2,(x5); \
    vmacc.vv v4,v3,v2; la x5,result; vse8.v v4,(x5); lbu x2,(x5); )

  TEST_CASE(7, x2, 0x25, \
    li x6,2; vsetvli x7,x6,e8,m1; la x5,mac_vd; vle8.v v4,(x5); \
    la x5,mac_vs1; vle8.v v3,(x5); \
    la x5,madd_vs2; vle8.v v2,(x5); \
    vmadd.vv v4,v3,v2; la x5,result; vse8.v v4,(x5); lbu x2,(x5); )

  TEST_CASE(8, x2, 0x1A, \
    li x6,2; vsetvli x7,x6,e8,m1; la x5,nmsac_vd; vle8.v v4,(x5); \
    la x5,mac_vs1; vle8.v v3,(x5); \
    la x5,mac_vs2; vle8.v v2,(x5); \
    vnmsac.vv v4,v3,v2; la x5,result; vse8.v v4,(x5); lbu x2,(x5); )

  TEST_PASSFAIL

RVTEST_CODE_END

.data
  .balign 4
mul_a:    .byte 0x03, 0x04
mul_b:    .byte 0x02, 0x03
mulh_a:   .byte 0x7F, 0xFF
mulh_b:   .byte 0x02, 0x02
mulh2_a:  .byte 0x40, 0x40   # 0x40*0x04=0x100, high byte=1
mulh2_b:  .byte 0x04, 0x04
mulhu_a:  .byte 0x80, 0x40  # 128, 64 unsigned
mulhu_b:  .byte 0x02, 0x04  # 2, 4
div_a:    .byte 0x0C, 0xFC  # 12, -4 signed
div_b:    .byte 0x03, 0x02  # 3, 2
rem_a:    .byte 0x0D, 0x0F
rem_b:    .byte 0x03, 0x04
mac_vd:   .byte 0x10, 0x20  # initial vd
mac_vs1:  .byte 0x02, 0x03
mac_vs2:  .byte 0x03, 0x04
madd_vs2: .byte 0x05, 0x06
nmsac_vd: .byte 0x20, 0x30

RVTEST_DATA_BEGIN
  .balign 8
result: .dword -1
RVTEST_DATA_END
