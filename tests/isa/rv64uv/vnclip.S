# Copyright (c) Qualcomm Technologies, Inc. and/or its subsidiaries.
# SPDX-License-Identifier: BSD-3-Clause-Clear

#*****************************************************************************
# vnclip.S — Phase 13 Group D: narrowing clip (vnclip, vnclipu)
# SEW=8 dest, 2*SEW=16 source. vl=2. Default vxrm=0 (rnu).
#
# T1: vnclip.wv  0x0180(384)>>2 rnu = 96 = 0x60  (no clamp, no vxsat)
# T2: vnclip.wv  0x0200(512)>>2 rnu = 128 > INT8_MAX -> 0x7F, vxsat=1
# T3: vnclip.wv  0xFF00(-256)>>2 rnu = -64 = 0xC0  (no clamp, sign-extended)
# T4: vnclipu.wv 0x0050>>1 rnu = 0x28  (no clamp)
# T5: vnclipu.wv 0x0200>>1 rnu = 256 > 255 -> 0xFF, vxsat=1
# T6: vnclip.wx  scalar shift: 0x0200>>2 -> 0x7F, vxsat=1
# T7: vnclip.wi  immediate shift: 0x0180>>2 -> 0x60
# T8: shift mask: shamt=17 on SEW=8 (2*SEW-1=15), 17&15=1 -> 0x0200>>1 = 256 -> 0x7F
# T9: vxsat readback — clear, clip saturates, vxsat=1
# T10: vxsat stays clear when no saturation

#include "riscv_test.h"
#include "test_macros.h"

RVTEST_RV64UV
RVTEST_CODE_BEGIN

  # T1: vnclip.wv 0x0180>>2 -> 96 = 0x60 (no clamp)
  TEST_CASE(1, x2, 0x60, \
    csrw vxsat,x0; csrw vxrm,x0; \
    li x6,2; vsetvli x7,x6,e16,m1; la x5,w_0180; vle16.v v2,(x5); \
    li x6,2; vsetvli x7,x6,e8,m1;  la x5,sh_02;  vle8.v  v3,(x5); \
    vnclip.wv v4,v2,v3; la x5,result; vse8.v v4,(x5); lbu x2,(x5); )

  # T2: vnclip.wv 0x0200>>2 -> clamps to 0x7F, vxsat set
  TEST_CASE(2, x2, 0x7F, \
    csrw vxsat,x0; csrw vxrm,x0; \
    li x6,2; vsetvli x7,x6,e16,m1; la x5,w_0200; vle16.v v2,(x5); \
    li x6,2; vsetvli x7,x6,e8,m1;  la x5,sh_02;  vle8.v  v3,(x5); \
    vnclip.wv v4,v2,v3; la x5,result; vse8.v v4,(x5); lbu x2,(x5); )

  # T3: vnclip.wv 0xFF00(-256)>>2 -> -64 = 0xC0 (sign-extended, no clamp)
  TEST_CASE(3, x2, 0xC0, \
    csrw vxrm,x0; \
    li x6,2; vsetvli x7,x6,e16,m1; la x5,w_ff00; vle16.v v2,(x5); \
    li x6,2; vsetvli x7,x6,e8,m1;  la x5,sh_02;  vle8.v  v3,(x5); \
    vnclip.wv v4,v2,v3; la x5,result; vse8.v v4,(x5); lbu x2,(x5); )

  # T4: vnclipu.wv 0x0050>>1 -> 0x28 (no clamp, unsigned)
  TEST_CASE(4, x2, 0x28, \
    csrw vxrm,x0; \
    li x6,2; vsetvli x7,x6,e16,m1; la x5,w_0050; vle16.v v2,(x5); \
    li x6,2; vsetvli x7,x6,e8,m1;  la x5,sh_01;  vle8.v  v3,(x5); \
    vnclipu.wv v4,v2,v3; la x5,result; vse8.v v4,(x5); lbu x2,(x5); )

  # T5: vnclipu.wv 0x0200>>1 -> 256 > 255 -> 0xFF, vxsat set
  TEST_CASE(5, x2, 0xFF, \
    csrw vxsat,x0; csrw vxrm,x0; \
    li x6,2; vsetvli x7,x6,e16,m1; la x5,w_0200; vle16.v v2,(x5); \
    li x6,2; vsetvli x7,x6,e8,m1;  la x5,sh_01;  vle8.v  v3,(x5); \
    vnclipu.wv v4,v2,v3; la x5,result; vse8.v v4,(x5); lbu x2,(x5); )

  # T6: vnclip.wx scalar shift 2: 0x0200>>2 -> 0x7F
  TEST_CASE(6, x2, 0x7F, \
    csrw vxrm,x0; \
    li x6,2; vsetvli x7,x6,e16,m1; la x5,w_0200; vle16.v v2,(x5); \
    li x6,2; vsetvli x7,x6,e8,m1;  li x5,2; vnclip.wx v4,v2,x5; \
    la x5,result; vse8.v v4,(x5); lbu x2,(x5); )

  # T7: vnclip.wi immediate shift 2: 0x0180>>2 -> 0x60
  TEST_CASE(7, x2, 0x60, \
    csrw vxrm,x0; \
    li x6,2; vsetvli x7,x6,e16,m1; la x5,w_0180; vle16.v v2,(x5); \
    li x6,2; vsetvli x7,x6,e8,m1;  vnclip.wi v4,v2,2; \
    la x5,result; vse8.v v4,(x5); lbu x2,(x5); )

  # T8: shift amount mask (2*SEW-1=15): shamt=17&15=1 -> 0x0200>>1=256 -> 0x7F
  TEST_CASE(8, x2, 0x7F, \
    csrw vxrm,x0; \
    li x6,2; vsetvli x7,x6,e16,m1; la x5,w_0200; vle16.v v2,(x5); \
    li x6,2; vsetvli x7,x6,e8,m1;  li x5,17; vnclip.wx v4,v2,x5; \
    la x5,result; vse8.v v4,(x5); lbu x2,(x5); )

  # T9: vxsat set after clip saturation
  TEST_CASE(9, x2, 0x01, \
    csrw vxsat,x0; csrw vxrm,x0; \
    li x6,2; vsetvli x7,x6,e16,m1; la x5,w_0200; vle16.v v2,(x5); \
    li x6,2; vsetvli x7,x6,e8,m1;  la x5,sh_02;  vle8.v  v3,(x5); \
    vnclip.wv v4,v2,v3; csrr x2,vxsat; )

  # T10: vxsat stays clear when no saturation
  TEST_CASE(10, x2, 0x00, \
    csrw vxsat,x0; csrw vxrm,x0; \
    li x6,2; vsetvli x7,x6,e16,m1; la x5,w_0180; vle16.v v2,(x5); \
    li x6,2; vsetvli x7,x6,e8,m1;  la x5,sh_02;  vle8.v  v3,(x5); \
    vnclip.wv v4,v2,v3; csrr x2,vxsat; )

  TEST_PASSFAIL

RVTEST_CODE_END

.data
  .balign 8
w_0180: .short 0x0180, 0x0180
w_0200: .short 0x0200, 0x0200
w_ff00: .short 0xFF00, 0xFF00
w_0050: .short 0x0050, 0x0050
sh_01:  .byte 0x01, 0x01
sh_02:  .byte 0x02, 0x02

RVTEST_DATA_BEGIN
  .balign 8
result: .fill 16, 1, 0x00
RVTEST_DATA_END
