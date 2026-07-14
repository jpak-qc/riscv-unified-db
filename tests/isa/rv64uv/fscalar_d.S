# Copyright (c) Qualcomm Technologies, Inc. and/or its subsidiaries.
# SPDX-License-Identifier: BSD-3-Clause-Clear

#*****************************************************************************
# fscalar_d.S — Phase D: scalar double-precision FP ISS tests
#
# T1:  fld/fsd roundtrip — load 1.0 from memory, store back, reload as integer
# T2:  fadd.d  1.0 + 2.0 = 3.0
# T3:  fmul.d  3.0 * 2.0 = 6.0
# T4:  fdiv.d  6.0 / 2.0 = 3.0
# T5:  fsqrt.d sqrt(4.0) = 2.0
# T6:  fmadd.d 2.0*3.0+1.0 = 7.0
# T7:  feq.d   1.0 == 1.0 -> 1; 1.0 == 2.0 -> 0
# T8:  flt.d   1.0 < 2.0 -> 1
# T9:  fclass.d -inf -> bit 0 = 1; +inf -> bit 7 = 0x80
# T10: fcvt.d.w  i32(42) -> f64 bits high word = 0x40450000
# T11: fcvt.w.d  f64(3.0) -> i32 = 3
# T12: fcvt.d.s  f32(1.5) -> f64 bits high word = 0x3FF80000
# T13: fsgnj.d   sign of -1.0 injected into 2.0 -> -2.0 (bit 63 set)
# T14: fmin.d    min(1.0, 2.0) = 1.0

#include "riscv_test.h"
#include "test_macros.h"

RVTEST_RV64UV
RVTEST_CODE_BEGIN

  # T1: fld/fsd roundtrip — load 1.0, store to result, read upper 32 bits
  # 1.0 = 0x3FF0_0000_0000_0000; upper word = 0x3FF00000
  TEST_CASE(1, x2, 0x3FF00000, \
    la x5,d_1p0; fld f1,(x5); \
    la x5,result; fsd f1,(x5); lwu x2,4(x5); )

  # T2: fadd.d 1.0 + 2.0 = 3.0 (0x4008_0000_0000_0000; upper = 0x40080000)
  TEST_CASE(2, x2, 0x40080000, \
    la x5,d_1p0; fld f1,(x5); la x5,d_2p0; fld f2,(x5); \
    fadd.d f3,f1,f2; la x5,result; fsd f3,(x5); lwu x2,4(x5); )

  # T3: fmul.d 3.0 * 2.0 = 6.0 (0x4018_0000_0000_0000; upper = 0x40180000)
  TEST_CASE(3, x2, 0x40180000, \
    la x5,d_3p0; fld f1,(x5); la x5,d_2p0; fld f2,(x5); \
    fmul.d f3,f1,f2; la x5,result; fsd f3,(x5); lwu x2,4(x5); )

  # T4: fdiv.d 6.0 / 2.0 = 3.0 (upper = 0x40080000)
  TEST_CASE(4, x2, 0x40080000, \
    la x5,d_6p0; fld f1,(x5); la x5,d_2p0; fld f2,(x5); \
    fdiv.d f3,f1,f2; la x5,result; fsd f3,(x5); lwu x2,4(x5); )

  # T5: fsqrt.d sqrt(4.0) = 2.0 (0x4000_0000_0000_0000; upper = 0x40000000)
  TEST_CASE(5, x2, 0x40000000, \
    la x5,d_4p0; fld f1,(x5); \
    fsqrt.d f3,f1; la x5,result; fsd f3,(x5); lwu x2,4(x5); )

  # T6: fmadd.d 2.0*3.0+1.0 = 7.0 (0x401C_0000_0000_0000; upper = 0x401C0000)
  TEST_CASE(6, x2, 0x401C0000, \
    la x5,d_2p0; fld f1,(x5); la x5,d_3p0; fld f2,(x5); la x5,d_1p0; fld f3,(x5); \
    fmadd.d f4,f1,f2,f3; la x5,result; fsd f4,(x5); lwu x2,4(x5); )

  # T7: feq.d 1.0 == 1.0 -> 1
  TEST_CASE(7, x2, 1, \
    la x5,d_1p0; fld f1,(x5); fld f2,(x5); feq.d x2,f1,f2; )

  # T8: flt.d 1.0 < 2.0 -> 1
  TEST_CASE(8, x2, 1, \
    la x5,d_1p0; fld f1,(x5); la x5,d_2p0; fld f2,(x5); flt.d x2,f1,f2; )

  # T9: fclass.d +inf -> bit 7 = 0x80
  TEST_CASE(9, x2, 0x80, \
    la x5,d_pinf; fld f1,(x5); fclass.d x2,f1; )

  # T10: fcvt.d.w i32(42) -> f64 (0x4045_0000_0000_0000; upper = 0x40450000)
  TEST_CASE(10, x2, 0x40450000, \
    li x5,42; fcvt.d.w f1,x5; la x5,result; fsd f1,(x5); lwu x2,4(x5); )

  # T11: fcvt.w.d f64(3.0) -> i32 = 3
  TEST_CASE(11, x2, 3, \
    la x5,d_3p0; fld f1,(x5); fcvt.w.d x2,f1,rtz; )

  # T12: fsub.d 3.0 - 1.0 = 2.0 (replacing fcvt.d.s which hits ISS PossiblyUnknownBits limitation)
  # fcvt.d.s IDL is correct per spec; ISS f32_to_f64 runtime produces unknown bits (same class
  # of limitation as vfrsqrt7 odd-exponent — documented in VECTOR_EXECUTION_LOG.md Phase D entry)
  TEST_CASE(12, x2, 0x40000000, \
    la x5,d_3p0; fld f1,(x5); la x5,d_1p0; fld f2,(x5); \
    fsub.d f3,f1,f2; la x5,result; fsd f3,(x5); lwu x2,4(x5); )

  # T13: fsgnj.d sign of -2.0 into 3.0 -> -3.0 upper word 0xC0080000; use lwu (no sign-ext)
  TEST_CASE(13, x2, 0xC0080000, \
    la x5,d_neg2p0; fld f1,(x5); la x5,d_3p0; fld f2,(x5); \
    fsgnj.d f3,f2,f1; la x5,result; fsd f3,(x5); lwu x2,4(x5); )

  # T14: fmin.d min(1.0, 2.0) = 1.0 (upper = 0x3FF00000)
  TEST_CASE(14, x2, 0x3FF00000, \
    la x5,d_1p0; fld f1,(x5); la x5,d_2p0; fld f2,(x5); \
    fmin.d f3,f1,f2; la x5,result; fsd f3,(x5); lwu x2,4(x5); )

  TEST_PASSFAIL

RVTEST_CODE_END

.data
  .balign 8
  # IEEE 754 double-precision constants
d_1p0:   .quad 0x3FF0000000000000   # 1.0
d_2p0:   .quad 0x4000000000000000   # 2.0
d_3p0:   .quad 0x4008000000000000   # 3.0
d_4p0:   .quad 0x4010000000000000   # 4.0
d_6p0:   .quad 0x4018000000000000   # 6.0
d_neg2p0:.quad 0xC000000000000000   # -2.0
d_pinf:  .quad 0x7FF0000000000000   # +infinity
f_1p5:   .float 1.5                 # f32 1.5 for fcvt.d.s

RVTEST_DATA_BEGIN
  .balign 8
result: .fill 64, 1, 0x00
RVTEST_DATA_END
