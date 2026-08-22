// Copyright (c) Qualcomm Technologies, Inc. and/or its subsidiaries.
// SPDX-License-Identifier: BSD-3-Clause-Clear

// Tests for register file storage and accessor generation (Layer 4a–4c).

#include <catch2/catch_test_macros.hpp>
#include <udb/hart_factory.hxx>
#include <udb/iss_soc_model.hpp>
#include <udb/stop_reason.h>

#include <deque>
#include <stdexcept>

// Use the rv64-riscv-tests config (known-working fully-configured rv64 with F extension).
static const std::string cfg_yaml = R"(
$schema: https://riscv.org/udb/schemas/config_schema-0.1.0.json
kind: architecture configuration
type: fully configured
name: rv64-riscv-tests
description: For register file testing

implemented_extensions:
  - [Sm, "1.12.0"]
  - [Smstateen, "1.0.0"]
  - [I, "2.1"]
  - [C, "2.0"]
  - [M, "2.0"]
  - [Zicsr, "2.0"]
  - [Zkr, "1.0.0"]
  - [Zicntr, "2.0"]
  - [Smrnmi, "1.0"]
  - [S, "1.11.0"]
  - [U, "1.0.0"]
  - [Zifencei, "2.0.0"]
  - [Sv39, "1.11.0"]
  - [Zca, "1.0.0"]
  - [F, "2.2.0"]

params:
  MXLEN: 64
  CONFIG_PTR_ADDRESS: 0
  MARCHID_IMPLEMENTED: true
  ARCH_ID_VALUE: 1
  MIMPID_IMPLEMENTED: true
  IMP_ID_VALUE: 0
  VENDOR_ID_BANK: 1
  VENDOR_ID_OFFSET: 1
  MISALIGNED_LDST: true
  MISALIGNED_LDST_EXCEPTION_PRIORITY: low
  MISALIGNED_MAX_ATOMICITY_GRANULE_SIZE: 4
  MISALIGNED_SPLIT_STRATEGY: sequential_bytes
  PRECISE_SYNCHRONOUS_EXCEPTIONS: true
  TRAP_ON_ECALL_FROM_M: true
  TRAP_ON_EBREAK: true
  M_MODE_ENDIANNESS: little
  TRAP_ON_ILLEGAL_WLRL: true
  TRAP_ON_UNIMPLEMENTED_INSTRUCTION: true
  TRAP_ON_RESERVED_INSTRUCTION: true
  TRAP_ON_UNIMPLEMENTED_CSR: true
  REPORT_VA_IN_MTVAL_ON_BREAKPOINT: true
  REPORT_VA_IN_MTVAL_ON_LOAD_MISALIGNED: true
  REPORT_VA_IN_MTVAL_ON_STORE_AMO_MISALIGNED: true
  REPORT_VA_IN_MTVAL_ON_INSTRUCTION_MISALIGNED: true
  REPORT_VA_IN_MTVAL_ON_LOAD_ACCESS_FAULT: true
  REPORT_VA_IN_MTVAL_ON_STORE_AMO_ACCESS_FAULT: true
  REPORT_VA_IN_MTVAL_ON_INSTRUCTION_ACCESS_FAULT: true
  REPORT_ENCODING_IN_MTVAL_ON_ILLEGAL_INSTRUCTION: true
  MTVAL_WIDTH: 32
  PMA_GRANULARITY: 12
  PHYS_ADDR_WIDTH: 57
  MISA_CSR_IMPLEMENTED: true
  MTVEC_ACCESS: rw
  MTVEC_MODES: [0, 1]
  MTVEC_BASE_ALIGNMENT_DIRECT: 0x4
  MTVEC_BASE_ALIGNMENT_VECTORED: 0x4
  MTVEC_ILLEGAL_WRITE_BEHAVIOR: retain
  MUTABLE_MISA_C: false
  MUTABLE_MISA_M: false
  TIME_CSR_IMPLEMENTED: false
  MUTABLE_MISA_S: false
  ASID_WIDTH: 5
  S_MODE_ENDIANNESS: little
  SXLEN: [64]
  REPORT_VA_IN_MTVAL_ON_LOAD_PAGE_FAULT: true
  REPORT_VA_IN_MTVAL_ON_STORE_AMO_PAGE_FAULT: true
  REPORT_VA_IN_MTVAL_ON_INSTRUCTION_PAGE_FAULT: true
  REPORT_VA_IN_STVAL_ON_BREAKPOINT: true
  REPORT_VA_IN_STVAL_ON_LOAD_MISALIGNED: true
  REPORT_VA_IN_STVAL_ON_STORE_AMO_MISALIGNED: true
  REPORT_VA_IN_STVAL_ON_INSTRUCTION_MISALIGNED: true
  REPORT_VA_IN_STVAL_ON_LOAD_ACCESS_FAULT: true
  REPORT_VA_IN_STVAL_ON_STORE_AMO_ACCESS_FAULT: true
  REPORT_VA_IN_STVAL_ON_INSTRUCTION_ACCESS_FAULT: true
  REPORT_VA_IN_STVAL_ON_LOAD_PAGE_FAULT: true
  REPORT_VA_IN_STVAL_ON_STORE_AMO_PAGE_FAULT: true
  REPORT_VA_IN_STVAL_ON_INSTRUCTION_PAGE_FAULT: true
  REPORT_ENCODING_IN_STVAL_ON_ILLEGAL_INSTRUCTION: true
  STVAL_WIDTH: 32
  MCOUNTENABLE_EN: [false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false]
  SCOUNTENABLE_EN: [false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false]
  COUNTINHIBIT_EN: [false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false]
  STVEC_MODES: [0, 1]
  STVEC_BASE_ALIGNMENT_VECTORED: 0x4
  SATP_MODE_BARE: true
  TRAP_ON_ECALL_FROM_S: true
  TRAP_ON_ECALL_FROM_U: true
  MSTATUS_VS_LEGAL_VALUES: [0]
  MSTATUS_FS_LEGAL_VALUES: [3, 2, 1, 0]
  NUM_PMP_ENTRIES: 16
  NUM_USABLE_PMP_ENTRIES: 16
  PMP_TOR_SUPPORTED: true
  PMP_NA4_SUPPORTED: false
  PMP_NAPOT_SUPPORTED: true
  PMP_GRANULARITY: 12
  MUTABLE_MISA_U: false
  U_MODE_ENDIANNESS: little
  UXLEN: [64]
  MSTATEEN_ENVCFG_TYPE: rw
  HW_MSTATUS_FS_DIRTY_UPDATE: precise
  MUTABLE_MISA_F: false
  HPM_COUNTER_EN: [false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false]
  MCOUNTINHIBIT_IMPLEMENTED: true
)";

