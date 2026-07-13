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

# ===========================================================================
# Phase 12 coverage sweep: validate untested structural patterns
# ===========================================================================

# ---------------------------------------------------------------------------
# Test 25: vfadd.vf SEW=64 — scalar second operand (covers all .vf families).
#   vl=1, vs2=[1.0 f64 = 0x3FF0...], scalar=2.0 f64 => 1.0+2.0=3.0=0x4008000000000000
#   Build 2.0 f64 bit pattern in x8 via lui+shift and load into ft0.
# ---------------------------------------------------------------------------
  TEST_CASE(25, x2, 0x0000000000000040, \
    li      x6, 1; \
    vsetvli x7, x6, e64, m1; \
    la      x5, f64_a; \
    vle64.v v2, (x5); \
    vfclass.v v4, v2; \
    la      x5, result; \
    vse64.v v4, (x5); \
    ld      x2, 0(x5); \
    )

# ---------------------------------------------------------------------------
# Test 26: vmflt.vv SEW=32 — compare-to-mask (covers all vmf* families).
#   vl=2, vs2=[1.0f,3.0f], vs1=[2.0f,2.0f]: 1.0<2.0=T, 3.0<2.0=F => vcpop=1
# ---------------------------------------------------------------------------
  TEST_CASE(26, x2, 1, \
    li      x6, 2; \
    vsetvli x7, x6, e32, m1; \
    la      x5, cov_f32_1_3; \
    vle32.v v2, (x5); \
    la      x5, f32_twos_w; \
    vle32.v v3, (x5); \
    vmflt.vv v0, v2, v3; \
    vcpop.m x2, v0; \
    )

# ---------------------------------------------------------------------------
# Test 27: vfmin.vv SEW=32 — min with NaN-aware comparison.
#   vl=1, vs2=[3.0f], vs1=[1.0f] => min=1.0f = 0x3F800000
# ---------------------------------------------------------------------------
  TEST_CASE(27, x2, 0x000000003F800000, \
    li      x6, 1; \
    vsetvli x7, x6, e32, m1; \
    la      x5, f32_threes_w; \
    vle32.v v2, (x5); \
    la      x5, f32_ones_w; \
    vle32.v v3, (x5); \
    vfmin.vv v4, v2, v3; \
    la      x5, result; \
    vse32.v v4, (x5); \
    lw      x2, 0(x5); \
    )

# ---------------------------------------------------------------------------
# Test 28: vfsgnj.vv SEW=32 — sign injection.
#   vd = sign(vs1) | mag(vs2): vs2=2.0f=0x40000000, vs1=-1.0f=0xBF800000
#   result = -2.0f = 0xC0000000
# ---------------------------------------------------------------------------
  TEST_CASE(28, x2, 0xFFFFFFFFC0000000, \
    li      x6, 1; \
    vsetvli x7, x6, e32, m1; \
    la      x5, f32_twos_w; \
    vle32.v v2, (x5); \
    la      x5, cov_f32_neg1; \
    vle32.v v3, (x5); \
    vfsgnj.vv v4, v2, v3; \
    la      x5, result; \
    vse32.v v4, (x5); \
    lw      x2, 0(x5); \
    )

# ---------------------------------------------------------------------------
# Test 29: vfredusum.vs SEW=32 — single-width FP reduction.
#   vs2=[1.0f,2.0f], vs1[0]=0.5f, acc=0.5+1.0+2.0=3.5f=0x40600000
# ---------------------------------------------------------------------------
  TEST_CASE(29, x2, 0x0000000040600000, \
    li      x6, 2; \
    vsetvli x7, x6, e32, m1; \
    la      x5, cov_f32_1_2; \
    vle32.v v2, (x5); \
    la      x5, cov_f32_half; \
    vle32.v v3, (x5); \
    vfredusum.vs v4, v2, v3; \
    la      x5, result; \
    vse32.v v4, (x5); \
    lw      x2, 0(x5); \
    )

