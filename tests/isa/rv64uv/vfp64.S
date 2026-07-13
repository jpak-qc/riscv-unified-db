# Copyright (c) Qualcomm Technologies, Inc. and/or its subsidiaries.
# SPDX-License-Identifier: BSD-3-Clause-Clear

#*****************************************************************************
# vfp64.S
#-----------------------------------------------------------------------------
#
# Phase 12A/12B ISS validation: exercise f64_add, f64_mul, f64_muladd through
# vfadd.vv, vfmul.vv, vfmacc.vv at SEW=64.
#
# VLEN=128, SEW=64, LMUL=1: 2 f64 elements per register.
# VLEN=128, SEW=64, LMUL=8: 16 f64 elements across 8 registers.
#
# f64 bit patterns:
#   1.0 = 0x3FF0000000000000
#   2.0 = 0x4000000000000000
#   3.0 = 0x4008000000000000
#   5.0 = 0x4014000000000000
#   6.0 = 0x4018000000000000

#include "riscv_test.h"
#include "test_macros.h"

RVTEST_RV64UV
RVTEST_CODE_BEGIN

# ---------------------------------------------------------------------------
# Test 1: vfadd.vv SEW=64 LMUL=1, unmasked.
#   vl=2, vs2=[1.0, 2.0], vs1=[1.0, 3.0]
#   result=[2.0, 5.0] = [0x4000000000000000, 0x4014000000000000]
#   Load result[0] (low 8 bytes) into x2 and check.
# ---------------------------------------------------------------------------
  TEST_CASE(1, x2, 0x4000000000000000, \
    li      x6, 2; \
    vsetvli x7, x6, e64, m1; \
    la      x5, f64_a; \
    vle64.v v2, (x5); \
    la      x5, f64_b; \
    vle64.v v3, (x5); \
    vfadd.vv v4, v2, v3; \
    la      x5, result; \
    vse64.v v4, (x5); \
    ld      x2, 0(x5); \
    )

# ---------------------------------------------------------------------------
# Test 2: vfadd.vv SEW=64 LMUL=1, check second element.
#   Same setup as Test 1. Load result[1] (high 8 bytes).
# ---------------------------------------------------------------------------
  TEST_CASE(2, x2, 0x4014000000000000, \
    li      x6, 2; \
    vsetvli x7, x6, e64, m1; \
    la      x5, f64_a; \
    vle64.v v2, (x5); \
    la      x5, f64_b; \
    vle64.v v3, (x5); \
    vfadd.vv v4, v2, v3; \
    la      x5, result; \
    vse64.v v4, (x5); \
    ld      x2, 8(x5); \
    )

# ---------------------------------------------------------------------------
# Test 3: vfadd.vv SEW=64 LMUL=1, masked (mask=0b01, only element 0 active).
#   Pre-fill vd with 0xFFFF...FFFF (by loading dest_init).
#   After masked add: elem0 = 1.0+1.0 = 2.0 (active), elem1 = 0xFFFF... (undisturbed).
#   Load result[0]: expect 0x4000000000000000.
#   Load result[1]: expect 0xFFFFFFFFFFFFFFFF.
# ---------------------------------------------------------------------------
  TEST_CASE(3, x2, 0x4000000000000000, \
    li      x6, 2; \
    vsetvli x7, x6, e64, m1; \
    la      x5, dest_init; \
    vle64.v v4, (x5); \
    la      x5, mask01; \
    vle64.v v0, (x5); \
    la      x5, f64_ones; \
    vle64.v v2, (x5); \
    la      x5, f64_ones; \
    vle64.v v3, (x5); \
    vfadd.vv v4, v2, v3, v0.t; \
    la      x5, result; \
    vse64.v v4, (x5); \
    ld      x2, 0(x5); \
    )

  TEST_CASE(4, x2, 0xFFFFFFFFFFFFFFFF, \
    li      x6, 2; \
    vsetvli x7, x6, e64, m1; \
    la      x5, dest_init; \
    vle64.v v4, (x5); \
    la      x5, mask01; \
    vle64.v v0, (x5); \
    la      x5, f64_ones; \
    vle64.v v2, (x5); \
    la      x5, f64_ones; \
    vle64.v v3, (x5); \
    vfadd.vv v4, v2, v3, v0.t; \
    la      x5, result; \
    vse64.v v4, (x5); \
    ld      x2, 8(x5); \
    )