namespace {

class ScriptedEntropySocModel : public udb::IssSocModel {
 public:
  ScriptedEntropySocModel(uint64_t size, uint64_t base_addr)
      : IssSocModel(size, base_addr) {}

  udb::UdbEntropySourceSample poll_entropy_source() override {
    ++poll_count;
    if (samples.empty()) {
      return {0b01, 0, 0};
    }

    const udb::UdbEntropySourceSample sample = samples.front();
    samples.pop_front();
    return sample;
  }

  std::deque<udb::UdbEntropySourceSample> samples;
  unsigned poll_count = 0;
};

uint32_t csr_instruction(uint16_t csr, uint8_t funct3, uint8_t rd,
                         uint8_t rs1_or_uimm) {
  return (static_cast<uint32_t>(csr) << 20) |
         (static_cast<uint32_t>(rs1_or_uimm) << 15) |
         (static_cast<uint32_t>(funct3) << 12) |
         (static_cast<uint32_t>(rd) << 7) | 0x73;
}

udb::HartBase<udb::IssSocModel>* create_seed_hart(
    ScriptedEntropySocModel& soc) {
  return udb::HartFactory::create("rv64", 0, cfg_yaml,
                                  static_cast<udb::IssSocModel&>(soc));
}

void execute_one(udb::HartBase<udb::IssSocModel>* hart,
                 ScriptedEntropySocModel& soc, uint32_t instruction) {
  hart->reset(0);
  soc.write_physical_memory_32(0, instruction);
  REQUIRE(hart->run_one() == StopReason::InstLimitReached);
}

int execute_at_current_mode(udb::HartBase<udb::IssSocModel>* hart,
                            ScriptedEntropySocModel& soc,
                            uint32_t instruction) {
  hart->set_pc(0);
  soc.write_physical_memory_32(0, instruction);
  return hart->run_one();
}

}  // namespace

TEST_CASE("seed polls the platform entropy source", "[seed]") {
  ScriptedEntropySocModel soc(1024 * 1024, 0);
  soc.samples.push_back({0b10, 0xa5, 0xbeef});
  soc.samples.push_back({0b01, 0x5a, 0xdead});
  auto* hart = create_seed_hart(soc);

  execute_one(hart, soc, csr_instruction(0x015, 0b001, 5, 0));
  REQUIRE(hart->xreg(5) == 0x80a5beef);
  REQUIRE(soc.poll_count == 1);

  execute_one(hart, soc, csr_instruction(0x015, 0b001, 6, 0));
  REQUIRE(hart->xreg(6) == 0x405a0000);
  REQUIRE(soc.poll_count == 2);

  delete hart;
}

TEST_CASE("seed write-only access polls and discards", "[seed]") {
  ScriptedEntropySocModel soc(1024 * 1024, 0);
  soc.samples.push_back({0b10, 0, 0x1234});
  auto* hart = create_seed_hart(soc);

  execute_one(hart, soc, csr_instruction(0x015, 0b001, 0, 0));
  REQUIRE(soc.poll_count == 1);
  REQUIRE(soc.samples.empty());

  delete hart;
}