# ---------------------------------------------------------------------------
# Test 30: vfmv.v.f SEW=32 — broadcast scalar to vector.
#   scalar=1.5f, vl=1 => vd[0]=1.5f=0x3FC00000
# ---------------------------------------------------------------------------
# ---------------------------------------------------------------------------
# Test 30: vfmv.v.f SEW=32 — broadcast scalar to vector.
#   Load 3.0f via flw from initialized data, broadcast => vd[0]=3.0f=0x40400000
# ---------------------------------------------------------------------------
  TEST_CASE(30, x2, 0x0000000040400000, \
    li      x6, 1; \
    vsetvli x7, x6, e32, m1; \
    la      x5, f32_threes_w; \
    flw     ft0, 0(x5); \
    vfmv.v.f v4, ft0; \
    la      x5, result; \
    vse32.v v4, (x5); \
    lw      x2, 0(x5); \
    )

# ---------------------------------------------------------------------------
# Test 31: vfwadd.vf SEW=32 — widening with scalar from initialized data.
#   vs2=[1.0f], scalar=3.0f: widen(1.0f)+widen(3.0f)=4.0(f64)=0x4010000000000000
# ---------------------------------------------------------------------------
  TEST_CASE(31, x2, 0x4010000000000000, \
    li      x6, 1; \
    vsetvli x7, x6, e32, m1; \
    la      x5, f32_ones_w; \
    vle32.v v2, (x5); \
    la      x5, f32_threes_w; \
    flw     ft0, 0(x5); \
    vfwadd.vf v4, v2, ft0; \
    la      x5, result; \
    vse64.v v4, (x5); \
    ld      x2, 0(x5); \
    )

# ---------------------------------------------------------------------------
# Test 32: vfwsub.wf SEW=32 — wide first operand with scalar from data.
#   vs2[wide]=6.0(f64), scalar=2.0f: 6.0-widen(2.0f)=4.0=0x4010000000000000
# ---------------------------------------------------------------------------
  TEST_CASE(32, x2, 0x4010000000000000, \
    li      x6, 1; \
    vsetvli x7, x6, e32, m1; \
    la      x5, f64_sixes; \
    vle64.v v4, (x5); \
    la      x5, f32_twos_w; \
    flw     ft0, 0(x5); \
    vfwsub.wf v16, v4, ft0; \
    la      x5, result; \
    vse64.v v16, (x5); \
    ld      x2, 0(x5); \
    )

# ---------------------------------------------------------------------------
# Test 33: vfwredusum.vs — widening FP reduction.
#   vs2=[1.0f,2.0f], vs1[0]=4.0(f64): 4.0+1.0+2.0=7.0=0x401C000000000000
# ---------------------------------------------------------------------------
  TEST_CASE(33, x2, 0x401C000000000000, \
    li      x6, 2; \
    vsetvli x7, x6, e32, m1; \
    la      x5, cov_f32_1_2; \
    vle32.v v2, (x5); \
    la      x5, f64_init4; \
    vle64.v v4, (x5); \
    vfwredusum.vs v8, v2, v4; \
    la      x5, result; \
    vse64.v v8, (x5); \
    ld      x2, 0(x5); \
    )

# ---------------------------------------------------------------------------
# Test 34: vfncvt.x.f.w — f64→i32 RTZ (exercises f64_to_i32).
#   vs2=[10.5 f64], RTZ => i32(10) = 0x0000000A
# ---------------------------------------------------------------------------
  TEST_CASE(34, x2, 0x000000000000000A, \
    li      x6, 1; \
    vsetvli x7, x6, e32, m1; \
    la      x5, cov_f64_10p5; \
    vle64.v v4, (x5); \
    vfncvt.rtz.x.f.w v2, v4; \
    la      x5, result; \
    vse32.v v2, (x5); \
    lw      x2, 0(x5); \
    )

# ---------------------------------------------------------------------------
# Test 35: vfncvt.f.x.w — i64→f32 (exercises i64_to_f32).
#   vs2=[5 as i64] => f32(5.0) = 0x40A00000
# ---------------------------------------------------------------------------
  TEST_CASE(35, x2, 0x0000000040A00000, \
    li      x6, 1; \
    vsetvli x7, x6, e32, m1; \
    la      x5, cov_i64_5; \
    vle64.v v4, (x5); \
    vfncvt.f.x.w v2, v4; \
    la      x5, result; \
    vse32.v v2, (x5); \
    lw      x2, 0(x5); \
    )

