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

  TEST_PASSFAIL

RVTEST_CODE_END

.data
  .balign 8
s_ff: .byte 0xFF, 0xFF
s_7f: .byte 0x7F, 0x7F
s_01: .byte 0x01, 0x01
s_02: .byte 0x02, 0x02
s_03: .byte 0x03, 0x03
acc16: .short 0x0010, 0x0010
n16_src: .short 0xFF80, 0xFF80
n_sh3: .byte 0x03, 0x03

RVTEST_DATA_BEGIN
  .balign 8
result: .fill 16, 1, 0x00
RVTEST_DATA_END
