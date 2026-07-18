# Copyright (c) Qualcomm Technologies, Inc. and/or its subsidiaries.
# SPDX-License-Identifier: BSD-3-Clause-Clear

#*****************************************************************************
# vsmul.S — Phase 13 Group B: signed saturating fractional multiply
# SEW=8, LMUL=1, vl=2. Result = roundoff_signed(a*b, SEW-1); shift=7.
# Default rounding mode rnu (vxrm=0) unless a test sets vxrm.
#
# Test 1: vsmul.vv  0x40*0x40 = 4096>>7 = 32 = 0x20 (no rounding, bit6=0)
# Test 2: vsmul.vv  0x7F*0x7F = 16129>>7 = 126 = 0x7E (bit6=0)
# Test 3: vsmul.vv  INT_MIN*INT_MIN: 0x80*0x80 saturates to INT_MAX = 0x7F, vxsat=1
# Test 4: vsmul.vv  negative result: 0x80(-128)*0x02(2) = -256>>7 = -2 = 0xFE
# Test 5: vsmul.vx  0x40 * scalar 0x40 = 0x20
# Test 6: vsmul.vv  rnu rounds up: 0x0A*0x0A = 100, bit6=1 → (100>>7)+1 = 0+1 = 0x01
# Test 7: vsmul.vv  rdn truncates: same 0x0A*0x0A with vxrm=rdn(2) → 100>>7 = 0x00
# Test 8: vxsat readback — after test 3's INT_MIN^2 saturation, vxsat[0] = 1
# Test 9: vxsat stays clear — non-saturating vsmul leaves vxsat = 0

#include "riscv_test.h"
#include "test_macros.h"

RVTEST_RV64UV
RVTEST_CODE_BEGIN

  # Test 1: vsmul.vv 0x40*0x40 -> 0x20
  TEST_CASE(1, x2, 0x20, \
    csrw vxsat,x0; csrw vxrm,x0; \
    li x6,2; vsetvli x7,x6,e8,m1; la x5,s_40; vle8.v v2,(x5); la x5,s_40; vle8.v v3,(x5); \
    vsmul.vv v4,v2,v3; la x5,result; vse8.v v4,(x5); lbu x2,(x5); )

  # Test 2: vsmul.vv 0x7F*0x7F -> 0x7E
  TEST_CASE(2, x2, 0x7E, \
    csrw vxrm,x0; \
    li x6,2; vsetvli x7,x6,e8,m1; la x5,s_7f; vle8.v v2,(x5); la x5,s_7f; vle8.v v3,(x5); \
    vsmul.vv v4,v2,v3; la x5,result; vse8.v v4,(x5); lbu x2,(x5); )

  # Test 3: vsmul.vv INT_MIN*INT_MIN saturates to 0x7F
  TEST_CASE(3, x2, 0x7F, \
    csrw vxsat,x0; csrw vxrm,x0; \
    li x6,2; vsetvli x7,x6,e8,m1; la x5,s_80; vle8.v v2,(x5); la x5,s_80; vle8.v v3,(x5); \
    vsmul.vv v4,v2,v3; la x5,result; vse8.v v4,(x5); lbu x2,(x5); )

  # Test 4: vsmul.vv negative result 0x80*0x02 = -256>>7 = 0xFE
  TEST_CASE(4, x2, 0xFE, \
    csrw vxrm,x0; \
    li x6,2; vsetvli x7,x6,e8,m1; la x5,s_80; vle8.v v2,(x5); la x5,s_02; vle8.v v3,(x5); \
    vsmul.vv v4,v2,v3; la x5,result; vse8.v v4,(x5); lbu x2,(x5); )

  # Test 5: vsmul.vx 0x40 * scalar 0x40 -> 0x20
  TEST_CASE(5, x2, 0x20, \
    csrw vxrm,x0; \
    li x6,2; vsetvli x7,x6,e8,m1; la x5,s_40; vle8.v v2,(x5); \
    li x5,0x40; vsmul.vx v4,v2,x5; la x5,result; vse8.v v4,(x5); lbu x2,(x5); )

  # Test 6: vsmul.vv rnu rounds up 0x0A*0x0A -> 0x01
  TEST_CASE(6, x2, 0x01, \
    csrw vxrm,x0; \
    li x6,2; vsetvli x7,x6,e8,m1; la x5,s_0a; vle8.v v2,(x5); la x5,s_0a; vle8.v v3,(x5); \
    vsmul.vv v4,v2,v3; la x5,result; vse8.v v4,(x5); lbu x2,(x5); )

  # Test 7: vsmul.vv rdn truncates 0x0A*0x0A -> 0x00 (vxrm=2)
  TEST_CASE(7, x2, 0x00, \
    li x4,2; csrw vxrm,x4; \
    li x6,2; vsetvli x7,x6,e8,m1; la x5,s_0a; vle8.v v2,(x5); la x5,s_0a; vle8.v v3,(x5); \
    vsmul.vv v4,v2,v3; la x5,result; vse8.v v4,(x5); lbu x2,(x5); csrw vxrm,x0; )

  # Test 8: vxsat set after INT_MIN^2 saturation
  TEST_CASE(8, x2, 0x01, \
    csrw vxsat,x0; csrw vxrm,x0; \
    li x6,2; vsetvli x7,x6,e8,m1; la x5,s_80; vle8.v v2,(x5); la x5,s_80; vle8.v v3,(x5); \
    vsmul.vv v4,v2,v3; csrr x2,vxsat; )

  # Test 9: vxsat stays clear on non-saturating vsmul
  TEST_CASE(9, x2, 0x00, \
    csrw vxsat,x0; csrw vxrm,x0; \
    li x6,2; vsetvli x7,x6,e8,m1; la x5,s_40; vle8.v v2,(x5); la x5,s_40; vle8.v v3,(x5); \
    vsmul.vv v4,v2,v3; csrr x2,vxsat; )

  TEST_PASSFAIL

RVTEST_CODE_END

.data
  .balign 8
s_40: .byte 0x40, 0x40
s_7f: .byte 0x7F, 0x7F
s_80: .byte 0x80, 0x80
s_02: .byte 0x02, 0x02
s_0a: .byte 0x0A, 0x0A

RVTEST_DATA_BEGIN
  .balign 8
result: .fill 16, 1, 0x00
RVTEST_DATA_END