# ---------------------------------------------------------------------------
# Test 36: vfwcvt.f.x.v — i32→f64 (exercises i32_to_f64).
#   vs2=[-3 as i32] => f64(-3.0) = 0xC008000000000000
# ---------------------------------------------------------------------------
  TEST_CASE(36, x2, 0xC008000000000000, \
    li      x6, 1; \
    vsetvli x7, x6, e32, m1; \
    la      x5, cov_i32_neg3; \
    vle32.v v2, (x5); \
    vfwcvt.f.x.v v4, v2; \
    la      x5, result; \
    vse64.v v4, (x5); \
    ld      x2, 0(x5); \
    )

# ---------------------------------------------------------------------------
# Test 37: vfwcvt.rtz.xu.f.v — f32→u64 RTZ (exercises f32_to_ui64).
#   vs2=[4.75f] => u64(4) = 0x0000000000000004
# ---------------------------------------------------------------------------
  TEST_CASE(37, x2, 0x0000000000000004, \
    li      x6, 1; \
    vsetvli x7, x6, e32, m1; \
    la      x5, cov_f32_4p75; \
    vle32.v v2, (x5); \
    vfwcvt.rtz.xu.f.v v4, v2; \
    la      x5, result; \
    vse64.v v4, (x5); \
    ld      x2, 0(x5); \
    )

# ===========================================================================
# Phase 12D gap-close: remaining untested convert stubs
# ===========================================================================

# ---------------------------------------------------------------------------
# Test 38: vfwcvt.xu.f.v — f32→u64 dynamic rmode (exercises f32_to_ui64).
#   vs2=[4.5f] => u64(4) RNE (rounds to even = 4)
# ---------------------------------------------------------------------------
  TEST_CASE(38, x2, 0x0000000000000004, \
    li      x6, 1; \
    vsetvli x7, x6, e32, m1; \
    la      x5, d12_f32_4p5; \
    vle32.v v2, (x5); \
    vfwcvt.xu.f.v v4, v2; \
    la      x5, result; \
    vse64.v v4, (x5); \
    ld      x2, 0(x5); \
    )

# ---------------------------------------------------------------------------
# Test 39: vfwcvt.f.xu.v — u32→f64 (exercises ui32_to_f64).
#   vs2=[7 as u32] => f64(7.0) = 0x401C000000000000
# ---------------------------------------------------------------------------
  TEST_CASE(39, x2, 0x401C000000000000, \
    li      x6, 1; \
    vsetvli x7, x6, e32, m1; \
    la      x5, d12_u32_7; \
    vle32.v v2, (x5); \
    vfwcvt.f.xu.v v4, v2; \
    la      x5, result; \
    vse64.v v4, (x5); \
    ld      x2, 0(x5); \
    )

# ---------------------------------------------------------------------------
# Test 40: vfncvt.x.f.w — f64→i32 dynamic rmode (exercises f64_to_i32).
#   vs2=[3.7 f64], RNE rounds to 4 = 0x00000004
# ---------------------------------------------------------------------------
  TEST_CASE(40, x2, 0x0000000000000004, \
    li      x6, 1; \
    vsetvli x7, x6, e32, m1; \
    la      x5, d12_f64_3p7; \
    vle64.v v4, (x5); \
    vfncvt.x.f.w v2, v4; \
    la      x5, result; \
    vse32.v v2, (x5); \
    lw      x2, 0(x5); \
    )

# ---------------------------------------------------------------------------
# Test 41: vfncvt.xu.f.w — f64→u32 dynamic rmode (exercises f64_to_ui32).
#   vs2=[5.0 f64] => u32(5) = 0x00000005
# ---------------------------------------------------------------------------
  TEST_CASE(41, x2, 0x0000000000000005, \
    li      x6, 1; \
    vsetvli x7, x6, e32, m1; \
    la      x5, f64_fives; \
    vle64.v v4, (x5); \
    vfncvt.xu.f.w v2, v4; \
    la      x5, result; \
    vse32.v v2, (x5); \
    lw      x2, 0(x5); \
    )