# ---------------------------------------------------------------------------
# Test 5: vfmul.vv SEW=64 LMUL=1, unmasked.
#   vl=2, vs2=[2.0, 3.0], vs1=[3.0, 2.0]
#   result=[6.0, 6.0] = [0x4018000000000000, 0x4018000000000000]
# ---------------------------------------------------------------------------
  TEST_CASE(5, x2, 0x4018000000000000, \
    li      x6, 2; \
    vsetvli x7, x6, e64, m1; \
    la      x5, f64_c; \
    vle64.v v2, (x5); \
    la      x5, f64_d; \
    vle64.v v3, (x5); \
    vfmul.vv v4, v2, v3; \
    la      x5, result; \
    vse64.v v4, (x5); \
    ld      x2, 0(x5); \
    )

# ---------------------------------------------------------------------------
# Test 6: vfmacc.vv SEW=64 LMUL=1.
#   Assembly: vfmacc.vv vd, vs1, vs2  => vd[i] = vd[i] + vs1[i] * vs2[i]
#   Pre-load vd with [3.0, 3.0].
#   vs1 = [1.0, 1.0], vs2 = [2.0, 2.0]
#   result = [3.0 + 1.0*2.0, 3.0 + 1.0*2.0] = [5.0, 5.0] = 0x4014000000000000
# ---------------------------------------------------------------------------
  TEST_CASE(6, x2, 0x4014000000000000, \
    li      x6, 2; \
    vsetvli x7, x6, e64, m1; \
    la      x5, f64_threes; \
    vle64.v v4, (x5); \
    la      x5, f64_ones; \
    vle64.v v2, (x5); \
    la      x5, f64_twos; \
    vle64.v v3, (x5); \
    vfmacc.vv v4, v2, v3; \
    la      x5, result; \
    vse64.v v4, (x5); \
    ld      x2, 0(x5); \
    )

# ---------------------------------------------------------------------------
# Test 7: vfadd.vv SEW=64 LMUL=8 (16 elements, spans 8 registers).
#   Verify element 8 (first element of second half of register group) is correct.
#   All elements = 1.0 + 1.0 = 2.0.
#   Result element 8 is at result + 8*8 = result + 64 bytes.
# ---------------------------------------------------------------------------
  TEST_CASE(7, x2, 0x4000000000000000, \
    li      x6, 16; \
    vsetvli x7, x6, e64, m8; \
    la      x5, f64_ones16; \
    vle64.v v8, (x5); \
    la      x5, f64_ones16; \
    vle64.v v16, (x5); \
    vfadd.vv v24, v8, v16; \
    la      x5, result; \
    vse64.v v24, (x5); \
    ld      x2, 64(x5); \
    )

# ---------------------------------------------------------------------------
# Test 8: vfdiv.vv SEW=64 LMUL=1 — exercises f64_div via ISS.
#   vl=1, vs2=[6.0], vs1=[2.0] => result[0] = 3.0 = 0x4008000000000000
# ---------------------------------------------------------------------------
  TEST_CASE(8, x2, 0x4008000000000000, \
    li      x6, 1; \
    vsetvli x7, x6, e64, m1; \
    la      x5, f64_sixes; \
    vle64.v v2, (x5); \
    la      x5, f64_twos; \
    vle64.v v3, (x5); \
    vfdiv.vv v4, v2, v3; \
    la      x5, result; \
    vse64.v v4, (x5); \
    ld      x2, 0(x5); \
    )

