# Copyright (c) Qualcomm Technologies, Inc. and/or its subsidiaries.
# SPDX-License-Identifier: BSD-3-Clause-Clear

#*****************************************************************************
# vavg.S — Phase 13 Group E: averaging add/sub (vaadd, vaaddu, vasub, vasubu)
# SEW=8, LMUL=1, vl=2. Default vxrm=0 (rnu). vxsat must NOT be set.
#
# T1: vaadd.vv   signed: (3+5)/2 rnu = 4 = 0x04
# T2: vaadd.vv   signed: (7+7)/2 rnu = 7 = 0x07 (even, no round)
# T3: vaadd.vv   rnu vs rdn: (3+4)/2 = 3.5 -> rnu=4, rdn=3
# T4: vaaddu.vv  unsigned: (200+100)/2 rnu = 150 = 0x96
# T5: vaaddu.vv  unsigned overflow handled: (255+3)/2 rnu = 129 = 0x81 (no sat)
# T6: vasub.vv   signed: (-3 - (-3))/2 = 0 -- use (5-3)/2=1
# T7: vasub.vx   scalar: (7 - 3)/2 rnu = 2
# T8: vaaddu.vx  unsigned scalar: (200 + scalar_100)/2 = 0x96
# T9: vasubu.vv  unsigned: (10-4)/2 rnu = 3
# T10: vxsat NOT set after averaging (averaging is NOT saturating)

#include "riscv_test.h"
#include "test_macros.h"

RVTEST_RV64UV
RVTEST_CODE_BEGIN

  # T1: vaadd.vv (3+5)/2 rnu = 4
  TEST_CASE(1, x2, 0x04, \
    csrw vxrm,x0; \
    li x6,2; vsetvli x7,x6,e8,m1; la x5,s_03; vle8.v v2,(x5); la x5,s_05; vle8.v v3,(x5); \
    vaadd.vv v4,v2,v3; la x5,result; vse8.v v4,(x5); lbu x2,(x5); )

  # T2: vaadd.vv (7+7)/2 rnu = 7
  TEST_CASE(2, x2, 0x07, \
    csrw vxrm,x0; \
    li x6,2; vsetvli x7,x6,e8,m1; la x5,s_07; vle8.v v2,(x5); la x5,s_07; vle8.v v3,(x5); \
    vaadd.vv v4,v2,v3; la x5,result; vse8.v v4,(x5); lbu x2,(x5); )

  # T3: vaadd.vv rdn: (3+4)/2 rdn = 3 (truncates; rnu gives 4)
  TEST_CASE(3, x2, 0x03, \
    li x4,2; csrw vxrm,x4; \
    li x6,2; vsetvli x7,x6,e8,m1; la x5,s_03; vle8.v v2,(x5); la x5,s_04; vle8.v v3,(x5); \
    vaadd.vv v4,v2,v3; la x5,result; vse8.v v4,(x5); lbu x2,(x5); csrw vxrm,x0; )

  # T4: vaaddu.vv unsigned (200+100)/2 = 150 = 0x96
  TEST_CASE(4, x2, 0x96, \
    csrw vxrm,x0; \
    li x6,2; vsetvli x7,x6,e8,m1; la x5,u_c8; vle8.v v2,(x5); la x5,u_64; vle8.v v3,(x5); \
    vaaddu.vv v4,v2,v3; la x5,result; vse8.v v4,(x5); lbu x2,(x5); )

  # T5: vaaddu.vv (255+3)/2 rnu = 129 = 0x81 (overflow handled, no saturation)
  TEST_CASE(5, x2, 0x81, \
    csrw vxrm,x0; \
    li x6,2; vsetvli x7,x6,e8,m1; la x5,u_ff; vle8.v v2,(x5); la x5,s_03; vle8.v v3,(x5); \
    vaaddu.vv v4,v2,v3; la x5,result; vse8.v v4,(x5); lbu x2,(x5); )

  # T6: vasub.vv signed (5-3)/2 rnu = 1
  TEST_CASE(6, x2, 0x01, \
    csrw vxrm,x0; \
    li x6,2; vsetvli x7,x6,e8,m1; la x5,s_05; vle8.v v2,(x5); la x5,s_03; vle8.v v3,(x5); \
    vasub.vv v4,v2,v3; la x5,result; vse8.v v4,(x5); lbu x2,(x5); )

  # T7: vasub.vx scalar (7-3)/2 rnu = 2
  TEST_CASE(7, x2, 0x02, \
    csrw vxrm,x0; \
    li x6,2; vsetvli x7,x6,e8,m1; la x5,s_07; vle8.v v2,(x5); \
    li x5,3; vasub.vx v4,v2,x5; la x5,result; vse8.v v4,(x5); lbu x2,(x5); )

  # T8: vaaddu.vx unsigned scalar (200 + 100)/2 = 0x96
  TEST_CASE(8, x2, 0x96, \
    csrw vxrm,x0; \
    li x6,2; vsetvli x7,x6,e8,m1; la x5,u_c8; vle8.v v2,(x5); \
    li x5,100; vaaddu.vx v4,v2,x5; la x5,result; vse8.v v4,(x5); lbu x2,(x5); )

  # T9: vasubu.vv unsigned (10-4)/2 rnu = 3
  TEST_CASE(9, x2, 0x03, \
    csrw vxrm,x0; \
    li x6,2; vsetvli x7,x6,e8,m1; la x5,u_0a; vle8.v v2,(x5); la x5,s_04; vle8.v v3,(x5); \
    vasubu.vv v4,v2,v3; la x5,result; vse8.v v4,(x5); lbu x2,(x5); )

  # T10: vxsat NOT set after averaging
  TEST_CASE(10, x2, 0x00, \
    csrw vxsat,x0; csrw vxrm,x0; \
    li x6,2; vsetvli x7,x6,e8,m1; la x5,s_07; vle8.v v2,(x5); la x5,s_07; vle8.v v3,(x5); \
    vaadd.vv v4,v2,v3; csrr x2,vxsat; )

  TEST_PASSFAIL

RVTEST_CODE_END

.data
  .balign 8
s_03: .byte 0x03, 0x03
s_04: .byte 0x04, 0x04
s_05: .byte 0x05, 0x05
s_07: .byte 0x07, 0x07
u_ff: .byte 0xFF, 0xFF
u_c8: .byte 0xC8, 0xC8
u_64: .byte 0x64, 0x64
u_0a: .byte 0x0A, 0x0A

RVTEST_DATA_BEGIN
  .balign 8
result: .fill 16, 1, 0x00
RVTEST_DATA_END
