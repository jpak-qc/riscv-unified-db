# Copyright (c) Qualcomm Technologies, Inc. and/or its subsidiaries.
# SPDX-License-Identifier: BSD-3-Clause-Clear

#*****************************************************************************
# vmem_phase10.S — Phase 10: strided, indexed, whole-register, segment loads/stores
#
# Test 1: vlse8.v stride=2 — load every 2nd byte: [0x01,0x03,0x05,0x07]; lbu byte0=1
# Test 2: vsse8.v stride=2 — store to every 2nd byte; lbu byte2=2 (element 1 at offset 2)
# Test 3: vluxei8.v — indices=[2,0,3,1], src=[10,20,30,40] → [30,10,40,20]; lbu byte0=30
# Test 4: vl1re8.v — load 16 bytes (1 register) regardless of vl; byte8=0x09
# Test 5: vs1r.v — store 16 bytes; byte4=0x05
# Test 6: vl2re8.v LMUL=1 — load 32 bytes into v2+v3; byte16 (second reg)=0x11
# Test 7: vlseg2e8.v — NFIELDS=2: [field0_elem0,field1_elem0,field0_elem1,...]; check v4[0]=0x01
# Test 8: vlsseg2e8.v stride=4 — segment stride: [field0_e0,field1_e0 at +4]; lbu=0x01

#include "riscv_test.h"
#include "test_macros.h"

RVTEST_RV64UV
RVTEST_CODE_BEGIN

  # Test 1: vlse8.v stride=2
  TEST_CASE(1, x2, 1, \
    li x6,4; vsetvli x7,x6,e8,m1; \
    la x5,strided_src; li x4,2; vlse8.v v2,(x5),x4; \
    la x5,result; vse8.v v2,(x5); lbu x2,(x5); )

  # Test 2: vsse8.v stride=2 — store elements at even offsets
  TEST_CASE(2, x2, 2, \
    li x6,4; vsetvli x7,x6,e8,m1; \
    la x5,elems4; vle8.v v2,(x5); \
    la x5,store_buf; li x4,2; vsse8.v v2,(x5),x4; \
    lbu x2,2(x5); )

  # Test 3: vluxei8.v — indices in v3, src in memory
  TEST_CASE(3, x2, 30, \
    li x6,4; vsetvli x7,x6,e8,m1; \
    la x5,idx4; vle8.v v3,(x5); \
    la x5,src10; vluxei8.v v2,(x5),v3; \
    la x5,result; vse8.v v2,(x5); lbu x2,(x5); )

  # Test 4: vl1re8.v — loads VLEN/8=16 bytes regardless of vl; byte 8 = 0x09
  # Must use vl=16 for vse8 to store all bytes including byte 8
  TEST_CASE(4, x2, 0x09, \
    li x6,16; vsetvli x7,x6,e8,m1; \
    la x5,wb_src; vl1re8.v v2,(x5); \
    la x5,result; vse8.v v2,(x5); lbu x2,8(x5); )

  # Test 5: vs1r.v — store 16 bytes (full register), check byte 4
  TEST_CASE(5, x2, 0x05, \
    li x6,16; vsetvli x7,x6,e8,m1; la x5,wb_src; vle8.v v2,(x5); \
    la x5,result; vs1r.v v2,(x5); lbu x2,4(x5); )

  # Test 6: vl2re8.v — loads 2 registers (32 bytes); byte 16 = 0x11 (second register)
  # LMUL=2 with vl=32 to store all bytes
  TEST_CASE(6, x2, 0x11, \
    li x6,2; vsetvli x7,x6,e8,m1; \
    la x5,wb_src2; vl2re8.v v2,(x5); \
    la x5,result; \
    li x6,32; vsetvli x7,x6,e8,m2; vse8.v v2,(x5); lbu x2,16(x5); )

  # Test 7: vlseg2e8.v NFIELDS=2 — interleaved [f0_e0, f1_e0, f0_e1, f1_e1, ...]
  # field0 → v2, field1 → v3; check v2 element0 = first byte = 0x01
  TEST_CASE(7, x2, 0x01, \
    li x6,2; vsetvli x7,x6,e8,m1; \
    la x5,seg2_src; vlseg2e8.v v2,(x5); \
    la x5,result; vse8.v v2,(x5); lbu x2,(x5); )

  # Test 8: vlsseg2e8.v strided NFIELDS=2, stride=4
  # Seg0: base+0=0x01(f0), base+1=0x02(f1); Seg1: base+4=0x05(f0), base+5=0x06(f1)
  # field0 elem0 = 0x01
  TEST_CASE(8, x2, 0x01, \
    li x6,2; vsetvli x7,x6,e8,m1; \
    la x5,seg2_src; li x4,4; vlsseg2e8.v v2,(x5),x4; \
    la x5,result; vse8.v v2,(x5); lbu x2,(x5); )

  # Test 9: vsuxei8.v indexed store — scatter [1,2,3,4] to indices [0,2,4,6]
  # byte0=1, byte2=2, byte4=3, byte6=4; check byte4=3
  TEST_CASE(9, x2, 3, \
    li x6,4; vsetvli x7,x6,e8,m1; \
    la x5,scatter_idx; vle8.v v3,(x5); \
    la x5,elems4; vle8.v v2,(x5); \
    la x5,scatter_buf; vsuxei8.v v2,(x5),v3; \
    lbu x2,4(x5); )

  # Test 10: vsseg2e8.v segment store — NFIELDS=2 fields interleaved
  # Store v2=[1,2] as field0, v3=[10,20] as field1 → [1,10,2,20]; byte2=2
  TEST_CASE(10, x2, 2, \
    li x6,2; vsetvli x7,x6,e8,m1; \
    la x5,elems4; vle8.v v2,(x5); \
    la x5,field1; vle8.v v3,(x5); \
    la x5,result; vsseg2e8.v v2,(x5); \
    lbu x2,2(x5); )

  # Test 11: vlseg3e8.v NFIELDS=3 — [f0,f1,f2,f0,f1,f2,...]; check v3 elem0=0x02 (field1)
  TEST_CASE(11, x2, 0x02, \
    li x6,2; vsetvli x7,x6,e8,m1; \
    la x5,seg3_src; vlseg3e8.v v2,(x5); \
    la x5,result; vse8.v v3,(x5); lbu x2,(x5); )

  # Test 12: vlse8.v negative stride — stride=-1: loads src[0],src[-1],src[-2]
  # src_neg[2]=0x01, src_neg[1]=0x02: stride=-1 → elem0=src_neg[2]=0x01, elem1=src_neg[1]=0x02
  TEST_CASE(12, x2, 0x02, \
    li x6,2; vsetvli x7,x6,e8,m1; \
    la x5,stride_neg; addi x5,x5,2; li x4,-1; vlse8.v v2,(x5),x4; \
    la x5,result; vse8.v v2,(x5); lbu x2,1(x5); )

  # Test 13: vs8r.v — store 8 registers; load known data into v16 group via vl8re8
  # Load 128 bytes from wb_src8 into v16-v23, then store back; check byte 4=0x05
  TEST_CASE(13, x2, 0x05, \
    la x5,wb_src8; vl8re8.v v16,(x5); \
    la x5,result; vs8r.v v16,(x5); lbu x2,4(x5); )

  TEST_PASSFAIL

