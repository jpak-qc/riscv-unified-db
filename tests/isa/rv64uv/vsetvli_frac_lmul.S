# Copyright (c) Qualcomm Technologies, Inc. and/or its subsidiaries.
# SPDX-License-Identifier: BSD-3-Clause-Clear
# See LICENSE for license details

#*****************************************************************************
# vsetvli_frac_lmul.S
#-----------------------------------------------------------------------------
#
# Bug-fix proof: fractional-LMUL VLMAX must DIVIDE, not multiply.
#
# vtype fields: vtypei[2:0]=VLMUL, [5:3]=VSEW, [6]=VTA, [7]=VMA.
# VLMUL=0b111 => LMUL=mf2 (fractional, "Divide" type, log2_lmul=1).
#
# With SEW=8, LMUL=mf2, VLEN=128:
#   correct VLMAX = VLEN * LMUL / SEW = 128 * (1/2) / 8 = 8
#   buggy   VLMAX = (VLEN << log2_lmul) >> log2_sew = (128<<1)>>3 = 32  (4x too big)
#
# Requesting AVL=20:
#   correct: 20 > 2*VLMAX(=16) => vl clamps to VLMAX = 8
#   buggy:   20 <= VLMAX(=32)  => vl = 20
# So vl==8 proves the fractional-LMUL divide path; vl==20 would be the old bug.

#include "riscv_test.h"
#include "test_macros.h"

RVTEST_RV64UV
RVTEST_CODE_BEGIN

  # vtypei = 0x07 -> VMA_VTA_VSEW_VLMUL = 0_0_000_111 -> SEW=8, LMUL=mf2
  TEST_CASE(1, x5, 0x8, \
    li x4, 20; \
    vsetvli x5, x4, 0x07; \
  )

  # Same via vsetvl (vtype from a register) to exercise that path too.
  TEST_CASE(2, x5, 0x8, \
    li x4, 20; \
    li x6, 0x07; \
    vsetvl x5, x4, x6; \
  )

  TEST_PASSFAIL

RVTEST_CODE_END

  .data
RVTEST_DATA_BEGIN

RVTEST_DATA_END
