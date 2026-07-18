# Copyright (c) Qualcomm Technologies, Inc. and/or its subsidiaries.
# SPDX-License-Identifier: BSD-3-Clause-Clear

# Test vdiv.vx with e32,mf2 tail-undisturbed:
# v1 is preloaded with known values for all 4 e32 elements.
# vdiv.vx with vl=2 should only write elements [0] and [1].
# Elements [2] and [3] should remain undisturbed.
# Expected: v1[0]=0xffffffff, v1[1]=0xffffffff (div by 0), v1[2]=0x12345678, v1[3]=0xdeadbeef

#include "riscv_test.h"
#include "test_macros.h"

RVTEST_RV64UV
RVTEST_CODE_BEGIN

  # zero all vector regs, load operands, run vdiv.vx, store the result --
  # shared setup executed once before the four per-element TEST_CASEs below.
  vsetvli t0, zero, e8, m8, tu, mu
  vmv.v.i v0, 0
  vmv.v.i v8, 0

  la a0, testdata
  vsetvli t1, zero, e8, m1, tu, mu
  vle8.v v1, (a0)

  addi a0, a0, 16
  vsetvli t1, zero, e32, m1, tu, mu
  vle32.v v2, (a0)

  li s0, 0

  li t0, 2
  vsetvli t1, t0, e32, mf2, tu, mu
  vdiv.vx v1, v2, s0

  vsetvli t1, zero, e32, m1, tu, mu
  la a0, result_data
  vse32.v v1, (a0)

  # element 0 = 0xffffffff (div by zero)
  TEST_CASE(1, x2, 0xffffffff, lwu x2, 0(a0); )

  # element 1 = 0xffffffff (div by zero)
  TEST_CASE(2, x2, 0xffffffff, lwu x2, 4(a0); )

  # element 2 = 0x12345678 (UNDISTURBED)
  TEST_CASE(3, x2, 0x12345678, lwu x2, 8(a0); )

  # element 3 = 0xdeadbeef (UNDISTURBED)
  TEST_CASE(4, x2, 0xdeadbeef, lwu x2, 12(a0); )

  TEST_PASSFAIL

RVTEST_CODE_END

    .data
    .align 4
testdata:
    # 16 bytes loaded as e8: v1[0..3] in e32 representation
    # v1[0] = 0xAABBCCDD (little-endian bytes: DD CC BB AA)
    .byte 0xDD, 0xCC, 0xBB, 0xAA   # v1[0] = 0xAABBCCDD
    .byte 0x44, 0x33, 0x22, 0x11   # v1[1] = 0x11223344
    .byte 0x78, 0x56, 0x34, 0x12   # v1[2] = 0x12345678
    .byte 0xEF, 0xBE, 0xAD, 0xDE   # v1[3] = 0xDEADBEEF
    # v2 dividends (4x e32)
    .word 10, 20, 30, 40

result_data:
    .word 0, 0, 0, 0

RVTEST_DATA_BEGIN
    .balign 8
RVTEST_DATA_END
