# Copyright (c) Qualcomm Technologies, Inc. and/or its subsidiaries.
# SPDX-License-Identifier: BSD-3-Clause-Clear

#*****************************************************************************
# vred_perm.S — Phase 8: reductions + permutations
#
# Test 1:  vredsum.vs — sum [1,2,3,4] + acc=0x10 = 0x1A; lbu=0x1A
# Test 2:  vredminu.vs — min_u([0xFF,0x01,0x02,0x03], acc=0x04) = 0x01; lbu=0x01
# Test 3:  vredmin.vs signed — min_s([0xFE(-2),0x01], acc=0x00) = -2=0xFE; lb=0xFE
# Test 4:  vwredsumu.vs — sum_u [0xFF+0x01] widen to 16-bit + acc=0x0000 = 0x0100; lhu=0x0100
# Test 5:  vslideup.vx — shift [1,2,3,4] up by 1: [?,1,2,3] (elem0 undisturbed=0); lbu byte1=1
# Test 6:  vslidedown.vx — shift [1,2,3,4] down by 1: [2,3,4,0]; lbu byte3=0 (out of bounds)
# Test 7:  vslide1up.vx — scalar x5=0x55 at elem0, others shift: [0x55,1,2,3]; lbu byte0=0x55
# Test 8:  vslide1down.vx — scalar x5=0x55 at last elem: [2,3,4,0x55]; lbu byte3=0x55
# Test 9:  vrgather.vi imm=2 — gather elem2 of vs2=[1,2,3,4] → all 4 = 3; lbu=3
# Test 10: vrgather.vv — indices=[3,2,1,0], src=[10,20,30,40]: [40,30,20,10]; lbu byte0=40
# Test 11: vcompress.vm — mask=0b1010, src=[1,2,3,4] → compact: [2,4,?,?]; lbu byte1=4
# Test 12: vredsum LMUL=8 — prove group-crossing works (vl=20 at LMUL=8)

#include "riscv_test.h"
#include "test_macros.h"