# ---------------------------------------------------------------------------
# Test 9: vfsqrt.v SEW=64 — exercises f64_sqrt via ISS.
#   vl=1, vs2=[4.0] => result[0] = 2.0 = 0x4000000000000000
# ---------------------------------------------------------------------------
  TEST_CASE(9, x2, 0x4000000000000000, \
    li      x6, 1; \
    vsetvli x7, x6, e64, m1; \
    la      x5, f64_fours; \
    vle64.v v2, (x5); \
    vfsqrt.v v4, v2; \
    la      x5, result; \
    vse64.v v4, (x5); \
    ld      x2, 0(x5); \
    )

# ---------------------------------------------------------------------------
# Test 10: vfcvt.x.f.v SEW=64 — f64→i64, exercises f64_to_i64 via ISS.
#   vl=1, vs2=[10.0] => result[0] = 10 = 0x000000000000000A
# ---------------------------------------------------------------------------
  TEST_CASE(10, x2, 0x000000000000000A, \
    li      x6, 1; \
    vsetvli x7, x6, e64, m1; \
    la      x5, f64_tens; \
    vle64.v v2, (x5); \
    vfcvt.x.f.v v4, v2; \
    la      x5, result; \
    vse64.v v4, (x5); \
    ld      x2, 0(x5); \
    )

# ---------------------------------------------------------------------------
# Test 11: vfcvt.xu.f.v SEW=64 — f64→ui64, exercises f64_to_ui64 via ISS.
#   vl=1, vs2=[5.0] => result[0] = 5 = 0x0000000000000005
# ---------------------------------------------------------------------------
  TEST_CASE(11, x2, 0x0000000000000005, \
    li      x6, 1; \
    vsetvli x7, x6, e64, m1; \
    la      x5, f64_fives; \
    vle64.v v2, (x5); \
    vfcvt.xu.f.v v4, v2; \
    la      x5, result; \
    vse64.v v4, (x5); \
    ld      x2, 0(x5); \
    )

# ---------------------------------------------------------------------------
# Test 12: vfcvt.f.x.v SEW=64 — i64→f64, exercises i64_to_f64 via ISS.
#   vl=1, vs2=[3 (integer)] => result[0] = 3.0 = 0x4008000000000000
# ---------------------------------------------------------------------------
  TEST_CASE(12, x2, 0x4008000000000000, \
    li      x6, 1; \
    vsetvli x7, x6, e64, m1; \
    la      x5, i64_three; \
    vle64.v v2, (x5); \
    vfcvt.f.x.v v4, v2; \
    la      x5, result; \
    vse64.v v4, (x5); \
    ld      x2, 0(x5); \
    )

# ===========================================================================
# Phase 12C: widening FP arithmetic and FMA (SEW=32 -> 64)
# vsetivli with e32,m1 sets SEW=32; destination registers are at 2*SEW=64.
# f32 inputs: 1.0f=0x3F800000, 2.0f=0x40000000, 3.0f=0x40400000
# f64 init (4.0): 0x4010000000000000
# ===========================================================================

# ---------------------------------------------------------------------------
# Test 13: vfwadd.vv SEW=32 — widen(1.0f) + widen(2.0f) = 3.0 (f64)
#   Expected: 0x4008000000000000
# ---------------------------------------------------------------------------
  TEST_CASE(13, x2, 0x4008000000000000, \
    li      x6, 2; \
    vsetvli x7, x6, e32, m1; \
    la      x5, f32_ones_w; \
    vle32.v v2, (x5); \
    la      x5, f32_twos_w; \
    vle32.v v3, (x5); \
    vfwadd.vv v4, v2, v3; \
    la      x5, result; \
    vse64.v v4, (x5); \
    ld      x2, 0(x5); \
    )