TEST_CASE("seed rejects read-only CSR forms", "[seed]") {
  ScriptedEntropySocModel soc(1024 * 1024, 0);
  auto* hart = create_seed_hart(soc);

  hart->reset(0);
  soc.write_physical_memory_32(0, csr_instruction(0x015, 0b010, 5, 0));
  REQUIRE(hart->run_one() == StopReason::Exception);
  REQUIRE(soc.poll_count == 0);

  delete hart;
}

TEST_CASE("seed enforces lower-privilege access controls", "[seed]") {
  ScriptedEntropySocModel soc(1024 * 1024, 0);
  soc.samples.push_back({0b10, 0, 0x1234});
  soc.samples.push_back({0b10, 0, 0x5678});
  auto* hart = create_seed_hart(soc);

  hart->reset(0);
  hart->_set_mode(udb::PrivilegeMode::U);
  REQUIRE(execute_at_current_mode(hart, soc, csr_instruction(0x015, 0b001, 5,
                                                               0)) ==
          StopReason::Exception);
  REQUIRE(soc.poll_count == 0);

  hart->reset(0);
  hart->set_xreg(1, 0x300);
  REQUIRE(execute_at_current_mode(hart, soc, csr_instruction(0x747, 0b001, 0,
                                                               1)) ==
          StopReason::InstLimitReached);
  REQUIRE(soc.poll_count == 0);

  hart->_set_mode(udb::PrivilegeMode::U);
  REQUIRE(execute_at_current_mode(hart, soc, csr_instruction(0x015, 0b001, 5,
                                                               0)) ==
          StopReason::InstLimitReached);
  REQUIRE(soc.poll_count == 1);

  hart->_set_mode(udb::PrivilegeMode::S);
  REQUIRE(execute_at_current_mode(hart, soc, csr_instruction(0x015, 0b001, 6,
                                                               0)) ==
          StopReason::InstLimitReached);
  REQUIRE(soc.poll_count == 2);

  delete hart;
}

// ---------------------------------------------------------------------------
// X register file tests (Layer 4a–4c)
// ---------------------------------------------------------------------------

TEST_CASE("X register storage has 32 entries", "[regfile]") {
  udb::IssSocModel soc(1024 * 1024, 0);
  auto* hart = udb::HartFactory::create("rv64", 0, cfg_yaml, soc);
  // Write a known value to x31, verify it round-trips; index 32 throws.
  REQUIRE_NOTHROW(hart->set_xreg(31, 42));
  REQUIRE(hart->xreg(31) == 42);
  REQUIRE_THROWS_AS(hart->xreg(32), std::out_of_range);
  delete hart;
}

TEST_CASE("x0 is zero after reset", "[regfile]") {
  udb::IssSocModel soc(1024 * 1024, 0);
  auto* hart = udb::HartFactory::create("rv64", 0, cfg_yaml, soc);
  REQUIRE(hart->xreg(0) == 0);
  delete hart;
}

TEST_CASE("writing to x0 leaves it zero (arch_write)", "[regfile]") {
  udb::IssSocModel soc(1024 * 1024, 0);
  auto* hart = udb::HartFactory::create("rv64", 0, cfg_yaml, soc);
  hart->set_xreg(0, 42);
  REQUIRE(hart->xreg(0) == 0);
  delete hart;
}

TEST_CASE("xreg throws out_of_range for index >= 32", "[regfile]") {
  udb::IssSocModel soc(1024 * 1024, 0);
  auto* hart = udb::HartFactory::create("rv64", 0, cfg_yaml, soc);
  REQUIRE_THROWS_AS(hart->set_xreg(32, 0), std::out_of_range);
  delete hart;
}

// ---------------------------------------------------------------------------
// F register file tests (Layer 4d: hart.hpp adds virtual freg() to HartBase)
// ---------------------------------------------------------------------------

TEST_CASE("F register storage has 32 entries", "[regfile]") {
  udb::IssSocModel soc(1024 * 1024, 0);
  auto* hart = udb::HartFactory::create("rv64", 0, cfg_yaml, soc);
  REQUIRE_NOTHROW(hart->set_freg(31, 0xdeadbeef));
  REQUIRE(hart->freg(31) == 0xdeadbeef);
  REQUIRE_THROWS_AS(hart->freg(32), std::out_of_range);
  delete hart;
}

TEST_CASE("freg round-trips a written value", "[regfile]") {
  udb::IssSocModel soc(1024 * 1024, 0);
  auto* hart = udb::HartFactory::create("rv64", 0, cfg_yaml, soc);
  hart->set_freg(0, 0x3f800000);
  REQUIRE(hart->freg(0) == 0x3f800000);
  delete hart;
}

TEST_CASE("freg throws out_of_range for index >= 32", "[regfile]") {
  udb::IssSocModel soc(1024 * 1024, 0);
  auto* hart = udb::HartFactory::create("rv64", 0, cfg_yaml, soc);
  REQUIRE_THROWS_AS(hart->set_freg(32, 0), std::out_of_range);
  delete hart;
}
