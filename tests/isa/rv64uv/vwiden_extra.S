# Copyright (c) Qualcomm Technologies, Inc. and/or its subsidiaries.
# SPDX-License-Identifier: BSD-3-Clause-Clear

#*****************************************************************************
# vwiden_extra.S — Phase 7 additional coverage: untested widening families
#
# Test 1: vwsub.vv signed — 0x7F-0x01=0x007E (16-bit); lhu=0x007E
# Test 2: vwsubu.vv unsigned — 0x02-0x01=0x0001 (16-bit); lhu=0x0001
# Test 3: vwmulsu.vv signed(vs2)*unsigned(vs1) — (-1)*2=0xFFFE; lhu=0xFFFE
# Test 4: vwmaccu.vv unsigned*unsigned+acc — 0x0010+2*3=0x0016; lhu=0x0016
# Test 5: vwmaccsu.vv signed(vs1)*unsigned(vs2)+acc — 0x0010+(-1)*2=0x000E; lhu=0x000E
# Test 6: vwmaccus.vx unsigned(rs1)*signed(vs2)+acc — 0x0010+2*(-1)=0x000E; lhu=0x000E
# Test 7: vnsra.wv arithmetic — 0xFF80>>3: 0xFF80 signed=-128, >>3=-16=0xF0; lbu=0xF0
# Test 8: vsext.vf4 — src SEW=8 val=0xFF, dest SEW=32: sign-ext=0xFFFFFFFF; lw sign-ext
# Test 9: vzext.vf4 — src SEW=8 val=0xFF, dest SEW=32: zero-ext=0x000000FF; lw=0xFF

#include "riscv_test.h"
#include "test_macros.h"