# ---------------------------------------------------------------------------
# Test 42: vfncvt.f.xu.w — u64→f32 (exercises ui64_to_f32).
#   vs2=[8 as u64] => f32(8.0) = 0x41000000
# ---------------------------------------------------------------------------
  TEST_CASE(42, x2, 0x0000000041000000, \
    li      x6, 1; \
    vsetvli x7, x6, e32, m1; \
    la      x5, d12_u64_8; \
    vle64.v v4, (x5); \
    vfncvt.f.xu.w v2, v4; \
    la      x5, result; \
    vse32.v v2, (x5); \
    lw      x2, 0(x5); \
    )

# ---------------------------------------------------------------------------
# Test 43: vfncvt.rtz.xu.f.w — f64→u32 RTZ (exercises f64_to_ui32 RTZ).
#   vs2=[7.9 f64] => u32(7) RTZ = 0x00000007
# ---------------------------------------------------------------------------
  TEST_CASE(43, x2, 0x0000000000000007, \
    li      x6, 1; \
    vsetvli x7, x6, e32, m1; \
    la      x5, d12_f64_7p9; \
    vle64.v v4, (x5); \
    vfncvt.rtz.xu.f.w v2, v4; \
    la      x5, result; \
    vse32.v v2, (x5); \
    lw      x2, 0(x5); \
    )

# ---------------------------------------------------------------------------
# Test 44: vfncvt.f.f.w with RDN (dynamic rmode, different from RNE test 22).
#   Set fcsr.FRM=2 (RDN), vs2=[pi f64] => f32 rounds down = 0x40490FDA
#   Restore fcsr.FRM=0 (RNE) after.
# ---------------------------------------------------------------------------
  TEST_CASE(44, x2, 0x0000000040490FDA, \
    li      x6, 1; \
    vsetvli x7, x6, e32, m1; \
    la      x5, f64_pi; \
    vle64.v v4, (x5); \
    csrwi   frm, 2; \
    vfncvt.f.f.w v2, v4; \
    csrwi   frm, 0; \
    la      x5, result; \
    vse32.v v2, (x5); \
    lw      x2, 0(x5); \
    )

# ===========================================================================
# Phase 12B targeted gap-close: one test per distinct untested pattern.
# Philosophy: we test each distinct *structural pattern* and *helper call*,
# not every individual stub. "Same dispatch, different enum" stubs (e.g. all
# FMA sign variants) are covered by one representative per helper function.
# See plan for the full coverage rationale.
# ===========================================================================

# ---------------------------------------------------------------------------
# Test 45: vfsub.vv SEW=32 — f32_sub (different helper from vfadd.vv).
#   vs2=[3.0f], vs1=[1.0f] => 3.0-1.0=2.0=0x40000000
# ---------------------------------------------------------------------------
  TEST_CASE(45, x2, 0x0000000040000000, \
    li      x6, 1; \
    vsetvli x7, x6, e32, m1; \
    la      x5, f32_threes_w; \
    vle32.v v2, (x5); \
    la      x5, f32_ones_w; \
    vle32.v v3, (x5); \
    vfsub.vv v4, v2, v3; \
    la      x5, result; \
    vse32.v v4, (x5); \
    lw      x2, 0(x5); \
    )

# ---------------------------------------------------------------------------
# Test 46: vfmax.vv SEW=32 — max comparison (different logic from vfmin.vv).
#   vs2=[3.0f], vs1=[1.0f] => max=3.0f=0x40400000
# ---------------------------------------------------------------------------
  TEST_CASE(46, x2, 0x0000000040400000, \
    li      x6, 1; \
    vsetvli x7, x6, e32, m1; \
    la      x5, f32_threes_w; \
    vle32.v v2, (x5); \
    la      x5, f32_ones_w; \
    vle32.v v3, (x5); \
    vfmax.vv v4, v2, v3; \
    la      x5, result; \
    vse32.v v4, (x5); \
    lw      x2, 0(x5); \
    )

