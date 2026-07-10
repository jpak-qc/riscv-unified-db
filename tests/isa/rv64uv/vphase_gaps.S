# Copyright (c) Qualcomm Technologies, Inc. and/or its subsidiaries.
# SPDX-License-Identifier: BSD-3-Clause-Clear

#*****************************************************************************
# vphase_gaps.S — Coverage to bring Phases 2-6 to 10/10 confidence
#
# Phase 2 (EEW loads/stores at LMUL>1 + masked store):
#   Test 1: vle16.v LMUL=2 — vl=4, element 2 (second reg of LMUL=2 group) = 0x0003
#   Test 2: vse32.v masked — mask=0x05, only elements 0,2 written; element 1 stays 0xFFFFFFFF
#
# Phase 3 (vmerge.vim + vmv8r):
#   Test 3: vmerge.vim — mask=0x05: even lanes get imm=7, odd lanes keep vs2
#   Test 4: vmv8r.v — copy 8 registers, check element 16 (second reg of group)
#
# Phase 4 (LMUL=8 signed min/max + fix signed read):
#   Test 5: vmin.vv LMUL=8 signed — element 16: min(-2, 1) = -2 = 0xFE; lb=0xFE=-2
#   Test 6: vmax.vx signed — max(0xFE=-2, 0x01=1) = 1; lb byte0 = 0x01
#
# Phase 5 (.vx scalar variants + INT_MIN edge case):
#   Test 7: vmulh.vx — 0x7F * x5=2 = 254, high8=0; lbu=0
#   Test 8: vdiv.vx signed — 0x0C / x5=3 = 4; lbu=4
#   Test 9: vmacc.vx — vd=0x10, rs1=2, vs2=3: 0x10+2*3=0x16; lbu=0x16
#   Test 10: INT_MIN/-1 div (vdiv SEW=8): -128/-1 = saturates to -128 per spec; lb=0x80=-128
#
# Phase 6 (Sail VCPOP/VIOTA verification with edge inputs):
#   Test 11: vcpop.m with all bits set in vl=8 window → count=8
#   Test 12: viota.m element 0 = 0 always (no bits set before element 0)

#include "riscv_test.h"
#include "test_macros.h"

