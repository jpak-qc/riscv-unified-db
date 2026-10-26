# Copyright (c) Qualcomm Technologies, Inc. and/or its subsidiaries.
# SPDX-License-Identifier: BSD-3-Clause-Clear

# Verify signed vector averaging and vxrm rounding.

#include "riscv_test.h"
#include "test_macros.h"

RVTEST_RV64UV
RVTEST_CODE_BEGIN

  # 3 / 2 rounds to 2 with RNU and RNE, and to 1 with RDN and ROD.
  TEST_CASE(1, x2, 2, \
    vsetivli x0, 1, e32, m1; \
    la x5, three; \
    vle32.v v2, (x5); \
    vmv.v.i v3, 0; \
    csrwi vxrm, 0; \
    vaadd.vv v4, v2, v3; \
    la x5, result; \
    vse32.v v4, (x5); \
    lw x2, 0(x5); \
  )

  TEST_CASE(2, x2, 2, \
    vsetivli x0, 1, e32, m1; \
    la x5, three; \
    vle32.v v2, (x5); \
    vmv.v.i v3, 0; \
    csrwi vxrm, 1; \
    vaadd.vv v4, v2, v3; \
    la x5, result; \
    vse32.v v4, (x5); \
    lw x2, 0(x5); \
  )

  TEST_CASE(3, x2, 1, \
    vsetivli x0, 1, e32, m1; \
    la x5, three; \
    vle32.v v2, (x5); \
    vmv.v.i v3, 0; \
    csrwi vxrm, 2; \
    vaadd.vv v4, v2, v3; \
    la x5, result; \
    vse32.v v4, (x5); \
    lw x2, 0(x5); \
  )

  TEST_CASE(4, x2, 1, \
    vsetivli x0, 1, e32, m1; \
    la x5, three; \
    vle32.v v2, (x5); \
    vmv.v.i v3, 0; \
    csrwi vxrm, 3; \
    vaadd.vv v4, v2, v3; \
    la x5, result; \
    vse32.v v4, (x5); \
    lw x2, 0(x5); \
  )

  # This requires a SEW+1 signed sum: INT32_MIN averaged with itself is INT32_MIN.
  TEST_CASE(5, x2, -2147483648, \
    vsetivli x0, 1, e32, m1; \
    la x5, int32_min; \
    vle32.v v2, (x5); \
    vle32.v v3, (x5); \
    csrwi vxrm, 0; \
    vaadd.vv v4, v2, v3; \
    la x5, result; \
    vse32.v v4, (x5); \
    lw x2, 0(x5); \
  )

  TEST_PASSFAIL

RVTEST_CODE_END

RVTEST_DATA_BEGIN

  .balign 4
three:
  .word 3
int32_min:
  .word 0x80000000
result:
  .word 0

RVTEST_DATA_END