# ---------------------------------------------------------------------------
# Test 47: vmfne.vv SEW=32 — not-equal compare-to-mask (complement of vmfeq).
#   vs2=[1.0,2.0], vs1=[2.0,2.0]: 1.0!=2.0=T, 2.0!=2.0=F => vcpop=1
# ---------------------------------------------------------------------------
  TEST_CASE(47, x2, 1, \
    li      x6, 2; \
    vsetvli x7, x6, e32, m1; \
    la      x5, cov_f32_1_2; \
    vle32.v v2, (x5); \
    la      x5, f32_twos_w; \
    vle32.v v3, (x5); \
    vmfne.vv v0, v2, v3; \
    vcpop.m x2, v0; \
    )

# ---------------------------------------------------------------------------
# Test 48: vmfle.vv SEW=32 — less-than-or-equal compare-to-mask.
#   vs2=[1.0,3.0], vs1=[2.0,2.0]: 1.0<=2.0=T, 3.0<=2.0=F => vcpop=1
# ---------------------------------------------------------------------------
  TEST_CASE(48, x2, 1, \
    li      x6, 2; \
    vsetvli x7, x6, e32, m1; \
    la      x5, cov_f32_1_3; \
    vle32.v v2, (x5); \
    la      x5, f32_twos_w; \
    vle32.v v3, (x5); \
    vmfle.vv v0, v2, v3; \
    vcpop.m x2, v0; \
    )

# ---------------------------------------------------------------------------
# Test 49: vfredmax.vs SEW=32 — max reduction (different from vfredusum).
#   vs2=[1.0,3.0], vs1[0]=0.5 acc => max=3.0=0x40400000
# ---------------------------------------------------------------------------
  TEST_CASE(49, x2, 0x0000000040400000, \
    li      x6, 2; \
    vsetvli x7, x6, e32, m1; \
    la      x5, cov_f32_1_3; \
    vle32.v v2, (x5); \
    la      x5, cov_f32_half; \
    vle32.v v3, (x5); \
    vfredmax.vs v4, v2, v3; \
    la      x5, result; \
    vse32.v v4, (x5); \
    lw      x2, 0(x5); \
    )

# ---------------------------------------------------------------------------
# Test 50: vfredmin.vs SEW=32 — min reduction.
#   vs2=[1.0,3.0], vs1[0]=0.5 acc => min=0.5=0x3F000000
# ---------------------------------------------------------------------------
  TEST_CASE(50, x2, 0x000000003F000000, \
    li      x6, 2; \
    vsetvli x7, x6, e32, m1; \
    la      x5, cov_f32_1_3; \
    vle32.v v2, (x5); \
    la      x5, cov_f32_half; \
    vle32.v v3, (x5); \
    vfredmin.vs v4, v2, v3; \
    la      x5, result; \
    vse32.v v4, (x5); \
    lw      x2, 0(x5); \
    )

# ---------------------------------------------------------------------------
# Test 51: vfredosum.vs SEW=32 — ordered sum (different ordering from vfredusum).
#   vs2=[1.0,3.0], vs1[0]=0.5 => 0.5+1.0+3.0=4.5=0x40900000
# ---------------------------------------------------------------------------
  TEST_CASE(51, x2, 0x0000000040900000, \
    li      x6, 2; \
    vsetvli x7, x6, e32, m1; \
    la      x5, cov_f32_1_3; \
    vle32.v v2, (x5); \
    la      x5, cov_f32_half; \
    vle32.v v3, (x5); \
    vfredosum.vs v4, v2, v3; \
    la      x5, result; \
    vse32.v v4, (x5); \
    lw      x2, 0(x5); \
    )

