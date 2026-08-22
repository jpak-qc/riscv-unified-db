// Copyright (c) Qualcomm Technologies, Inc. and/or its subsidiaries.
// SPDX-License-Identifier: BSD-3-Clause-Clear

//*****************************************************************************
// vff_vm.S
//
// Regression for fault-only-first loads through Sv39 translation. A single
// virtual page is mapped at VM_DATA_VA; the next page is deliberately unmapped.
// vle8ff.v starts two bytes before the page boundary, so elements 0 and 1 must
// load and the page fault on element 2 must trim vl to 2 without entering the
// architectural trap handler.

#include "riscv_test.h"
#include "test_macros.h"

#define VM_DATA_VA 0x40000000

// Keep execution in M-mode after reset. The test uses MPRV with MPP=S so only
// the vector data accesses use Sv39 translation; instruction fetch stays bare.
#undef EXTRA_INIT
#define EXTRA_INIT \
  li t0, MSTATUS_MPP; \
  csrrs zero, mstatus, t0;

#define MPRV_S_ON \
  li t3, MSTATUS_MPP; \
  csrrc zero, mstatus, t3; \
  li t3, ((MSTATUS_MPP & ~(MSTATUS_MPP << 1)) * PRV_S) | MSTATUS_MPRV; \
  csrrs zero, mstatus, t3

#define MPRV_OFF \
  li t3, MSTATUS_MPRV; \
  csrrc zero, mstatus, t3

RVTEST_RV64UV
RVTEST_CODE_BEGIN

  jal ra, setup_sv39

  TEST_CASE(1, x2, 2, \
    li x6, 4; \
    vsetvli x7, x6, e8, m1; \
    li x5, VM_DATA_VA + 4094; \
    MPRV_S_ON; \
    vle8ff.v v2, (x5); \
    MPRV_OFF; \
    csrr x2, vl; )

  TEST_PASSFAIL

// Build a three-level Sv39 page table for VM_DATA_VA. Only its first 4 KiB
// page is mapped, making VM_DATA_VA + 4096 a load page fault.
setup_sv39:
  la t0, vm_data
  srli t0, t0, 12
  slli t0, t0, PTE_PPN_SHIFT
  li t1, PTE_V | PTE_R | PTE_W | PTE_A | PTE_D
  or t0, t0, t1
  la t1, vm_l0
  sd t0, 0(t1)

  la t0, vm_l0
  srli t0, t0, 12
  slli t0, t0, PTE_PPN_SHIFT
  ori t0, t0, PTE_V
  la t1, vm_l1
  sd t0, 0(t1)

  la t0, vm_l1
  srli t0, t0, 12
  slli t0, t0, PTE_PPN_SHIFT
  ori t0, t0, PTE_V
  la t1, vm_root
  sd t0, 8(t1)

  la t0, vm_root
  srli t0, t0, 12
  li t1, (SATP_MODE & ~(SATP_MODE << 1)) * SATP_MODE_SV39
  or t0, t0, t1
  csrw satp, t0
  sfence.vma
  ret

RVTEST_CODE_END

RVTEST_DATA_BEGIN
  .balign 4096
vm_root: .fill 512, 8, 0
  .balign 4096
vm_l1: .fill 512, 8, 0
  .balign 4096
vm_l0: .fill 512, 8, 0
  .balign 4096
vm_data: .fill 4096, 1, 0xAB
RVTEST_DATA_END
