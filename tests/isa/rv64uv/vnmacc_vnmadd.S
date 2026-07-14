# Copyright (c) Qualcomm Technologies, Inc. and/or its subsidiaries.
# SPDX-License-Identifier: BSD-3-Clause-Clear

#*****************************************************************************
# vnmacc_vnmadd.S
#-----------------------------------------------------------------------------
# ISS tests for vnmacc.vv, vnmacc.vx, vnmadd.vv, vnmadd.vx
# SEW=8, LMUL=1, vl=2.
#
# vnmacc semantics: vd[i] = -(vs1[i] * vs2[i]) - vd[i]
# vnmadd semantics: vd[i] = -(vs1[i] * vd[i]) - vs2[i]
#
# Test 1: vnmacc.vv — vd=0x20, vs1=0x02, vs2=0x03 → -(2*3)-0x20 = -6-32 = -38 = 0xDA
# Test 2: vnmacc.vx — vd=0x20, xs1=0x02, vs2=0x03 → -(2*3)-0x20 = 0xDA
# Test 3: vnmadd.vv — vd=0x10, vs1=0x03, vs2=0x05 → -(3*0x10)-0x05 = -48-5 = -53 = 0xCB
# Test 4: vnmadd.vx — vd=0x10, xs1=0x03, vs2=0x05 → -(3*0x10)-0x05 = 0xCB
# Test 5: vnmacc.vv with negative operands — vd=0x00, vs1=0xFF(-1), vs2=0x02
#   -((-1)*2)-0x00 = 2 = 0x02
# Test 6: vnmadd.vv with negative operands — vd=0xFF(-1), vs1=0x02, vs2=0x03
#   -(2*(-1))-0x03 = 2-3 = -1 = 0xFF

#include "riscv_test.h"
#include "test_macros.h"

RVTEST_RV64UV
RVTEST_CODE_BEGIN

  # vnmacc.vv: vd[i] = -(vs1[i]*vs2[i]) - vd[i]
  TEST_CASE(1, x2, 0xDA, \
    li x6,2; vsetvli x7,x6,e8,m1; la x5,vd_20; vle8.v v4,(x5); \
    la x5,vs1_02; vle8.v v3,(x5); la x5,vs2_03; vle8.v v2,(x5); \
    vnmacc.vv v4,v3,v2; la x5,result; vse8.v v4,(x5); lbu x2,(x5); )

  # vnmacc.vx: vd[i] = -(xs1*vs2[i]) - vd[i]
  TEST_CASE(2, x2, 0xDA, \
    li x6,2; vsetvli x7,x6,e8,m1; la x5,vd_20; vle8.v v4,(x5); \
    la x5,vs2_03; vle8.v v2,(x5); \
    li x5,2; vnmacc.vx v4,x5,v2; la x5,result; vse8.v v4,(x5); lbu x2,(x5); )

  # vnmadd.vv: vd[i] = -(vs1[i]*vd[i]) - vs2[i]
  TEST_CASE(3, x2, 0xCB, \
    li x6,2; vsetvli x7,x6,e8,m1; la x5,vd_10; vle8.v v4,(x5); \
    la x5,vs1_03; vle8.v v3,(x5); la x5,vs2_05; vle8.v v2,(x5); \
    vnmadd.vv v4,v3,v2; la x5,result; vse8.v v4,(x5); lbu x2,(x5); )

  # vnmadd.vx: vd[i] = -(xs1*vd[i]) - vs2[i]
  TEST_CASE(4, x2, 0xCB, \
    li x6,2; vsetvli x7,x6,e8,m1; la x5,vd_10; vle8.v v4,(x5); \
    la x5,vs2_05; vle8.v v2,(x5); \
    li x5,3; vnmadd.vx v4,x5,v2; la x5,result; vse8.v v4,(x5); lbu x2,(x5); )

  # vnmacc.vv with negative vs1: -((-1)*2)-0 = 2
  TEST_CASE(5, x2, 0x02, \
    li x6,2; vsetvli x7,x6,e8,m1; la x5,vd_00; vle8.v v4,(x5); \
    la x5,vs1_ff; vle8.v v3,(x5); la x5,vs2_02; vle8.v v2,(x5); \
    vnmacc.vv v4,v3,v2; la x5,result; vse8.v v4,(x5); lbu x2,(x5); )

  # vnmadd.vv with negative vd: -(2*(-1))-3 = 2-3 = -1 = 0xFF
  TEST_CASE(6, x2, 0xFF, \
    li x6,2; vsetvli x7,x6,e8,m1; la x5,vd_ff; vle8.v v4,(x5); \
    la x5,vs1_02; vle8.v v3,(x5); la x5,vs2_03; vle8.v v2,(x5); \
    vnmadd.vv v4,v3,v2; la x5,result; vse8.v v4,(x5); lbu x2,(x5); )

  TEST_PASSFAIL

RVTEST_CODE_END

.data
  .balign 4
vd_20:  .byte 0x20, 0x20
vd_10:  .byte 0x10, 0x10
vd_00:  .byte 0x00, 0x00
vd_ff:  .byte 0xFF, 0xFF
vs1_02: .byte 0x02, 0x02
vs1_03: .byte 0x03, 0x03
vs1_ff: .byte 0xFF, 0xFF
vs2_02: .byte 0x02, 0x02
vs2_03: .byte 0x03, 0x03
vs2_05: .byte 0x05, 0x05

RVTEST_DATA_BEGIN
  .balign 8
result: .fill 8, 1, 0xff
RVTEST_DATA_END