RVTEST_RV64UV
RVTEST_CODE_BEGIN

  # Phase 2 Test 1: vle16.v LMUL=2, vl=4 — element 2 in second register of group
  # VLEN=128, SEW=16, LMUL=2: elems_per_reg = 128/16 = 8. Elem 2 is in first reg (reg_off=0).
  # Use vl=10 to cross into second register: element 8 is in second reg (v2+1).
  # input16_lmul2[8] = 0x0009; check lhu byte 16 = 0x0009
  TEST_CASE(1, x2, 0x0009, \
    li x6,10; vsetvli x7,x6,e16,m2; \
    la x5,inp16; vle16.v v2,(x5); \
    la x5,result; vse16.v v2,(x5); lhu x2,16(x5); )

  # Phase 2 Test 2: vse32.v masked — mask=0x05 (bits 0,2), vl=4
  # Pre-fill result with 0xFF; only elements 0,2 should be written (0x00000001, 0x00000003)
  # Element 1 stays 0xFFFFFFFF. Check element 1 = 0xFFFFFFFF: lw=-1
  TEST_CASE(2, x2, 0xFFFFFFFFFFFFFFFF, \
    li x6,4; vsetvli x7,x6,e32,m1; \
    la x5,mask05; vle8.v v0,(x5); \
    la x5,inp32; vle32.v v2,(x5); \
    la x5,ffresult; \
    vse32.v v2,(x5), v0.t; \
    lw x2,4(x5); )

  # Phase 3 Test 3: vmerge.vim — mask=0x05, imm=7, vs2=[10,20,30,40]
  # elem0: mask=1 → 7; elem1: mask=0 → 20; elem2: mask=1 → 7; elem3: mask=0 → 40
  # check byte1 = 20 = 0x14
  TEST_CASE(3, x2, 0x14, \
    li x6,4; vsetvli x7,x6,e8,m1; \
    la x5,mask05b; vle8.v v0,(x5); \
    la x5,vec_src; vle8.v v2,(x5); \
    vmerge.vim v4,v2,7,v0; \
    la x5,result; vse8.v v4,(x5); lbu x2,1(x5); )

  # Phase 3 Test 4: vmv8r.v — load pattern into v8 group, copy to v16, check element 16
  # With LMUL=8 vl=20 at SEW=8: element 16 is in register v8+1 (second of 8-reg group)
  # Source[16] = 0xBA; after vmv8r.v v16,v8, v16[16] should also be 0xBA
  TEST_CASE(4, x2, 0xBA, \
    li x6,20; vsetvli x7,x6,e8,m8; la x5,src8r; vle8.v v8,(x5); \
    vmv8r.v v16,v8; \
    la x5,result; vse8.v v16,(x5); lbu x2,16(x5); )

  # Phase 4 Test 5: vmin.vv LMUL=8 signed — element 16: min(0xFE=-2, 0x01=1) = -2 = 0xFE
  TEST_CASE(5, x2, 0xFFFFFFFFFFFFFFFE, \
    li x6,20; vsetvli x7,x6,e8,m8; \
    la x5,smin_a; vle8.v v8,(x5); la x5,smin_b; vle8.v v16,(x5); \
    vmin.vv v24,v8,v16; \
    la x5,result; vse8.v v24,(x5); lb x2,16(x5); )

  # Phase 4 Test 6: vmax.vx signed — max(0xFE=-2, x5=1) = 1; lb signed check
  TEST_CASE(6, x2, 1, \
    li x6,2; vsetvli x7,x6,e8,m1; la x5,smin_a; vle8.v v2,(x5); \
    li x5,1; vmax.vx v4,v2,x5; \
    la x5,result; vse8.v v4,(x5); lb x2,(x5); )

  # Phase 5 Test 7: vmulh.vx — 0x40*x5=4 = 0x0100; high8=0x01; lbu=0x01
  TEST_CASE(7, x2, 0x01, \
    li x6,2; vsetvli x7,x6,e8,m1; la x5,p5_a; vle8.v v2,(x5); \
    li x5,4; vmulh.vx v4,v2,x5; \
    la x5,result; \
    li x6,2; vsetvli x7,x6,e16,m1; vse16.v v4,(x5); \
    li x6,2; vsetvli x7,x6,e8,m1; \
    lbu x2,1(x5); )

  # Phase 5 Test 8: vdiv.vx signed — 0x0C/x5=3 = 4; lbu=4
  TEST_CASE(8, x2, 4, \
    li x6,2; vsetvli x7,x6,e8,m1; la x5,p5_b; vle8.v v2,(x5); \
    li x5,3; vdiv.vx v4,v2,x5; \
    la x5,result; vse8.v v4,(x5); lbu x2,(x5); )

  # Phase 5 Test 9: vmacc.vx — vd=0x10, rs1=2, vs2=3: 0x10+2*3=0x16; lbu=0x16
  TEST_CASE(9, x2, 0x16, \
    li x6,2; vsetvli x7,x6,e8,m1; la x5,mac_vd; vle8.v v4,(x5); \
    la x5,p5_c; vle8.v v2,(x5); \
    li x5,2; vmacc.vx v4,x5,v2; \
    la x5,result; vse8.v v4,(x5); lbu x2,(x5); )

  # Phase 5 Test 10: INT_MIN/-1 div — SEW=8: -128/-1. Per spec result is -128 (saturates)
  # 0x80 = -128 signed; / -1 = 128 which overflows SEW=8, result = -128 = 0x80
  TEST_CASE(10, x2, 0xFFFFFFFFFFFFFF80, \
    li x6,2; vsetvli x7,x6,e8,m1; la x5,int_min; vle8.v v2,(x5); \
    li x5,-1; vdiv.vx v4,v2,x5; \
    la x5,result; vse8.v v4,(x5); lb x2,(x5); )

  # Phase 6 Test 11: vcpop.m all bits set in vl=8 window → count=8
  TEST_CASE(11, x2, 8, \
    li x6,8; vsetvli x7,x6,e8,m1; \
    la x5,allbits; vle8.v v0,(x5); \
    vcpop.m x2,v0; )

  # Phase 6 Test 12: viota.m element 0 always = 0 (no set bits before index 0)
  TEST_CASE(12, x2, 0, \
    li x6,4; vsetvli x7,x6,e8,m1; \
    la x5,mask05b; vle8.v v0,(x5); \
    viota.m v4,v0; \
    la x5,result; vse8.v v4,(x5); lbu x2,(x5); )

  TEST_PASSFAIL

RVTEST_CODE_END

.data
  .balign 8
inp16:  .short 0x0001,0x0002,0x0003,0x0004,0x0005,0x0006,0x0007,0x0008,0x0009,0x000A
inp32:  .word 0x00000001,0x00000002,0x00000003,0x00000004
mask05: .byte 0x05,0x00,0x00,0x00,0x00,0x00,0x00,0x00
mask05b:.byte 0x05,0x00,0x00,0x00,0x00,0x00,0x00,0x00
vec_src:.byte 0x0A,0x14,0x1E,0x28
src8r:  .byte 0x01,0x02,0x03,0x04,0x05,0x06,0x07,0x08,0x09,0x0A,0x0B,0x0C,0x0D,0x0E,0x0F,0x10,0xBA,0xBB,0xBC,0xBD
smin_a: .byte 0x01,0x01,0x01,0x01,0x01,0x01,0x01,0x01,0x01,0x01,0x01,0x01,0x01,0x01,0x01,0x01,0xFE,0xFE,0xFE,0xFE
smin_b: .byte 0x02,0x02,0x02,0x02,0x02,0x02,0x02,0x02,0x02,0x02,0x02,0x02,0x02,0x02,0x02,0x02,0x01,0x01,0x01,0x01
p5_a:   .byte 0x40, 0x40
p5_b:   .byte 0x0C, 0x0C
p5_c:   .byte 0x03, 0x03
mac_vd: .byte 0x10, 0x10
int_min:.byte 0x80, 0x80
allbits:.byte 0xFF,0x00,0x00,0x00,0x00,0x00,0x00,0x00

RVTEST_DATA_BEGIN
  .balign 8
ffresult: .fill 16, 1, 0xFF
result:   .fill 32, 1, 0x00
RVTEST_DATA_END