# ---------------------------------------------------------------------------
# Test 14: vfwsub.vv SEW=32 — widen(2.0f) - widen(1.0f) = 1.0 (f64)
#   Expected: 0x3FF0000000000000
# ---------------------------------------------------------------------------
  TEST_CASE(14, x2, 0x3FF0000000000000, \
    li      x6, 1; \
    vsetvli x7, x6, e32, m1; \
    la      x5, f32_twos_w; \
    vle32.v v2, (x5); \
    la      x5, f32_ones_w; \
    vle32.v v3, (x5); \
    vfwsub.vv v4, v2, v3; \
    la      x5, result; \
    vse64.v v4, (x5); \
    ld      x2, 0(x5); \
    )

# ---------------------------------------------------------------------------
# Test 15: vfwmul.vv SEW=32 — widen(2.0f) * widen(3.0f) = 6.0 (f64)
#   Expected: 0x4018000000000000
# ---------------------------------------------------------------------------
  TEST_CASE(15, x2, 0x4018000000000000, \
    li      x6, 1; \
    vsetvli x7, x6, e32, m1; \
    la      x5, f32_twos_w; \
    vle32.v v2, (x5); \
    la      x5, f32_threes_w; \
    vle32.v v3, (x5); \
    vfwmul.vv v4, v2, v3; \
    la      x5, result; \
    vse64.v v4, (x5); \
    ld      x2, 0(x5); \
    )

# ---------------------------------------------------------------------------
# Test 16: vfwadd.wv — wide_vs2(4.0 f64) + widen(1.0f) = 5.0 (f64)
#   Expected: 0x4014000000000000
# ---------------------------------------------------------------------------
  TEST_CASE(16, x2, 0x4014000000000000, \
    li      x6, 1; \
    vsetvli x7, x6, e32, m1; \
    la      x5, f64_init4; \
    vle64.v v4, (x5); \
    la      x5, f32_ones_w; \
    vle32.v v3, (x5); \
    vfwadd.wv v8, v4, v3; \
    la      x5, result; \
    vse64.v v8, (x5); \
    ld      x2, 0(x5); \
    )

# ---------------------------------------------------------------------------
# Test 17: vfwmacc.vv — vd=4.0 + widen(1.0f)*widen(2.0f) = 6.0 (f64)
#   Expected: 0x4018000000000000
# ---------------------------------------------------------------------------
  TEST_CASE(17, x2, 0x4018000000000000, \
    li      x6, 1; \
    vsetvli x7, x6, e32, m1; \
    la      x5, f64_init4; \
    vle64.v v4, (x5); \
    la      x5, f32_ones_w; \
    vle32.v v2, (x5); \
    la      x5, f32_twos_w; \
    vle32.v v3, (x5); \
    vfwmacc.vv v4, v2, v3; \
    la      x5, result; \
    vse64.v v4, (x5); \
    ld      x2, 0(x5); \
    )

# ---------------------------------------------------------------------------
# Test 18: vfwnmacc.vv — -(4.0 + widen(1.0f)*widen(2.0f)) = -6.0 (f64)
#   Expected: 0xC018000000000000
# ---------------------------------------------------------------------------
  TEST_CASE(18, x2, 0xC018000000000000, \
    li      x6, 1; \
    vsetvli x7, x6, e32, m1; \
    la      x5, f64_init4; \
    vle64.v v4, (x5); \
    la      x5, f32_ones_w; \
    vle32.v v2, (x5); \
    la      x5, f32_twos_w; \
    vle32.v v3, (x5); \
    vfwnmacc.vv v4, v2, v3; \
    la      x5, result; \
    vse64.v v4, (x5); \
    ld      x2, 0(x5); \
    )

# ---------------------------------------------------------------------------
# Test 19: vfwmsac.vv — widen(1.0f)*widen(2.0f) - 4.0 = -2.0 (f64)
#   Expected: 0xC000000000000000
# ---------------------------------------------------------------------------
  TEST_CASE(19, x2, 0xC000000000000000, \
    li      x6, 1; \
    vsetvli x7, x6, e32, m1; \
    la      x5, f64_init4; \
    vle64.v v4, (x5); \
    la      x5, f32_ones_w; \
    vle32.v v2, (x5); \
    la      x5, f32_twos_w; \
    vle32.v v3, (x5); \
    vfwmsac.vv v4, v2, v3; \
    la      x5, result; \
    vse64.v v4, (x5); \
    ld      x2, 0(x5); \
    )

