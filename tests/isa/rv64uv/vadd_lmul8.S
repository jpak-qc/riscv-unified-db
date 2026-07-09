# Copyright (c) Qualcomm Technologies, Inc. and/or its subsidiaries.
# SPDX-License-Identifier: BSD-3-Clause-Clear
# See LICENSE for license details

#*****************************************************************************
# vadd_lmul8.S
#-----------------------------------------------------------------------------
#
# Phase 0 showstopper proof: vadd.vv at LMUL=8 exercises register-group
# addressing. With SEW=8 and VLEN=128, each register holds 16 elements, so a
# vl>16 forces element access to cross into the second register of the group
# (v_base+1). Flat bit-indexing V[vd][i*SEW...] would runtime-assert here
# because the bit position spills past VLEN; correct group addressing does not.
#
# Also verifies per-element masking (V[0][i]) leaves inactive elements
# undisturbed.

#include "riscv_test.h"
#include "test_macros.h"

RVTEST_RV64UV
RVTEST_CODE_BEGIN

# ---------------------------------------------------------------------------
# Test 1: LMUL=8, vl=20, unmasked. Element 17 lives in the second register of
# the group (index 17 >= 16 elems/reg). Read result element 17 and check it
# equals input1[17] + input2[17] = 0x11 + 0x22 = 0x33.
#
# We store the full 20-byte result and load the word containing element 17
# (bytes 16..19) => result+16. Element 17 is byte 1 of that word.
# input1[16..19] = 0x10,0x11,0x12,0x13 ; input2[16..19] = 0x20,0x22,0x24,0x26
# sums          = 0x30,0x33,0x36,0x39  => little-endian word = 0x39363330
# ---------------------------------------------------------------------------
  TEST_CASE(1, x2, 0x0000000039363330, \
    li      x6, 20; \
    vsetvli x7, x6, e8, m8; \
    la      x5, input1; \
    vle8.v  v8, (x5); \
    la      x5, input2; \
    vle8.v  v16, (x5); \
    vadd.vv v24, v8, v16; \
    la      x5, result; \
    vse8.v  v24, (x5); \
    lw      x2, 16(x5); \
    )

# ---------------------------------------------------------------------------
# Test 2: masking with v0 = 0x55 (even lanes active, odd lanes inactive).
# Pre-fill dest group v24 with 0xFF via a first unmasked store target, then
# do a masked vadd. Inactive (odd) lanes must remain 0xFF (undisturbed);
# active (even) lanes get input1+input2.
# Check bytes 0..3 of result:
#   lane0 active  = 0x01+0x02 = 0x03
#   lane1 inactive= 0xFF
#   lane2 active  = 0x03+0x06 = 0x09
#   lane3 inactive= 0xFF
# little-endian word = 0xFF09FF03  -> sign-extended lw = 0xFFFFFFFFFF09FF03
# ---------------------------------------------------------------------------
  TEST_CASE(2, x2, 0xFFFFFFFFFF09FF03, \
    li      x6, 4; \
    vsetvli x7, x6, e8, m8; \
    la      x5, allff; \
    vle8.v  v24, (x5); \
    la      x5, maskbits; \
    vle8.v  v0, (x5); \
    la      x5, input1; \
    vle8.v  v8, (x5); \
    la      x5, input2; \
    vle8.v  v16, (x5); \
    vadd.vv v24, v8, v16, v0.t; \
    la      x5, result; \
    vse8.v  v24, (x5); \
    lw      x2, (x5); \
    )

  TEST_PASSFAIL

RVTEST_CODE_END

# Input data section.
.data
  .balign 8
input1:
  .byte 0x01,0x02,0x03,0x04,0x05,0x06,0x07,0x08
  .byte 0x09,0x0a,0x0b,0x0c,0x0d,0x0e,0x0f,0x10
  .byte 0x10,0x11,0x12,0x13,0x14,0x15,0x16,0x17
input2:
  .byte 0x02,0x04,0x06,0x08,0x0a,0x0c,0x0e,0x10
  .byte 0x12,0x14,0x16,0x18,0x1a,0x1c,0x1e,0x20
  .byte 0x20,0x22,0x24,0x26,0x28,0x2a,0x2c,0x2e
maskbits:
  # v0 mask bits: 0x55 => lanes 0,2,4,6 active; lanes 1,3,5,7 inactive
  .byte 0x55,0x00,0x00,0x00,0x00,0x00,0x00,0x00
allff:
  .byte 0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff
  .byte 0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff
  .byte 0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff

# Output data section.
RVTEST_DATA_BEGIN

  .balign 8
result:
  .word -1
  .word -1
  .word -1
  .word -1
  .word -1
  .word -1

RVTEST_DATA_END