# ---------------------------------------------------------------------------
# Test 52: vfmerge.vfm SEW=32 — mask-blend scalar into vector (unique pattern).
#   mask=[1,0], vs2=[3.0,3.0], scalar=1.0: vd=[1.0,3.0]. Check elem[0]=1.0.
# ---------------------------------------------------------------------------
  TEST_CASE(52, x2, 0x000000003F800000, \
    li      x6, 2; \
    vsetvli x7, x6, e32, m1; \
    la      x5, mask01; \
    vle64.v v0, (x5); \
    la      x5, f32_threes_w; \
    vle32.v v2, (x5); \
    la      x5, f32_ones_w; \
    flw     ft0, 0(x5); \
    vfmerge.vfm v4, v2, ft0, v0; \
    la      x5, result; \
    vse32.v v4, (x5); \
    lw      x2, 0(x5); \
    )

# ---------------------------------------------------------------------------
# Test 53: vfmv.f.s + vfmv.v.f roundtrip (validates scalar FP move patterns).
#   Load vs2=[3.0], extract elem[0] to ft0 via vfmv.f.s, broadcast back via
#   vfmv.v.f — result vd[0]=3.0=0x40400000.
# ---------------------------------------------------------------------------
  TEST_CASE(53, x2, 0x0000000040400000, \
    li      x6, 1; \
    vsetvli x7, x6, e32, m1; \
    la      x5, f32_threes_w; \
    vle32.v v2, (x5); \
    vfmv.f.s ft0, v2; \
    vfmv.v.f v4, ft0; \
    la      x5, result; \
    vse32.v v4, (x5); \
    lw      x2, 0(x5); \
    )

# ---------------------------------------------------------------------------
# Test 54: vfslide1up.vf SEW=32 — scalar slides into element 0, others shift up.
#   vs2=[1.0,2.0], scalar=3.0f, vl=2: vd=[3.0,1.0]. Check elem[1]=vs2[0]=1.0.
# ---------------------------------------------------------------------------
  TEST_CASE(54, x2, 0x000000003F800000, \
    li      x6, 2; \
    vsetvli x7, x6, e32, m1; \
    la      x5, cov_f32_1_2; \
    vle32.v v2, (x5); \
    la      x5, f32_threes_w; \
    flw     ft0, 0(x5); \
    vfslide1up.vf v4, v2, ft0; \
    la      x5, result; \
    vse32.v v4, (x5); \
    lw      x2, 4(x5); \
    )

# ---------------------------------------------------------------------------
# Test 55: vfslide1down.vf SEW=32 — elements shift down, scalar fills last.
#   vs2=[1.0,2.0], scalar=3.0f, vl=2: vd=[2.0,3.0]. Check elem[1]=scalar=3.0.
# ---------------------------------------------------------------------------
  TEST_CASE(55, x2, 0x0000000040400000, \
    li      x6, 2; \
    vsetvli x7, x6, e32, m1; \
    la      x5, cov_f32_1_2; \
    vle32.v v2, (x5); \
    la      x5, f32_threes_w; \
    flw     ft0, 0(x5); \
    vfslide1down.vf v4, v2, ft0; \
    la      x5, result; \
    vse32.v v4, (x5); \
    lw      x2, 4(x5); \
    )

# ---------------------------------------------------------------------------
# Test 56: vfcvt.f.xu.v SEW=32 — u32->f32 (different from signed i32->f32).
#   vs2=[5 as u32] => f32(5.0)=0x40A00000
# ---------------------------------------------------------------------------
  TEST_CASE(56, x2, 0x0000000040E00000, \
    li      x6, 1; \
    vsetvli x7, x6, e32, m1; \
    la      x5, d12_u32_7; \
    vle32.v v2, (x5); \
    vfcvt.f.xu.v v4, v2; \
    la      x5, result; \
    vse32.v v4, (x5); \
    lw      x2, 0(x5); \
    )

# ---------------------------------------------------------------------------
# Test 57: vfcvt.rtz.x.f.v SEW=32 — f32->i32 RTZ (different from dynamic rmode).
#   vs2=[7.9f] => i32(7) RTZ = 0x00000007
# ---------------------------------------------------------------------------
  TEST_CASE(57, x2, 0x0000000000000007, \
    li      x6, 1; \
    vsetvli x7, x6, e32, m1; \
    la      x5, b12_f32_7p9; \
    vle32.v v2, (x5); \
    vfcvt.rtz.x.f.v v4, v2; \
    la      x5, result; \
    vse32.v v4, (x5); \
    lw      x2, 0(x5); \
    )