# ---------------------------------------------------------------------------
# Test 20: vfwnmsac.vv — -(widen(1.0f))*widen(2.0f) + 4.0 = 2.0 (f64)
#   Expected: 0x4000000000000000
# ---------------------------------------------------------------------------
  TEST_CASE(20, x2, 0x4000000000000000, \
    li      x6, 1; \
    vsetvli x7, x6, e32, m1; \
    la      x5, f64_init4; \
    vle64.v v4, (x5); \
    la      x5, f32_ones_w; \
    vle32.v v2, (x5); \
    la      x5, f32_twos_w; \
    vle32.v v3, (x5); \
    vfwnmsac.vv v4, v2, v3; \
    la      x5, result; \
    vse64.v v4, (x5); \
    ld      x2, 0(x5); \
    )

# ===========================================================================
# Phase 12D: widening/narrowing FP converts
# Closes final 12A ISS gaps: f32_to_f64, f64_to_f32, and ROD rounding.
# ===========================================================================

# ---------------------------------------------------------------------------
# Test 21: vfwcvt.f.f.v — f32→f64 (exercises f32_to_f64).
#   vl=1, vs2=[1.5f=0x3FC00000] => vd[0] = 1.5 (f64) = 0x3FF8000000000000
# ---------------------------------------------------------------------------
  TEST_CASE(21, x2, 0x3FF8000000000000, \
    li      x6, 1; \
    vsetvli x7, x6, e32, m1; \
    la      x5, f32_onehalf; \
    vle32.v v2, (x5); \
    vfwcvt.f.f.v v4, v2; \
    la      x5, result; \
    vse64.v v4, (x5); \
    ld      x2, 0(x5); \
    )

# ---------------------------------------------------------------------------
# Test 22: vfncvt.f.f.w — f64→f32 (exercises f64_to_f32, dynamic RNE).
#   vl=1, vs2=[pi as f64=0x400921FB54442D18] => vd[0] = pi as f32 = 0x40490FDB
# ---------------------------------------------------------------------------
  TEST_CASE(22, x2, 0x0000000040490FDB, \
    li      x6, 1; \
    vsetvli x7, x6, e32, m1; \
    la      x5, f64_pi; \
    vle64.v v4, (x5); \
    vfncvt.f.f.w v2, v4; \
    la      x5, result; \
    vse32.v v2, (x5); \
    lw      x2, 0(x5); \
    )

# ---------------------------------------------------------------------------
# Test 23: vfncvt.rod.f.f.w — f64→f32 round-to-odd (exercises ROD mode).
#   Midpoint between 1.0f and nextf32: 0x3FF0000010000000
#   RNE -> 0x3F800000 (even), ROD -> 0x3F800001 (odd)
#   Expected: 0x000000003F800001
# ---------------------------------------------------------------------------
  TEST_CASE(23, x2, 0x000000003F800001, \
    li      x6, 1; \
    vsetvli x7, x6, e32, m1; \
    la      x5, f64_midpoint; \
    vle64.v v4, (x5); \
    vfncvt.rod.f.f.w v2, v4; \
    la      x5, result; \
    vse32.v v2, (x5); \
    lw      x2, 0(x5); \
    )

# ---------------------------------------------------------------------------
# Test 24: vfwcvt.x.f.v — f32→i64 (exercises f32_to_i64).
#   vl=1, vs2=[7.5f=0x40F00000], RTZ => i64(7) = 0x0000000000000007
# ---------------------------------------------------------------------------
  TEST_CASE(24, x2, 0x0000000000000007, \
    li      x6, 1; \
    vsetvli x7, x6, e32, m1; \
    la      x5, f32_sevenhalf; \
    vle32.v v2, (x5); \
    vfwcvt.rtz.x.f.v v4, v2; \
    la      x5, result; \
    vse64.v v4, (x5); \
    ld      x2, 0(x5); \
    )

  TEST_PASSFAIL

