# Copyright (c) Qualcomm Technologies, Inc. and/or its subsidiaries.
# SPDX-License-Identifier: BSD-3-Clause-Clear

#*****************************************************************************
# vshift_widen.S — Phase 7: shifts, widening, narrowing, extension
#
# For widening, the destination holds 2*SEW elements. We store the result with
# vse8.v after resetting vtype to e8 with a vl large enough to cover the 16-bit
# results as byte pairs, and read back with lbu/lhu against little-endian layout.
#
# Test 1: vsll.vi  — [0x01] << 2 = 0x04
# Test 2: vsrl.vx  — [0x80] >> 2 = 0x20
# Test 3: vsra.vi  — [0x80(-128)] >>a 1 = 0xC0 (-64)
# Test 4: vwaddu.vv — 0xFF + 0x01 = 0x0100 (16-bit); low byte 0x00, byte1 0x01
# Test 5: vwmul.vv  — 0x7F * 0x02 = 0x00FE; low byte 0xFE
# Test 6: vwmulu.vv — 0xFF * 0x02 = 0x01FE; byte1 0x01, byte0 0xFE
# Test 7: vwmacc.vv — vd=0x0010 + 3*4 = 0x001C; low byte 0x1C
# Test 8: vnsrl.wv  — 0x0100 >> 4 = 0x10 (narrowed to 8-bit)
# Test 9: vsext.vf2 — 0xFF sign-ext to 16-bit = 0xFFFF; byte0 0xFF byte1 0xFF
# Test 10: vzext.vf2 — 0xFF zero-ext to 16-bit = 0x00FF; byte0 0xFF byte1 0x00
# Test 11: vsll.vv LMUL=8 — element 16 = 0x03 << 1 = 0x06

#include "riscv_test.h"
#include "test_macros.h"

RVTEST_RV64UV
RVTEST_CODE_BEGIN

  TEST_CASE(1, x2, 0x04, \
    li x6,2; vsetvli x7,x6,e8,m1; la x5,sh_a; vle8.v v2,(x5); \
    vsll.vi v4,v2,2; la x5,result; vse8.v v4,(x5); lbu x2,(x5); )

  TEST_CASE(2, x2, 0x20, \
    li x6,2; vsetvli x7,x6,e8,m1; la x5,sh_b; vle8.v v2,(x5); \
    li x5,2; vsrl.vx v4,v2,x5; la x5,result; vse8.v v4,(x5); lbu x2,(x5); )

  TEST_CASE(3, x2, 0xFFFFFFFFFFFFFFC0, \
    li x6,2; vsetvli x7,x6,e8,m1; la x5,sh_b; vle8.v v2,(x5); \
    vsra.vi v4,v2,1; la x5,result; vse8.v v4,(x5); lb x2,(x5); )

  # Widening add unsigned: result SEW=16. Store with e16, check halfword.
  TEST_CASE(4, x2, 0x0100, \
    li x6,2; vsetvli x7,x6,e8,m1; la x5,w_ff; vle8.v v2,(x5); la x5,w_01; vle8.v v3,(x5); \
    vwaddu.vv v4,v2,v3; \
    li x6,2; vsetvli x7,x6,e16,m1; la x5,result; vse16.v v4,(x5); lhu x2,(x5); )

  TEST_CASE(5, x2, 0x00FE, \
    li x6,2; vsetvli x7,x6,e8,m1; la x5,w_7f; vle8.v v2,(x5); la x5,w_02; vle8.v v3,(x5); \
    vwmul.vv v4,v2,v3; \
    li x6,2; vsetvli x7,x6,e16,m1; la x5,result; vse16.v v4,(x5); lhu x2,(x5); )

  TEST_CASE(6, x2, 0x01FE, \
    li x6,2; vsetvli x7,x6,e8,m1; la x5,w_ff; vle8.v v2,(x5); la x5,w_02; vle8.v v3,(x5); \
    vwmulu.vv v4,v2,v3; \
    li x6,2; vsetvli x7,x6,e16,m1; la x5,result; vse16.v v4,(x5); lhu x2,(x5); )

  # vwmacc: preload vd(v4) with 16-bit accumulator, then multiply-accumulate
  TEST_CASE(7, x2, 0x001C, \
    li x6,2; vsetvli x7,x6,e16,m1; la x5,mac_acc; vle16.v v4,(x5); \
    li x6,2; vsetvli x7,x6,e8,m1; la x5,mac_s1; vle8.v v2,(x5); la x5,mac_s2; vle8.v v3,(x5); \
    vwmacc.vv v4,v2,v3; \
    li x6,2; vsetvli x7,x6,e16,m1; la x5,result; vse16.v v4,(x5); lhu x2,(x5); )

  # Narrowing: src SEW=16 → dest SEW=8
  TEST_CASE(8, x2, 0x10, \
    li x6,2; vsetvli x7,x6,e16,m1; la x5,n_src; vle16.v v2,(x5); \
    li x6,2; vsetvli x7,x6,e8,m1; la x5,n_sh; vle8.v v3,(x5); \
    vnsrl.wv v4,v2,v3; la x5,result; vse8.v v4,(x5); lbu x2,(x5); )

  # Sign extension: src SEW=8 → dest SEW=16
  TEST_CASE(9, x2, 0xFFFF, \
    li x6,2; vsetvli x7,x6,e8,m1; la x5,w_ff; vle8.v v2,(x5); \
    li x6,2; vsetvli x7,x6,e16,m1; vsext.vf2 v4,v2; \
    la x5,result; vse16.v v4,(x5); lhu x2,(x5); )

  # Zero extension: src SEW=8 → dest SEW=16
  TEST_CASE(10, x2, 0x00FF, \
    li x6,2; vsetvli x7,x6,e8,m1; la x5,w_ff; vle8.v v2,(x5); \
    li x6,2; vsetvli x7,x6,e16,m1; vzext.vf2 v4,v2; \
    la x5,result; vse16.v v4,(x5); lhu x2,(x5); )

  # LMUL=8 group crossing: vsll.vv at element 16
  TEST_CASE(11, x2, 0x06, \
    li x6,20; vsetvli x7,x6,e8,m8; la x5,lmul8_val; vle8.v v8,(x5); \
    la x5,lmul8_sh; vle8.v v16,(x5); \
    vsll.vv v24,v8,v16; la x5,result; vse8.v v24,(x5); lbu x2,16(x5); )

  TEST_PASSFAIL

RVTEST_CODE_END

.data
  .balign 8
sh_a:   .byte 0x01, 0x02
sh_b:   .byte 0x80, 0x40
w_ff:   .byte 0xFF, 0xFF
w_01:   .byte 0x01, 0x01
w_02:   .byte 0x02, 0x02
w_7f:   .byte 0x7F, 0x7F
mac_acc: .short 0x0010, 0x0010
mac_s1:  .byte 0x03, 0x03
mac_s2:  .byte 0x04, 0x04
n_src:  .short 0x0100, 0x0200
n_sh:   .byte 0x04, 0x04
lmul8_val: .byte 0x01,0x02,0x03,0x04,0x05,0x06,0x07,0x08,0x09,0x0a,0x0b,0x0c,0x0d,0x0e,0x0f,0x10,0x03,0x04,0x05,0x06
lmul8_sh:  .byte 0x01,0x01,0x01,0x01,0x01,0x01,0x01,0x01,0x01,0x01,0x01,0x01,0x01,0x01,0x01,0x01,0x01,0x01,0x01,0x01

RVTEST_DATA_BEGIN
  .balign 8
result: .fill 48, 1, 0x00
RVTEST_DATA_END