RVTEST_CODE_END

.data
  .balign 8
strided_src: .byte 0x01,0x00,0x03,0x00,0x05,0x00,0x07,0x00
elems4:      .byte 0x01,0x02,0x03,0x04
idx4:        .byte 2,0,3,1   # indices into src10 array
src10:       .byte 10,20,30,40,50,60,70,80
wb_src:      .byte 0x01,0x02,0x03,0x04,0x05,0x06,0x07,0x08,0x09,0x0a,0x0b,0x0c,0x0d,0x0e,0x0f,0x10
wb_src2:     .byte 0x01,0x02,0x03,0x04,0x05,0x06,0x07,0x08,0x09,0x0a,0x0b,0x0c,0x0d,0x0e,0x0f,0x10
             .byte 0x11,0x12,0x13,0x14,0x15,0x16,0x17,0x18,0x19,0x1a,0x1b,0x1c,0x1d,0x1e,0x1f,0x20
seg2_src:    .byte 0x01,0x02,0x03,0x04,0x05,0x06,0x07,0x08,0x09,0x0a,0x0b,0x0c,0x0d,0x0e,0x0f,0x10
scatter_idx: .byte 0,2,4,6
field1:      .byte 0x0A,0x14,0x1E,0x28
seg3_src:    .byte 0x01,0x02,0x03,0x04,0x05,0x06,0x07,0x08,0x09,0x0a,0x0b,0x0c
stride_neg:  .byte 0x03,0x02,0x01
wb_src8:     .byte 0x01,0x02,0x03,0x04,0x05,0x06,0x07,0x08,0x09,0x0a,0x0b,0x0c,0x0d,0x0e,0x0f,0x10
             .byte 0x11,0x12,0x13,0x14,0x15,0x16,0x17,0x18,0x19,0x1a,0x1b,0x1c,0x1d,0x1e,0x1f,0x20
             .byte 0x21,0x22,0x23,0x24,0x25,0x26,0x27,0x28,0x29,0x2a,0x2b,0x2c,0x2d,0x2e,0x2f,0x30
             .byte 0x31,0x32,0x33,0x34,0x35,0x36,0x37,0x38,0x39,0x3a,0x3b,0x3c,0x3d,0x3e,0x3f,0x40
             .byte 0x41,0x42,0x43,0x44,0x45,0x46,0x47,0x48,0x49,0x4a,0x4b,0x4c,0x4d,0x4e,0x4f,0x50
             .byte 0x51,0x52,0x53,0x54,0x55,0x56,0x57,0x58,0x59,0x5a,0x5b,0x5c,0x5d,0x5e,0x5f,0x60
             .byte 0x61,0x62,0x63,0x64,0x65,0x66,0x67,0x68,0x69,0x6a,0x6b,0x6c,0x6d,0x6e,0x6f,0x70
             .byte 0x71,0x72,0x73,0x74,0x75,0x76,0x77,0x78,0x79,0x7a,0x7b,0x7c,0x7d,0x7e,0x7f,0x80

RVTEST_DATA_BEGIN
  .balign 8
scatter_buf: .fill 8, 1, 0x00
store_buf:   .fill 16, 1, 0xFF
result:      .fill 256, 1, 0x00
RVTEST_DATA_END