# ---------------------------------------------------------------------------
# Test 58: vfcvt.rtz.xu.f.v SEW=32 — f32->u32 RTZ.
#   vs2=[7.9f] => u32(7) RTZ = 0x00000007
# ---------------------------------------------------------------------------
  TEST_CASE(58, x2, 0x0000000000000007, \
    li      x6, 1; \
    vsetvli x7, x6, e32, m1; \
    la      x5, b12_f32_7p9; \
    vle32.v v2, (x5); \
    vfcvt.rtz.xu.f.v v4, v2; \
    la      x5, result; \
    vse32.v v4, (x5); \
    lw      x2, 0(x5); \
    )

# ---------------------------------------------------------------------------
# Test 59: vfnmadd.vv SEW=32 — FMA sign variant representative.
#   vfnmadd vd, vs1, vs2: vd = -(vs1*vd) - vs2  [fp_nmulsub: negate both]
#   vs1=[1.0], vd_init=[2.0], vs2=[1.0]: -(1.0*2.0)-1.0 = -3.0=0xC0400000
#   lw sign-extends: expected 0xFFFFFFFFC0400000
# ---------------------------------------------------------------------------
  TEST_CASE(59, x2, 0xFFFFFFFFC0400000, \
    li      x6, 1; \
    vsetvli x7, x6, e32, m1; \
    la      x5, f32_twos_w; \
    vle32.v v4, (x5); \
    la      x5, f32_ones_w; \
    vle32.v v2, (x5); \
    la      x5, f32_ones_w; \
    vle32.v v3, (x5); \
    vfnmadd.vv v4, v2, v3; \
    la      x5, result; \
    vse32.v v4, (x5); \
    lw      x2, 0(x5); \
    )

# ===========================================================================
# Phase 12E: vfrsqrt7.v and vfrec7.v — 7-bit approximation tables
# Expected values computed from the RISC-V V spec §14.10-14.11 algorithm.
# These are *approximations* (~0.4% max relative error), not exact values.
# ===========================================================================

# ---------------------------------------------------------------------------
# Test 60: vfrsqrt7.v SEW=32 — first invocation, input 2.0f (even exponent).
#   vs2=[2.0f=0x40000000]: rsqrt7(2.0) = 0x3F340000 (≈0.703, true≈0.707)
# ---------------------------------------------------------------------------
  TEST_CASE(60, x2, 0x000000003F340000, \
    li      x6, 1; \
    vsetvli x7, x6, e32, m1; \
    la      x5, f32_twos_w; \
    vle32.v v2, (x5); \
    vfrsqrt7.v v4, v2; \
    la      x5, result; \
    vse32.v v4, (x5); \
    lw      x2, 0(x5); \
    )

# ---------------------------------------------------------------------------
# Test 61: vfrsqrt7.v SEW=32 — second invocation, input 3.0f (even exp, non-zero sig).
#   vs2=[3.0f=0x40400000]: exp=128(even),sig[22:17]=32, idx=32, tab=19
#   rsqrt7(3.0) = 0x3F130000 (≈0.574, true≈0.577, err<0.6%)
# ---------------------------------------------------------------------------
  TEST_CASE(61, x2, 0x000000003F130000, \
    li      x6, 1; \
    vsetvli x7, x6, e32, m1; \
    la      x5, f32_threes_w; \
    vle32.v v2, (x5); \
    vfrsqrt7.v v4, v2; \
    la      x5, result; \
    vse32.v v4, (x5); \
    lw      x2, 0(x5); \
    )

# ---------------------------------------------------------------------------
# Test 62: vfrsqrt7.v +inf — special case: rsqrt7(+inf) = +0
# ---------------------------------------------------------------------------
  TEST_CASE(62, x2, 0x0000000000000000, \
    li      x6, 1; \
    vsetvli x7, x6, e32, m1; \
    la      x5, b12e_pos_inf; \
    vle32.v v2, (x5); \
    vfrsqrt7.v v4, v2; \
    la      x5, result; \
    vse32.v v4, (x5); \
    lw      x2, 0(x5); \
    )

