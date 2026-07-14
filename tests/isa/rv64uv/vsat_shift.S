# Copyright (c) Qualcomm Technologies, Inc. and/or its subsidiaries.
# SPDX-License-Identifier: BSD-3-Clause-Clear

#*****************************************************************************
# vsat_shift.S — Phase 13 Group C: rounding shift right (vssrl, vssra)
# SEW=8, LMUL=1, vl=2. Shift amount masked to SEW-1 = 7 bits.
# Default vxrm=0 (rnu) unless overridden. vxsat must NOT be set.
#
# Test 1: vssrl.vv  0xF0>>3 rnu: 240>>3=30, bit2=0 -> no round -> 0x1E
# Test 2: vssra.vv  0x80>>1 rnu: -128>>1=-64+0=0xC0 (sign-extending)
# Test 3: vssrl.vv  0x80>>1 rnu: 128>>1=64+0=0x40 (unsigned — key difference from vssra)
# Test 4: vssrl.vv  rdn vs rnu: 0xA4>>3 rdu=0x14, rnu=0x15 (bit2=1 rounds up)
# Test 5: vssrl.vx  scalar shift 3: 0xF0>>3 -> 0x1E
# Test 6: vssrl.vi  immediate shift 3: 0xF0>>3 -> 0x1E
# Test 7: vssra.vx  scalar shift 1: 0x80>>1 -> 0xC0
# Test 8: vssra.vi  immediate shift 1: 0x80>>1 -> 0xC0
# Test 9: shift mask — vssrl with shift=9 on SEW=8: 9&7=1 → 0x80>>1 = 0x40
# Test 10: vxsat NOT set after rounding shift (shifts are NOT saturating)

#include "riscv_test.h"
#include "test_macros.h"

RVTEST_RV64UV
RVTEST_CODE_BEGIN

  # Test 1: vssrl.vv unsigned rounding shift 0xF0>>3
  TEST_CASE(1, x2, 0x1E, \
    csrw vxrm,x0; \
    li x6,2; vsetvli x7,x6,e8,m1; la x5,s_f0; vle8.v v2,(x5); la x5,s_03; vle8.v v3,(x5); \
    vssrl.vv v4,v2,v3; la x5,result; vse8.v v4,(x5); lbu x2,(x5); )

  # Test 2: vssra.vv arithmetic: 0x80(-128)>>1 = -64 = 0xC0
  TEST_CASE(2, x2, 0xC0, \
    csrw vxrm,x0; \
    li x6,2; vsetvli x7,x6,e8,m1; la x5,s_80; vle8.v v2,(x5); la x5,s_01; vle8.v v3,(x5); \
    vssra.vv v4,v2,v3; la x5,result; vse8.v v4,(x5); lbu x2,(x5); )

  # Test 3: vssrl.vv unsigned: 0x80>>1 = 64 = 0x40 (sign NOT extended — differs from test 2)
  TEST_CASE(3, x2, 0x40, \
    csrw vxrm,x0; \
    li x6,2; vsetvli x7,x6,e8,m1; la x5,s_80; vle8.v v2,(x5); la x5,s_01; vle8.v v3,(x5); \
    vssrl.vv v4,v2,v3; la x5,result; vse8.v v4,(x5); lbu x2,(x5); )

  # Test 4: rdn truncates where rnu rounds up: 0xA4>>3
  # 0xA4=10100100, bit2=1 -> rnu rounds up to 0x15; rdn truncates to 0x14
  TEST_CASE(4, x2, 0x14, \
    li x4,2; csrw vxrm,x4; \
    li x6,2; vsetvli x7,x6,e8,m1; la x5,s_a4; vle8.v v2,(x5); la x5,s_03; vle8.v v3,(x5); \
    vssrl.vv v4,v2,v3; la x5,result; vse8.v v4,(x5); lbu x2,(x5); csrw vxrm,x0; )

  # Test 5: vssrl.vx scalar shift 3
  TEST_CASE(5, x2, 0x1E, \
    csrw vxrm,x0; \
    li x6,2; vsetvli x7,x6,e8,m1; la x5,s_f0; vle8.v v2,(x5); \
    li x5,3; vssrl.vx v4,v2,x5; la x5,result; vse8.v v4,(x5); lbu x2,(x5); )

  # Test 6: vssrl.vi immediate shift 3
  TEST_CASE(6, x2, 0x1E, \
    csrw vxrm,x0; \
    li x6,2; vsetvli x7,x6,e8,m1; la x5,s_f0; vle8.v v2,(x5); \
    vssrl.vi v4,v2,3; la x5,result; vse8.v v4,(x5); lbu x2,(x5); )

  # Test 7: vssra.vx arithmetic scalar shift 1
  TEST_CASE(7, x2, 0xC0, \
    csrw vxrm,x0; \
    li x6,2; vsetvli x7,x6,e8,m1; la x5,s_80; vle8.v v2,(x5); \
    li x5,1; vssra.vx v4,v2,x5; la x5,result; vse8.v v4,(x5); lbu x2,(x5); )

  # Test 8: vssra.vi immediate shift 1
  TEST_CASE(8, x2, 0xC0, \
    csrw vxrm,x0; \
    li x6,2; vsetvli x7,x6,e8,m1; la x5,s_80; vle8.v v2,(x5); \
    vssra.vi v4,v2,1; la x5,result; vse8.v v4,(x5); lbu x2,(x5); )

  # Test 9: shift amount mask: shift=9 on SEW=8 → 9&7=1 → same as shift 1 → 0x40
  TEST_CASE(9, x2, 0x40, \
    csrw vxrm,x0; \
    li x6,2; vsetvli x7,x6,e8,m1; la x5,s_80; vle8.v v2,(x5); \
    li x5,9; vssrl.vx v4,v2,x5; la x5,result; vse8.v v4,(x5); lbu x2,(x5); )

  # Test 10: vxsat NOT set after rounding shift (shifts are NOT saturating ops)
  TEST_CASE(10, x2, 0x00, \
    csrw vxsat,x0; csrw vxrm,x0; \
    li x6,2; vsetvli x7,x6,e8,m1; la x5,s_f0; vle8.v v2,(x5); la x5,s_03; vle8.v v3,(x5); \
    vssrl.vv v4,v2,v3; csrr x2,vxsat; )

  TEST_PASSFAIL

RVTEST_CODE_END

.data
  .balign 8
s_f0: .byte 0xF0, 0xF0
s_80: .byte 0x80, 0x80
s_a4: .byte 0xA4, 0xA4
s_03: .byte 0x03, 0x03
s_01: .byte 0x01, 0x01

RVTEST_DATA_BEGIN
  .balign 8
result: .fill 16, 1, 0x00
RVTEST_DATA_END
