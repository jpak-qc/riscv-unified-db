# Copyright (c) Qualcomm Technologies, Inc. and/or its subsidiaries.
# SPDX-License-Identifier: BSD-3-Clause-Clear

#*****************************************************************************
# vsat_addsub.S — Phase 13 Group A: saturating add/sub + vxsat flag
# SEW=8, LMUL=1, vl=2 unless noted.
#
# Test 1: vsadd.vv  signed sat high — 0x7F + 0x01 = 0x80 > INT8_MAX → 0x7F
# Test 2: vsadd.vv  signed sat low  — 0x80(-128) + 0xFF(-1) = -129 < INT8_MIN → 0x80
# Test 3: vsadd.vx  signed sat high — 0x7F + 1 → 0x7F
# Test 4: vsadd.vi  signed no-sat   — 0x10 + 5 = 0x15
# Test 5: vsaddu.vv unsigned sat    — 0xFF + 0x01 = 0x100 > UINT8_MAX → 0xFF
# Test 6: vsaddu.vx unsigned no-sat — 0x10 + 5 = 0x15
# Test 7: vssub.vv  signed sat low  — 0x80(-128) - 0x01(1) = -129 → 0x80
# Test 8: vssubu.vv unsigned borrow — 0x01 - 0x02 → saturates to 0x00
# Test 9: vssubu.vx unsigned no-sat — 0x05 - 3 = 0x02
# Test 10: vxsat readback — after test 1's saturation, vxsat[0] must read 1
# Test 11: vxsat stays clear — clear vxsat, run non-saturating vsadd, vxsat must read 0

#include "riscv_test.h"
#include "test_macros.h"

RVTEST_RV64UV
RVTEST_CODE_BEGIN

  # Test 1: vsadd.vv signed positive saturation → 0x7F
  TEST_CASE(1, x2, 0x7F, \
    li x6,2; vsetvli x7,x6,e8,m1; la x5,s_7f; vle8.v v2,(x5); la x5,s_01; vle8.v v3,(x5); \
    vsadd.vv v4,v2,v3; la x5,result; vse8.v v4,(x5); lbu x2,(x5); )

  # Test 2: vsadd.vv signed negative saturation: -128 + -1 = -129 → -128 = 0x80
  TEST_CASE(2, x2, 0x80, \
    li x6,2; vsetvli x7,x6,e8,m1; la x5,s_80; vle8.v v2,(x5); la x5,s_ff; vle8.v v3,(x5); \
    vsadd.vv v4,v2,v3; la x5,result; vse8.v v4,(x5); lbu x2,(x5); )

  # Test 3: vsadd.vx signed positive saturation with scalar 1 → 0x7F
  TEST_CASE(3, x2, 0x7F, \
    li x6,2; vsetvli x7,x6,e8,m1; la x5,s_7f; vle8.v v2,(x5); \
    li x5,1; vsadd.vx v4,v2,x5; la x5,result; vse8.v v4,(x5); lbu x2,(x5); )

  # Test 4: vsadd.vi no saturation: 0x10 + 5 = 0x15
  TEST_CASE(4, x2, 0x15, \
    li x6,2; vsetvli x7,x6,e8,m1; la x5,s_10; vle8.v v2,(x5); \
    vsadd.vi v4,v2,5; la x5,result; vse8.v v4,(x5); lbu x2,(x5); )

  # Test 5: vsaddu.vv unsigned saturation: 0xFF + 0x01 → 0xFF
  TEST_CASE(5, x2, 0xFF, \
    li x6,2; vsetvli x7,x6,e8,m1; la x5,s_ff; vle8.v v2,(x5); la x5,s_01; vle8.v v3,(x5); \
    vsaddu.vv v4,v2,v3; la x5,result; vse8.v v4,(x5); lbu x2,(x5); )

  # Test 6: vsaddu.vx no saturation: 0x10 + 5 = 0x15
  TEST_CASE(6, x2, 0x15, \
    li x6,2; vsetvli x7,x6,e8,m1; la x5,s_10; vle8.v v2,(x5); \
    li x5,5; vsaddu.vx v4,v2,x5; la x5,result; vse8.v v4,(x5); lbu x2,(x5); )

  # Test 7: vssub.vv signed negative saturation: -128 - 1 = -129 → -128 = 0x80
  TEST_CASE(7, x2, 0x80, \
    li x6,2; vsetvli x7,x6,e8,m1; la x5,s_80; vle8.v v2,(x5); la x5,s_01; vle8.v v3,(x5); \
    vssub.vv v4,v2,v3; la x5,result; vse8.v v4,(x5); lbu x2,(x5); )

  # Test 8: vssubu.vv unsigned borrow saturates to 0: 0x01 - 0x02 → 0x00
  TEST_CASE(8, x2, 0x00, \
    li x6,2; vsetvli x7,x6,e8,m1; la x5,s_01; vle8.v v2,(x5); la x5,s_02; vle8.v v3,(x5); \
    vssubu.vv v4,v2,v3; la x5,result; vse8.v v4,(x5); lbu x2,(x5); )

  # Test 9: vssubu.vx no saturation: 0x05 - 3 = 0x02
  TEST_CASE(9, x2, 0x02, \
    li x6,2; vsetvli x7,x6,e8,m1; la x5,s_05; vle8.v v2,(x5); \
    li x5,3; vssubu.vx v4,v2,x5; la x5,result; vse8.v v4,(x5); lbu x2,(x5); )

  # Test 10: vxsat readback — clear vxsat, run a SATURATING vsadd, vxsat[0] must be 1
  TEST_CASE(10, x2, 0x01, \
    csrw vxsat,x0; \
    li x6,2; vsetvli x7,x6,e8,m1; la x5,s_7f; vle8.v v2,(x5); la x5,s_01; vle8.v v3,(x5); \
    vsadd.vv v4,v2,v3; csrr x2,vxsat; )

  # Test 11: vxsat stays clear — clear vxsat, run a NON-saturating vsadd, vxsat[0] must be 0
  TEST_CASE(11, x2, 0x00, \
    csrw vxsat,x0; \
    li x6,2; vsetvli x7,x6,e8,m1; la x5,s_10; vle8.v v2,(x5); la x5,s_01; vle8.v v3,(x5); \
    vsadd.vv v4,v2,v3; csrr x2,vxsat; )

  TEST_PASSFAIL

RVTEST_CODE_END

.data
  .balign 8
s_7f: .byte 0x7F, 0x7F
s_80: .byte 0x80, 0x80
s_ff: .byte 0xFF, 0xFF
s_01: .byte 0x01, 0x01
s_02: .byte 0x02, 0x02
s_05: .byte 0x05, 0x05
s_10: .byte 0x10, 0x10

RVTEST_DATA_BEGIN
  .balign 8
result: .fill 16, 1, 0x00
RVTEST_DATA_END