RVTEST_RV64UV
RVTEST_CODE_BEGIN

  TEST_CASE(1, x2, 0x1A, \
    li x6,4; vsetvli x7,x6,e8,m1; la x5,src4; vle8.v v2,(x5); \
    la x5,acc10; vle8.v v1,(x5); \
    vredsum.vs v4,v2,v1; la x5,result; vse8.v v4,(x5); lbu x2,(x5); )

  TEST_CASE(2, x2, 0x01, \
    li x6,4; vsetvli x7,x6,e8,m1; la x5,srcff; vle8.v v2,(x5); \
    la x5,acc04; vle8.v v1,(x5); \
    vredminu.vs v4,v2,v1; la x5,result; vse8.v v4,(x5); lbu x2,(x5); )

  # Test 3: vredmin.vs signed — [0xFE=-2,0x01], acc=0
  TEST_CASE(3, x2, 0xFFFFFFFFFFFFFFFE, \
    li x6,2; vsetvli x7,x6,e8,m1; la x5,srcfe; vle8.v v2,(x5); \
    la x5,acc00; vle8.v v1,(x5); \
    vredmin.vs v4,v2,v1; la x5,result; vse8.v v4,(x5); lb x2,(x5); )

  # Test 4: vwredsumu — [0xFF,0x01] widened to 16-bit, summed + acc=0
  TEST_CASE(4, x2, 0x0100, \
    li x6,2; vsetvli x7,x6,e8,m1; la x5,srcffo; vle8.v v2,(x5); \
    la x5,acc00_16; vle8.v v1,(x5); \
    vwredsumu.vs v4,v2,v1; \
    li x6,2; vsetvli x7,x6,e16,m1; la x5,result; vse16.v v4,(x5); lhu x2,(x5); )

  # Test 5: vslideup.vx offset=1 — pre-fill vd with zeros, src=[1,2,3,4]
  # elem0 stays 0 (undisturbed below offset), elem1=src[0]=1
  TEST_CASE(5, x2, 1, \
    li x6,4; vsetvli x7,x6,e8,m1; la x5,zeros; vle8.v v4,(x5); \
    la x5,src4; vle8.v v2,(x5); \
    li x5,1; vslideup.vx v4,v2,x5; \
    la x5,result; vse8.v v4,(x5); lbu x2,1(x5); )

  # Test 6: vslidedown.vx offset=1 — src=[1,2,3,4], result=[2,3,4,0]; byte3=0
  TEST_CASE(6, x2, 0, \
    li x6,4; vsetvli x7,x6,e8,m1; la x5,src4; vle8.v v2,(x5); \
    li x5,1; vslidedown.vx v4,v2,x5; \
    la x5,result; vse8.v v4,(x5); lbu x2,3(x5); )

  # Test 7: vslide1up.vx x5=0x55, src=[1,2,3,4]: result=[0x55,1,2,3]; byte0=0x55
  TEST_CASE(7, x2, 0x55, \
    li x6,4; vsetvli x7,x6,e8,m1; la x5,src4; vle8.v v2,(x5); \
    li x5,0x55; vslide1up.vx v4,v2,x5; \
    la x5,result; vse8.v v4,(x5); lbu x2,(x5); )

  # Test 8: vslide1down.vx x5=0x55, src=[1,2,3,4]: result=[2,3,4,0x55]; byte3=0x55
  TEST_CASE(8, x2, 0x55, \
    li x6,4; vsetvli x7,x6,e8,m1; la x5,src4; vle8.v v2,(x5); \
    li x5,0x55; vslide1down.vx v4,v2,x5; \
    la x5,result; vse8.v v4,(x5); lbu x2,3(x5); )

  # Test 9: vrgather.vi imm=2 — gather elem2 of src=[1,2,3,4]=3; all 4 elems = 3
  TEST_CASE(9, x2, 3, \
    li x6,4; vsetvli x7,x6,e8,m1; la x5,src4; vle8.v v2,(x5); \
    vrgather.vi v4,v2,2; la x5,result; vse8.v v4,(x5); lbu x2,(x5); )

  # Test 10: vrgather.vv — indices=[3,2,1,0], src=[10,20,30,40] → [40,30,20,10]
  TEST_CASE(10, x2, 40, \
    li x6,4; vsetvli x7,x6,e8,m1; la x5,src10; vle8.v v2,(x5); \
    la x5,idx3210; vle8.v v3,(x5); \
    vrgather.vv v4,v2,v3; la x5,result; vse8.v v4,(x5); lbu x2,(x5); )

  # Test 11: vcompress.vm — mask=0b1010 (bits 1,3 set), src=[1,2,3,4] → compact [2,4,?,?]
  # byte1 of result = 4 (second compacted element)
  TEST_CASE(11, x2, 4, \
    li x6,4; vsetvli x7,x6,e8,m1; la x5,mask1010; vle8.v v1,(x5); \
    la x5,src4; vle8.v v2,(x5); \
    vcompress.vm v4,v2,v1; la x5,result; vse8.v v4,(x5); lbu x2,1(x5); )

  # Test 12: vredsum LMUL=8 group-crossing — sum [1..20] + acc=0
  # Sum = 1+2+...+20 = 210 = 0xD2; lbu=0xD2
  TEST_CASE(12, x2, 0xD2, \
    li x6,20; vsetvli x7,x6,e8,m8; la x5,src20; vle8.v v8,(x5); \
    la x5,acc00; vle8.v v1,(x5); \
    vredsum.vs v24,v8,v1; \
    li x6,4; vsetvli x7,x6,e8,m1; la x5,result; vse8.v v24,(x5); lbu x2,(x5); )

  # Test 13: vredand.vs — [0x0F & 0x33 & 0xFF & 0xAA] & acc=0xFF = 0x0F&0x33=0x03&0xFF=0x03&0xAA=0x02
  TEST_CASE(13, x2, 0x02, \
    li x6,4; vsetvli x7,x6,e8,m1; la x5,srcand; vle8.v v2,(x5); \
    la x5,accff; vle8.v v1,(x5); \
    vredand.vs v4,v2,v1; la x5,result; vse8.v v4,(x5); lbu x2,(x5); )

  # Test 14: vredmax.vs signed — max([0xFE=-2, 0x03], acc=0x00) = 3; lbu=3
  TEST_CASE(14, x2, 3, \
    li x6,2; vsetvli x7,x6,e8,m1; la x5,srcfe; vle8.v v2,(x5); \
    la x5,acc00; vle8.v v1,(x5); \
    vredmax.vs v4,v2,v1; la x5,result; vse8.v v4,(x5); lbu x2,(x5); )

  # Test 15: vredmaxu.vs unsigned — max_u([0xFE=254, 0x03], acc=0x00) = 254=0xFE; lbu=0xFE
  TEST_CASE(15, x2, 0xFE, \
    li x6,2; vsetvli x7,x6,e8,m1; la x5,srcfe; vle8.v v2,(x5); \
    la x5,acc00; vle8.v v1,(x5); \
    vredmaxu.vs v4,v2,v1; la x5,result; vse8.v v4,(x5); lbu x2,(x5); )

  # Test 16: vrgather.vx scalar index — idx x5=1, src=[10,20,30,40]: all → 20; lbu=20
  TEST_CASE(16, x2, 20, \
    li x6,4; vsetvli x7,x6,e8,m1; la x5,src10; vle8.v v2,(x5); \
    li x5,1; vrgather.vx v4,v2,x5; la x5,result; vse8.v v4,(x5); lbu x2,(x5); )

  # Test 17: vslideup.vi imm=2 — src=[1,2,3,4], pre-fill vd=0, result=[0,0,1,2]; byte2=1
  TEST_CASE(17, x2, 1, \
    li x6,4; vsetvli x7,x6,e8,m1; la x5,zeros; vle8.v v4,(x5); \
    la x5,src4; vle8.v v2,(x5); \
    vslideup.vi v4,v2,2; la x5,result; vse8.v v4,(x5); lbu x2,2(x5); )

  # Test 18: vslidedown.vi imm=1 — src=[1,2,3,4]: result=[2,3,4,0]; byte3=0
  TEST_CASE(18, x2, 0, \
    li x6,4; vsetvli x7,x6,e8,m1; la x5,src4; vle8.v v2,(x5); \
    vslidedown.vi v4,v2,1; la x5,result; vse8.v v4,(x5); lbu x2,3(x5); )

  # Test 19: vrgather out-of-bounds — index=10 >= VLMAX=16(SEW=8,LMUL=1) but fine;
  # Use index=16 which equals VLMAX → should give 0; lbu=0
  TEST_CASE(19, x2, 0, \
    li x6,4; vsetvli x7,x6,e8,m1; la x5,src4; vle8.v v2,(x5); \
    li x5,16; vrgather.vx v4,v2,x5; la x5,result; vse8.v v4,(x5); lbu x2,(x5); )

  # Test 20: vcompress all-ones mask — mask=0xFF, all elements active → compact=copy
  # src=[1,2,3,4], mask all set: result=[1,2,3,4]; byte0=1, byte3=4
  TEST_CASE(20, x2, 4, \
    li x6,4; vsetvli x7,x6,e8,m1; la x5,maskff; vle8.v v1,(x5); \
    la x5,src4; vle8.v v2,(x5); \
    vcompress.vm v4,v2,v1; la x5,result; vse8.v v4,(x5); lbu x2,3(x5); )

  TEST_PASSFAIL

RVTEST_CODE_END

.data
  .balign 8
src4:    .byte 0x01, 0x02, 0x03, 0x04
src10:   .byte 10, 20, 30, 40
srcff:   .byte 0xFF, 0x01, 0x02, 0x03
srcfe:   .byte 0xFE, 0x03
srcffo:  .byte 0xFF, 0x01
srcand:  .byte 0x0F, 0x33, 0xFF, 0xAA
acc10:   .byte 0x10, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
acc04:   .byte 0x04, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
acc00:   .byte 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
acc00_16:.short 0x0000, 0x0000, 0x0000, 0x0000
accff:   .byte 0xFF, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
idx3210: .byte 3, 2, 1, 0
mask1010:.byte 0x0A, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
maskff:  .byte 0xFF, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
zeros:   .fill 8, 1, 0x00
src20:   .byte 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20

RVTEST_DATA_BEGIN
  .balign 8
result: .fill 32, 1, 0x00
RVTEST_DATA_END