RVTEST_CODE_END

.data
  .balign 8

# f64 input arrays
f64_a:
  .quad 0x3FF0000000000000   # 1.0
  .quad 0x4000000000000000   # 2.0

f64_b:
  .quad 0x3FF0000000000000   # 1.0
  .quad 0x4008000000000000   # 3.0

f64_c:
  .quad 0x4000000000000000   # 2.0
  .quad 0x4008000000000000   # 3.0

f64_d:
  .quad 0x4008000000000000   # 3.0
  .quad 0x4000000000000000   # 2.0

f64_ones:
  .quad 0x3FF0000000000000   # 1.0
  .quad 0x3FF0000000000000   # 1.0

f64_twos:
  .quad 0x4000000000000000   # 2.0
  .quad 0x4000000000000000   # 2.0

f64_threes:
  .quad 0x4008000000000000   # 3.0
  .quad 0x4008000000000000   # 3.0

f64_fours:
  .quad 0x4010000000000000   # 4.0
  .quad 0x4010000000000000   # 4.0

f64_fives:
  .quad 0x4014000000000000   # 5.0
  .quad 0x4014000000000000   # 5.0

f64_sixes:
  .quad 0x4018000000000000   # 6.0
  .quad 0x4018000000000000   # 6.0

f64_tens:
  .quad 0x4024000000000000   # 10.0
  .quad 0x4024000000000000   # 10.0

i64_three:
  .quad 3                    # signed 64-bit integer 3
  .quad 3

# f32 inputs for widening tests (stored as 32-bit words, 2 per entry)
f32_ones_w:
  .word 0x3F800000           # 1.0f
  .word 0x3F800000           # 1.0f

f32_twos_w:
  .word 0x40000000           # 2.0f
  .word 0x40000000           # 2.0f

f32_threes_w:
  .word 0x40400000           # 3.0f
  .word 0x40400000           # 3.0f

# f64 initial accumulator (4.0) for widening FMA tests
f64_init4:
  .quad 0x4010000000000000   # 4.0 (f64)
  .quad 0x4010000000000000   # 4.0 (f64)

# 12D convert test data
f32_onehalf:
  .word 0x3FC00000           # 1.5f
  .word 0x3FC00000

f32_sevenhalf:
  .word 0x40F00000           # 7.5f
  .word 0x40F00000

f64_pi:
  .quad 0x400921FB54442D18   # pi as f64
  .quad 0x400921FB54442D18

f64_midpoint:
  .quad 0x3FF0000010000000   # exact midpoint 1.0f..nextafter(1.0f); RNE->0x3F800000, ROD->0x3F800001
  .quad 0x3FF0000010000000

# 16 x 1.0 for LMUL=8 test
f64_ones16:
  .quad 0x3FF0000000000000
  .quad 0x3FF0000000000000
  .quad 0x3FF0000000000000
  .quad 0x3FF0000000000000
  .quad 0x3FF0000000000000
  .quad 0x3FF0000000000000
  .quad 0x3FF0000000000000
  .quad 0x3FF0000000000000
  .quad 0x3FF0000000000000
  .quad 0x3FF0000000000000
  .quad 0x3FF0000000000000
  .quad 0x3FF0000000000000
  .quad 0x3FF0000000000000
  .quad 0x3FF0000000000000
  .quad 0x3FF0000000000000
  .quad 0x3FF0000000000000

# mask: bit 0 set (element 0 active), bit 1 clear (element 1 inactive)
mask01:
  .quad 0x0000000000000001
  .quad 0x0000000000000000

# pre-fill destination with all-ones (undisturbed sentinel)
dest_init:
  .quad 0xFFFFFFFFFFFFFFFF
  .quad 0xFFFFFFFFFFFFFFFF

RVTEST_DATA_BEGIN

result:
  .fill 128, 1, -1     # 128 bytes = 16 f64 slots, all 0xFF initially

RVTEST_DATA_END