RVTEST_RV64UV
RVTEST_CODE_BEGIN

  TEST_CASE(1, x2, 0x007E, \
    li x6,2; vsetvli x7,x6,e8,m1; la x5,s_7f; vle8.v v2,(x5); la x5,s_01; vle8.v v3,(x5); \
    vwsub.vv v4,v2,v3; \
    li x6,2; vsetvli x7,x6,e16,m1; la x5,result; vse16.v v4,(x5); lhu x2,(x5); )

  TEST_CASE(2, x2, 0x0001, \
    li x6,2; vsetvli x7,x6,e8,m1; la x5,s_02; vle8.v v2,(x5); la x5,s_01; vle8.v v3,(x5); \
    vwsubu.vv v4,v2,v3; \
    li x6,2; vsetvli x7,x6,e16,m1; la x5,result; vse16.v v4,(x5); lhu x2,(x5); )

  # vwmulsu: signed(vs2=-1) * unsigned(vs1=2) = -2 = 0xFFFE (16-bit)
  TEST_CASE(3, x2, 0xFFFE, \
    li x6,2; vsetvli x7,x6,e8,m1; la x5,s_ff; vle8.v v2,(x5); la x5,s_02; vle8.v v3,(x5); \
    vwmulsu.vv v4,v2,v3; \
    li x6,2; vsetvli x7,x6,e16,m1; la x5,result; vse16.v v4,(x5); lhu x2,(x5); )

  # vwmaccu: acc=0x0010, 2*3=6, result=0x0016
  TEST_CASE(4, x2, 0x0016, \
    li x6,2; vsetvli x7,x6,e16,m1; la x5,acc16; vle16.v v4,(x5); \
    li x6,2; vsetvli x7,x6,e8,m1; la x5,s_02; vle8.v v2,(x5); la x5,s_03; vle8.v v3,(x5); \
    vwmaccu.vv v4,v2,v3; \
    li x6,2; vsetvli x7,x6,e16,m1; la x5,result; vse16.v v4,(x5); lhu x2,(x5); )

  # vwmaccsu: signed(vs1=0xFF=-1) * unsigned(vs2=2) = -2, acc=0x0010, result=0x000E
  TEST_CASE(5, x2, 0x000E, \
    li x6,2; vsetvli x7,x6,e16,m1; la x5,acc16; vle16.v v4,(x5); \
    li x6,2; vsetvli x7,x6,e8,m1; la x5,s_ff; vle8.v v2,(x5); la x5,s_02; vle8.v v3,(x5); \
    vwmaccsu.vv v4,v2,v3; \
    li x6,2; vsetvli x7,x6,e16,m1; la x5,result; vse16.v v4,(x5); lhu x2,(x5); )

  # vwmaccus: unsigned(rs1=2)*signed(vs2=0xFF=-1)=-2, acc=0x0010, result=0x000E
  TEST_CASE(6, x2, 0x000E, \
    li x6,2; vsetvli x7,x6,e16,m1; la x5,acc16; vle16.v v4,(x5); \
    li x6,2; vsetvli x7,x6,e8,m1; la x5,s_ff; vle8.v v2,(x5); \
    li x5,2; vwmaccus.vx v4,x5,v2; \
    li x6,2; vsetvli x7,x6,e16,m1; la x5,result; vse16.v v4,(x5); lhu x2,(x5); )

  # vnsra arithmetic: src 16-bit 0xFF80(-128 signed), >> 3 = -16 = 0xF0 (8-bit)
  TEST_CASE(7, x2, 0xFFFFFFFFFFFFFFF0, \
    li x6,2; vsetvli x7,x6,e16,m1; la x5,n16_src; vle16.v v2,(x5); \
    li x6,2; vsetvli x7,x6,e8,m1; la x5,n_sh3; vle8.v v3,(x5); \
    vnsra.wv v4,v2,v3; la x5,result; vse8.v v4,(x5); lb x2,(x5); )

  # vsext.vf4: src SEW=8 val=0xFF(-1), dest SEW=32, sign-ext=0xFFFFFFFF
  # lw sign-extends 32-bit: 0xFFFFFFFF -> 0xFFFFFFFFFFFFFFFF
  TEST_CASE(8, x2, 0xFFFFFFFFFFFFFFFF, \
    li x6,2; vsetvli x7,x6,e8,m1; la x5,s_ff; vle8.v v2,(x5); \
    li x6,2; vsetvli x7,x6,e32,m1; vsext.vf4 v4,v2; \
    la x5,result; vse32.v v4,(x5); lw x2,(x5); )

  # vzext.vf4: src SEW=8 val=0xFF, dest SEW=32, zero-ext=0x000000FF; lw=0xFF
  TEST_CASE(9, x2, 0x00000000000000FF, \
    li x6,2; vsetvli x7,x6,e8,m1; la x5,s_ff; vle8.v v2,(x5); \
    li x6,2; vsetvli x7,x6,e32,m1; vzext.vf4 v4,v2; \
    la x5,result; vse32.v v4,(x5); lw x2,(x5); )

  # Test 10: vwadd.wx signed — vs2(2xSEW)=[0x0010], xs1(SEW scalar)=0x01 → 0x0011
  TEST_CASE(10, x2, 0x0011, \
    li x6,2; vsetvli x7,x6,e16,m1; la x5,wx_wide; vle16.v v2,(x5); \
    li x5,1; \
    li x6,2; vsetvli x7,x6,e8,m1; vwadd.wx v4,v2,x5; \
    li x6,2; vsetvli x7,x6,e16,m1; la x5,result; vse16.v v4,(x5); lhu x2,(x5); )

  # Test 11: vwaddu.wx unsigned — vs2(2xSEW)=[0x00FF], xs1=1 → 0x0100
  TEST_CASE(11, x2, 0x0100, \
    li x6,2; vsetvli x7,x6,e16,m1; la x5,wx_ff; vle16.v v2,(x5); \
    li x5,1; \
    li x6,2; vsetvli x7,x6,e8,m1; vwaddu.wx v4,v2,x5; \
    li x6,2; vsetvli x7,x6,e16,m1; la x5,result; vse16.v v4,(x5); lhu x2,(x5); )

  # Test 12: vwsub.wx signed — vs2(2xSEW)=[0x0010], xs1=1 → 0x000F
  TEST_CASE(12, x2, 0x000F, \
    li x6,2; vsetvli x7,x6,e16,m1; la x5,wx_wide; vle16.v v2,(x5); \
    li x5,1; \
    li x6,2; vsetvli x7,x6,e8,m1; vwsub.wx v4,v2,x5; \
    li x6,2; vsetvli x7,x6,e16,m1; la x5,result; vse16.v v4,(x5); lhu x2,(x5); )

  # Test 13: vwsubu.wx unsigned — vs2(2xSEW=16-bit)=[0x00FE=254], xs1=1 → 0x00FD (16-bit)
  # vs2 is the widened source (.w operand), must be loaded at 2*SEW=16-bit width.
  TEST_CASE(13, x2, 0x00FD, \
    li x6,2; vsetvli x7,x6,e16,m1; la x5,wx_fe; vle16.v v2,(x5); \
    li x5,1; \
    li x6,2; vsetvli x7,x6,e8,m1; vwsubu.wx v4,v2,x5; \
    li x6,2; vsetvli x7,x6,e16,m1; la x5,result; vse16.v v4,(x5); lhu x2,(x5); )

  # Test 14: vsext.vf8 — src SEW=8 [0xFF=-1], dest SEW=64, sign-ext=0xFFFFFFFFFFFFFFFF
  # Requires SEW=64 which means e64; source group uses SEW=8 EMUL=LMUL/8=m1/8=mf8
  # vsetvli e64,m1 gives VLMAX=VLEN/64=2 elements. Source at SEW=8 → EMUL=mf8, SEW=8.
  TEST_CASE(14, x2, 0xFFFFFFFFFFFFFFFF, \
    li x6,2; vsetvli x7,x6,e8,m1; la x5,s_ff; vle8.v v2,(x5); \
    li x6,2; vsetvli x7,x6,e64,m1; vsext.vf8 v4,v2; \
    la x5,result; vse64.v v4,(x5); ld x2,(x5); )

  # Test 15: vzext.vf8 — src SEW=8 [0xFF=255], dest SEW=64, zero-ext=0x00000000000000FF
  TEST_CASE(15, x2, 0x00000000000000FF, \
    li x6,2; vsetvli x7,x6,e8,m1; la x5,s_ff; vle8.v v2,(x5); \
    li x6,2; vsetvli x7,x6,e64,m1; vzext.vf8 v4,v2; \
    la x5,result; vse64.v v4,(x5); ld x2,(x5); )

  # Test 16: Widening at LMUL=4 (dest crosses into LMUL=8 territory)
  # SEW=8, LMUL=4: VLMAX=64. vwadd dest LMUL=8, dest has 8 registers (v8-v15).
  # Use vl=20 so elements 16-19 cross into the second dest register of the 2xSEW group.
  # v8 group (LMUL=4) holds elements 0-63 at SEW=8.
  # v16 group (LMUL=8) holds elements 0-63 at SEW=16 (dest).
  # Element 16 of the dest group: elems_per_reg_d = 128/(8*2) = 8. Element 16/8=reg_off=2.
  # Check element 16 = 0x01 + 0x02 = 0x0003 (16-bit). Store as e16, lhu byte 32.
  TEST_CASE(16, x2, 0x0003, \
    li x6,20; vsetvli x7,x6,e8,m4; \
    la x5,lmul4_a; vle8.v v8,(x5); la x5,lmul4_b; vle8.v v12,(x5); \
    vwaddu.vv v16,v8,v12; \
    li x6,20; vsetvli x7,x6,e16,m8; la x5,result; vse16.v v16,(x5); lhu x2,32(x5); )

  TEST_PASSFAIL

