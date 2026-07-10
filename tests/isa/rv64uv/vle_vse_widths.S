# Copyright (c) Qualcomm Technologies, Inc. and/or its subsidiaries.
# SPDX-License-Identifier: BSD-3-Clause-Clear
# See LICENSE for license details

#*****************************************************************************
# vle_vse_widths.S
#-----------------------------------------------------------------------------
#
# Phase 2 proof: unit-stride loads and stores at EEW=16, 32, 64.
# Each test: load two vectors, vadd, store, read back and compare.
# Uses LMUL=1 and vl=2 to keep expected values simple.
#
# EEW=16: input1=[0x0001,0x0002], input2=[0x0010,0x0020] -> sum=[0x0011,0x0022]
#   lw at result gives little-endian [0x0022_0011] = 0x00220011 (msbit clear -> 0 sign-ext)
#
# EEW=32: input1=[0x00000001,0x00000002], input2=[0x00000010,0x00000020]
#   -> sum=[0x00000011,0x00000022]
#   lw first word: 0x00000011
#
# EEW=64: input1=[0x0000000000000001, 0x0000000000000002]
#         input2=[0x0000000000000010, 0x0000000000000020]
#   -> sum=[0x0000000000000011, 0x0000000000000022]
#   lw first word (little-endian): 0x00000011 (low 32 bits of element 0)

#include "riscv_test.h"
#include "test_macros.h"

RVTEST_RV64UV
RVTEST_CODE_BEGIN

  # EEW=16: SEW=16, LMUL=1, vl=2
  TEST_CASE(1, x2, 0x0000000000220011, \
    li      x6, 2; \
    vsetvli x7, x6, e16, m1; \
    la      x5, input16a; \
    vle16.v v2, (x5); \
    la      x5, input16b; \
    vle16.v v3, (x5); \
    vadd.vv v4, v2, v3; \
    la      x5, result; \
    vse16.v v4, (x5); \
    lw      x2, (x5); \
    )

  # EEW=32: SEW=32, LMUL=1, vl=2
  TEST_CASE(2, x2, 0x0000000000000011, \
    li      x6, 2; \
    vsetvli x7, x6, e32, m1; \
    la      x5, input32a; \
    vle32.v v2, (x5); \
    la      x5, input32b; \
    vle32.v v3, (x5); \
    vadd.vv v4, v2, v3; \
    la      x5, result; \
    vse32.v v4, (x5); \
    lw      x2, (x5); \
    )

  # EEW=64: SEW=64, LMUL=1, vl=2
  TEST_CASE(3, x2, 0x0000000000000011, \
    li      x6, 2; \
    vsetvli x7, x6, e64, m1; \
    la      x5, input64a; \
    vle64.v v2, (x5); \
    la      x5, input64b; \
    vle64.v v3, (x5); \
    vadd.vv v4, v2, v3; \
    la      x5, result; \
    vse64.v v4, (x5); \
    lw      x2, (x5); \
    )

  # EEW=8 LMUL=8 group-crossing: vl=20, element 16 is in second register of group.
  # input8a[16]=0x10, input8b[16]=0x20 → sum=0x30. lbu byte16=0x30
  TEST_CASE(4, x2, 0x30, \
    li      x6, 20; \
    vsetvli x7, x6, e8, m8; \
    la      x5, input8a; \
    vle8.v  v8, (x5); \
    la      x5, input8b; \
    vle8.v  v16, (x5); \
    vadd.vv v24, v8, v16; \
    la      x5, result; \
    vse8.v  v24, (x5); \
    lbu     x2, 16(x5); \
    )

  TEST_PASSFAIL

RVTEST_CODE_END

.data
  .balign 8
input16a:  .short 0x0001, 0x0002
input16b:  .short 0x0010, 0x0020
input32a:  .word  0x00000001, 0x00000002
input32b:  .word  0x00000010, 0x00000020
input64a:  .dword 0x0000000000000001, 0x0000000000000002
input64b:  .dword 0x0000000000000010, 0x0000000000000020
input8a:   .byte 0x01,0x02,0x03,0x04,0x05,0x06,0x07,0x08,0x09,0x0a,0x0b,0x0c,0x0d,0x0e,0x0f,0x10,0x10,0x11,0x12,0x13
input8b:   .byte 0x01,0x02,0x03,0x04,0x05,0x06,0x07,0x08,0x09,0x0a,0x0b,0x0c,0x0d,0x0e,0x0f,0x10,0x20,0x21,0x22,0x23

RVTEST_DATA_BEGIN
  .balign 8
result: .fill 24, 1, 0xff
RVTEST_DATA_END