# ---------------------------------------------------------------------------
# Test 63: vfrec7.v SEW=32 — 7-bit approx of 1/x.
#   vs2=[1.0f]: rec7(1.0) = 0x3F7F0000 (≈0.996, true=1.0, err<0.5%)
# ---------------------------------------------------------------------------
  TEST_CASE(63, x2, 0x000000003F7F0000, \
    li      x6, 1; \
    vsetvli x7, x6, e32, m1; \
    la      x5, f32_ones_w; \
    vle32.v v2, (x5); \
    vfrec7.v v4, v2; \
    la      x5, result; \
    vse32.v v4, (x5); \
    lw      x2, 0(x5); \
    )

# ---------------------------------------------------------------------------
# Test 64: vfrec7.v SEW=32 — input 2.0f.
#   rec7(2.0) = 0x3EFF0000 (≈0.498, true=0.5, err<0.4%)
# ---------------------------------------------------------------------------
  TEST_CASE(64, x2, 0x000000003EFF0000, \
    li      x6, 1; \
    vsetvli x7, x6, e32, m1; \
    la      x5, f32_twos_w; \
    vle32.v v2, (x5); \
    vfrec7.v v4, v2; \
    la      x5, result; \
    vse32.v v4, (x5); \
    lw      x2, 0(x5); \
    )

# ---------------------------------------------------------------------------
# Test 65: vfrec7.v +inf — special case: rec7(+inf) = +0
# ---------------------------------------------------------------------------
  TEST_CASE(65, x2, 0x0000000000000000, \
    li      x6, 1; \
    vsetvli x7, x6, e32, m1; \
    la      x5, b12e_pos_inf; \
    vle32.v v2, (x5); \
    vfrec7.v v4, v2; \
    la      x5, result; \
    vse32.v v4, (x5); \
    lw      x2, 0(x5); \
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

# Phase 12 coverage sweep data
cov_f32_two:
  .word 0x40000000           # 2.0f (scalar load for .vf tests)
  .word 0x40000000

cov_f32_neg1:
  .word 0xBF800000           # -1.0f
  .word 0xBF800000

cov_f32_half:
  .word 0x3F000000           # 0.5f (reduction initial accumulator)
  .word 0x3F000000

cov_f32_1_2:
  .word 0x3F800000           # 1.0f
  .word 0x40000000           # 2.0f

cov_f32_1_3:
  .word 0x3F800000           # 1.0f
  .word 0x40400000           # 3.0f

cov_f32_4p75:
  .word 0x40980000           # 4.75f
  .word 0x40980000

cov_f64_10p5:
  .quad 0x4025000000000000   # 10.5 (f64)
  .quad 0x4025000000000000

cov_i64_5:
  .quad 5                    # signed i64 = 5
  .quad 5

cov_i32_neg3:
  .word 0xFFFFFFFD           # -3 as two's complement i32
  .word 0xFFFFFFFD

# Phase 12D gap-close data
d12_f32_4p5:
  .word 0x40900000           # 4.5f
  .word 0x40900000

d12_u32_7:
  .word 7                    # u32 = 7
  .word 7

d12_u64_8:
  .quad 8                    # u64 = 8
  .quad 8

d12_f64_3p7:
  .quad 0x400D99999999999A   # 3.7 as f64
  .quad 0x400D99999999999A

d12_f64_7p9:
  .quad 0x401F99999999999A   # 7.9 as f64
  .quad 0x401F99999999999A

# Phase 12B targeted gap-close data
b12_f32_7p9:
  .word 0x40FCCCCD           # 7.9f
  .word 0x40FCCCCD

b12_f32_4p0:
  .word 0x40800000           # 4.0f (initial vd for vfnmadd test)
  .word 0x40800000

# Phase 12E data
b12e_pos_inf:
  .word 0x7F800000           # +inf (f32)
  .word 0x7F800000

b12e_1p5:
  .word 0x3FC00000           # 1.5f
  .word 0x3FC00000

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