RVTEST_CODE_END

.data
  .balign 8
s_ff: .byte 0xFF, 0xFF
s_fe: .byte 0xFE, 0xFE
s_7f: .byte 0x7F, 0x7F
s_01: .byte 0x01, 0x01
s_02: .byte 0x02, 0x02
s_03: .byte 0x03, 0x03
acc16: .short 0x0010, 0x0010
n16_src: .short 0xFF80, 0xFF80
n_sh3: .byte 0x03, 0x03
wx_wide: .short 0x0010, 0x0010   # 2xSEW source for .wx tests
wx_ff:   .short 0x00FF, 0x00FF   # 0x00FF for vwaddu.wx
wx_100:  .short 0x0100, 0x0100   # 0x0100 for vwsubu.wx
wx_fe:   .short 0x00FE, 0x00FE   # 0x00FE for vwsubu.wx test 13
lmul4_a: .byte 0x01,0x01,0x01,0x01,0x01,0x01,0x01,0x01,0x01,0x01,0x01,0x01,0x01,0x01,0x01,0x01,0x01,0x01,0x01,0x01
lmul4_b: .byte 0x02,0x02,0x02,0x02,0x02,0x02,0x02,0x02,0x02,0x02,0x02,0x02,0x02,0x02,0x02,0x02,0x02,0x02,0x02,0x02

RVTEST_DATA_BEGIN
  .balign 8
result: .fill 64, 1, 0x00
RVTEST_DATA_END
