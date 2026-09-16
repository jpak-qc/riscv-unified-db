// Copyright (c) Qualcomm Technologies, Inc. and/or its subsidiaries.
// SPDX-License-Identifier: BSD-3-Clause-Clear

// Tests for register file storage and accessor generation (Layer 4a–4c).

#include <catch2/catch_test_macros.hpp>
#include <udb/hart_factory.hxx>
#include <udb/iss_soc_model.hpp>
#include <udb/stop_reason.h>

#include <array>
#include <deque>
#include <filesystem>
#include <stdexcept>
#include <string_view>

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
  - [Zbkb, "1.0.0"]
  - [Zbkc, "1.0.0"]
  - [Zknd, "1.0.0"]
  - [Zkne, "1.0.0"]
  - [Zknh, "1.0.0"]
  - [Zkr, "1.0.0"]
  - [Zksh, "1.0.0"]
  - [Zksed, "1.0.0"]
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

uint32_t r_instruction(uint8_t funct7, uint8_t funct3, uint8_t rd,
                       uint8_t rs1, uint8_t rs2, uint8_t opcode = 0x33) {
  return (static_cast<uint32_t>(funct7) << 25) |
         (static_cast<uint32_t>(rs2) << 20) |
         (static_cast<uint32_t>(rs1) << 15) |
         (static_cast<uint32_t>(funct3) << 12) |
         (static_cast<uint32_t>(rd) << 7) | opcode;
}

uint32_t i_instruction(uint16_t funct12, uint8_t rd, uint8_t rs1,
                       uint8_t funct3 = 0b001) {
  return (static_cast<uint32_t>(funct12) << 20) |
         (static_cast<uint32_t>(rs1) << 15) |
         (static_cast<uint32_t>(funct3) << 12) |
         (static_cast<uint32_t>(rd) << 7) | 0x13;
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

constexpr uint64_t kInstructionAddress = 0x100;

int execute_at_current_mode(udb::HartBase<udb::IssSocModel>* hart,
                            udb::IssSocModel& soc, uint32_t instruction) {
  hart->set_pc(kInstructionAddress);
  soc.write_physical_memory_32(kInstructionAddress, instruction);
  return hart->run_one();
}

constexpr std::string_view kVectorCryptoConfig = "rv64-vector-crypto";

bool vector_crypto_config_available() {
  for (const std::string_view config : udb::HartFactory::configs()) {
    if (config == kVectorCryptoConfig) {
      return true;
    }
  }
  return false;
}

udb::HartBase<udb::IssSocModel>* create_vector_crypto_hart(
    udb::IssSocModel& soc) {
  const std::filesystem::path cfg_path =
      std::filesystem::path(UDB_ROOT_PATH) / "cfgs" /
      "rv64-vector-crypto.yaml";
  return udb::HartFactory::create(std::string(kVectorCryptoConfig), 0,
                                  cfg_path, soc);
}

uint32_t vector_setivli_instruction(uint8_t rd, uint8_t avl,
                                    uint16_t vtypei) {
  return (0b11u << 30) | (static_cast<uint32_t>(vtypei) << 20) |
         (static_cast<uint32_t>(avl) << 15) |
         (0b111u << 12) | (static_cast<uint32_t>(rd) << 7) | 0x57;
}

uint32_t vector_r_instruction(uint8_t funct6, uint8_t vd, uint8_t vs2,
                              uint8_t vs1, uint8_t funct3 = 0b010,
                              uint8_t opcode = 0x57) {
  return (static_cast<uint32_t>(funct6) << 26) | (1u << 25) |
         (static_cast<uint32_t>(vs2) << 20) |
         (static_cast<uint32_t>(vs1) << 15) |
         (static_cast<uint32_t>(funct3) << 12) |
         (static_cast<uint32_t>(vd) << 7) | opcode;
}

uint32_t vector_crypto_instruction(uint8_t funct6, uint8_t vd, uint8_t vs2,
                                   uint8_t vs1, uint8_t funct3 = 0b010) {
  return vector_r_instruction(funct6, vd, vs2, vs1, funct3, 0x77);
}

uint32_t vector_load_instruction(uint8_t vd, uint8_t rs1, uint8_t funct3) {
  return (1u << 25) | (static_cast<uint32_t>(rs1) << 15) |
         (static_cast<uint32_t>(funct3) << 12) |
         (static_cast<uint32_t>(vd) << 7) | 0x07;
}

uint32_t vector_store_instruction(uint8_t vs3, uint8_t rs1, uint8_t funct3) {
  return (1u << 25) | (static_cast<uint32_t>(rs1) << 15) |
         (static_cast<uint32_t>(funct3) << 12) |
         (static_cast<uint32_t>(vs3) << 7) | 0x27;
}

void enable_vector_state(udb::HartBase<udb::IssSocModel>* hart,
                         udb::IssSocModel& soc) {
  hart->set_xreg(1, 0x600);
  REQUIRE(execute_at_current_mode(hart, soc,
                                  csr_instruction(0x300, 0b010, 0, 1)) ==
          StopReason::InstLimitReached);
}

void configure_vector(udb::HartBase<udb::IssSocModel>* hart,
                      udb::IssSocModel& soc, uint8_t vl, uint16_t vtypei) {
  REQUIRE(execute_at_current_mode(
              hart, soc, vector_setivli_instruction(0, vl, vtypei)) ==
          StopReason::InstLimitReached);
}

uint64_t read_csr(udb::HartBase<udb::IssSocModel>* hart,
                  udb::IssSocModel& soc, uint16_t csr) {
  REQUIRE(execute_at_current_mode(hart, soc,
                                  csr_instruction(csr, 0b010, 2, 0)) ==
          StopReason::InstLimitReached);
  return hart->xreg(2);
}

void write_words(udb::IssSocModel& soc, uint64_t address,
                 const std::array<uint32_t, 4>& words) {
  for (size_t index = 0; index < words.size(); ++index) {
    soc.write_physical_memory_32(address + index * sizeof(uint32_t),
                                 words[index]);
  }
}

std::array<uint32_t, 4> read_words(udb::IssSocModel& soc, uint64_t address) {
  std::array<uint32_t, 4> words{};
  for (size_t index = 0; index < words.size(); ++index) {
    words[index] = soc.read_physical_memory_32(
        address + index * sizeof(uint32_t));
  }
  return words;
}

void load_vector32(udb::HartBase<udb::IssSocModel>* hart,
                   udb::IssSocModel& soc, uint8_t vd, uint64_t address,
                   const std::array<uint32_t, 4>& words) {
  write_words(soc, address, words);
  hart->set_xreg(1, address);
  REQUIRE(execute_at_current_mode(hart, soc,
                                  vector_load_instruction(vd, 1, 0b110)) ==
          StopReason::InstLimitReached);
}

void store_vector32(udb::HartBase<udb::IssSocModel>* hart,
                    udb::IssSocModel& soc, uint8_t vs3, uint64_t address) {
  hart->set_xreg(1, address);
  REQUIRE(execute_at_current_mode(hart, soc,
                                  vector_store_instruction(vs3, 1, 0b110)) ==
          StopReason::InstLimitReached);
}

void write_doublewords(udb::IssSocModel& soc, uint64_t address,
                       const std::array<uint64_t, 2>& values) {
  for (size_t index = 0; index < values.size(); ++index) {
    soc.write_physical_memory_32(address + index * sizeof(uint64_t),
                                 values[index]);
    soc.write_physical_memory_32(address + index * sizeof(uint64_t) + 4,
                                 values[index] >> 32);
  }
}

std::array<uint64_t, 2> read_doublewords(udb::IssSocModel& soc,
                                         uint64_t address) {
  std::array<uint64_t, 2> values{};
  for (size_t index = 0; index < values.size(); ++index) {
    const uint64_t low =
        soc.read_physical_memory_32(address + index * sizeof(uint64_t));
    const uint64_t high = soc.read_physical_memory_32(
        address + index * sizeof(uint64_t) + 4);
    values[index] = low | (high << 32);
  }
  return values;
}

void load_vector64(udb::HartBase<udb::IssSocModel>* hart,
                   udb::IssSocModel& soc, uint8_t vd, uint64_t address,
                   const std::array<uint64_t, 2>& values) {
  write_doublewords(soc, address, values);
  hart->set_xreg(1, address);
  REQUIRE(execute_at_current_mode(hart, soc,
                                  vector_load_instruction(vd, 1, 0b111)) ==
          StopReason::InstLimitReached);
}

void store_vector64(udb::HartBase<udb::IssSocModel>* hart,
                    udb::IssSocModel& soc, uint8_t vs3, uint64_t address) {
  hart->set_xreg(1, address);
  REQUIRE(execute_at_current_mode(hart, soc,
                                  vector_store_instruction(vs3, 1, 0b111)) ==
          StopReason::InstLimitReached);
}

void load_vector32x8(udb::HartBase<udb::IssSocModel>* hart,
                     udb::IssSocModel& soc, uint8_t vd, uint64_t address,
                     const std::array<uint32_t, 8>& words) {
  for (size_t index = 0; index < words.size(); ++index) {
    soc.write_physical_memory_32(address + index * sizeof(uint32_t),
                                 words[index]);
  }
  hart->set_xreg(1, address);
  REQUIRE(execute_at_current_mode(hart, soc,
                                  vector_load_instruction(vd, 1, 0b110)) ==
          StopReason::InstLimitReached);
}

std::array<uint32_t, 8> read_words8(udb::IssSocModel& soc, uint64_t address) {
  std::array<uint32_t, 8> words{};
  for (size_t index = 0; index < words.size(); ++index) {
    words[index] = soc.read_physical_memory_32(
        address + index * sizeof(uint32_t));
  }
  return words;
}

void store_vector32x8(udb::HartBase<udb::IssSocModel>* hart,
                      udb::IssSocModel& soc, uint8_t vs3, uint64_t address) {
  hart->set_xreg(1, address);
  REQUIRE(execute_at_current_mode(hart, soc,
                                  vector_store_instruction(vs3, 1, 0b110)) ==
          StopReason::InstLimitReached);
}

void load_vector64x4(udb::HartBase<udb::IssSocModel>* hart,
                     udb::IssSocModel& soc, uint8_t vd, uint64_t address,
                     const std::array<uint64_t, 4>& values) {
  for (size_t index = 0; index < values.size(); ++index) {
    soc.write_physical_memory_32(address + index * sizeof(uint64_t),
                                 values[index]);
    soc.write_physical_memory_32(address + index * sizeof(uint64_t) + 4,
                                 values[index] >> 32);
  }
  hart->set_xreg(1, address);
  REQUIRE(execute_at_current_mode(hart, soc,
                                  vector_load_instruction(vd, 1, 0b111)) ==
          StopReason::InstLimitReached);
}

std::array<uint64_t, 4> read_doublewords4(udb::IssSocModel& soc,
                                           uint64_t address) {
  std::array<uint64_t, 4> values{};
  for (size_t index = 0; index < values.size(); ++index) {
    const uint64_t low =
        soc.read_physical_memory_32(address + index * sizeof(uint64_t));
    const uint64_t high = soc.read_physical_memory_32(
        address + index * sizeof(uint64_t) + 4);
    values[index] = low | (high << 32);
  }
  return values;
}

void store_vector64x4(udb::HartBase<udb::IssSocModel>* hart,
                      udb::IssSocModel& soc, uint8_t vs3, uint64_t address) {
  hart->set_xreg(1, address);
  REQUIRE(execute_at_current_mode(hart, soc,
                                  vector_store_instruction(vs3, 1, 0b111)) ==
          StopReason::InstLimitReached);
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

TEST_CASE("Zbkb and Zbkc instructions match known-answer vectors", "[crypto]") {
  ScriptedEntropySocModel soc(1024 * 1024, 0);
  auto* hart = create_seed_hart(soc);

  hart->reset(0);
  hart->set_xreg(1, 0x0123456789abcdef);
  hart->set_xreg(2, 0xfedcba9876543210);
  REQUIRE(execute_at_current_mode(hart, soc, r_instruction(0x04, 0b100, 5, 1,
                                                            2)) ==
          StopReason::InstLimitReached);
  REQUIRE(hart->xreg(5) == 0x7654321089abcdef);

  REQUIRE(execute_at_current_mode(hart, soc, r_instruction(0x04, 0b111, 5, 1,
                                                            2)) ==
          StopReason::InstLimitReached);
  REQUIRE(hart->xreg(5) == 0x00000000000010ef);

  hart->set_xreg(2, 0xfedcba987654fedc);
  REQUIRE(execute_at_current_mode(hart, soc, r_instruction(0x04, 0b100, 5, 1,
                                                            2, 0x3b)) ==
          StopReason::InstLimitReached);
  REQUIRE(hart->xreg(5) == 0xfffffffffedccdef);

  hart->set_xreg(1, 0x8000000000000000);
  hart->set_xreg(2, 0x0000000000000002);
  REQUIRE(execute_at_current_mode(hart, soc, r_instruction(0x05, 0b010, 5, 1,
                                                            2)) ==
          StopReason::InstLimitReached);
  REQUIRE(hart->xreg(5) == 0x0000000000000002);

  delete hart;
}

TEST_CASE("AES RV64 instructions match known-answer vectors", "[crypto]") {
  ScriptedEntropySocModel soc(1024 * 1024, 0);
  auto* hart = create_seed_hart(soc);

  hart->reset(0);
  hart->set_xreg(1, 0x0706050403020100);
  hart->set_xreg(2, 0x0f0e0d0c0b0a0908);
  REQUIRE(execute_at_current_mode(hart, soc, r_instruction(0x19, 0, 5, 1, 2)) ==
          StopReason::InstLimitReached);
  REQUIRE(hart->xreg(5) == 0x7bab01f276676b63);

  REQUIRE(execute_at_current_mode(hart, soc, r_instruction(0x1b, 0, 5, 1, 2)) ==
          StopReason::InstLimitReached);
  REQUIRE(hart->xreg(5) == 0x51336d2c455c6a6a);

  REQUIRE(execute_at_current_mode(hart, soc, r_instruction(0x1d, 0, 5, 1, 2)) ==
          StopReason::InstLimitReached);
  REQUIRE(hart->xreg(5) == 0x9ed7093038a3f352);

  REQUIRE(execute_at_current_mode(hart, soc, r_instruction(0x1f, 0, 5, 1, 2)) ==
          StopReason::InstLimitReached);
  REQUIRE(hart->xreg(5) == 0x6e29192e1c96a313);

  hart->set_xreg(1, 0x7bab01f276676b63);
  REQUIRE(execute_at_current_mode(hart, soc, i_instruction(0x300, 5, 1)) ==
          StopReason::InstLimitReached);
  REQUIRE(hart->xreg(5) == 0xa14f9d50f984d6b2);

  hart->set_xreg(1, 0x0f0e0d0c0b0a0908);
  REQUIRE(execute_at_current_mode(hart, soc, i_instruction(0x310, 5, 1)) ==
          StopReason::InstLimitReached);
  REQUIRE(hart->xreg(5) == 0xfe76abd6fe76abd6);

  REQUIRE(execute_at_current_mode(hart, soc, r_instruction(0x3f, 0, 5, 1, 2)) ==
          StopReason::InstLimitReached);
  REQUIRE(hart->xreg(5) == 0x0b0a090804040404);

  REQUIRE(execute_at_current_mode(hart, soc, i_instruction(0x31b, 5, 1)) ==
          StopReason::Exception);

  delete hart;
}

TEST_CASE("SHA-2 instructions match known-answer vectors", "[crypto]") {
  ScriptedEntropySocModel soc(1024 * 1024, 0);
  auto* hart = create_seed_hart(soc);

  hart->reset(0);
  hart->set_xreg(1, 0x0123456789abcdef);
  REQUIRE(execute_at_current_mode(hart, soc, i_instruction(0x102, 5, 1)) ==
          StopReason::InstLimitReached);
  REQUIRE(hart->xreg(5) == 0x000000003d5dcc4c);
  REQUIRE(execute_at_current_mode(hart, soc, i_instruction(0x103, 5, 1)) ==
          StopReason::InstLimitReached);
  REQUIRE(hart->xreg(5) == 0xffffffff9f685f13);
  REQUIRE(execute_at_current_mode(hart, soc, i_instruction(0x100, 5, 1)) ==
          StopReason::InstLimitReached);
  REQUIRE(hart->xreg(5) == 0x0000000022210003);
  REQUIRE(execute_at_current_mode(hart, soc, i_instruction(0x101, 5, 1)) ==
          StopReason::InstLimitReached);
  REQUIRE(hart->xreg(5) == 0xffffffffd6316d8a);

  REQUIRE(execute_at_current_mode(hart, soc, i_instruction(0x106, 5, 1)) ==
          StopReason::InstLimitReached);
  REQUIRE(hart->xreg(5) == 0x6f92c77c6c4f1aa1);
  REQUIRE(execute_at_current_mode(hart, soc, i_instruction(0x107, 5, 1)) ==
          StopReason::InstLimitReached);
  REQUIRE(hart->xreg(5) == 0x70a3460dbbd4317a);
  REQUIRE(execute_at_current_mode(hart, soc, i_instruction(0x104, 5, 1)) ==
          StopReason::InstLimitReached);
  REQUIRE(hart->xreg(5) == 0xb7c57a100c7ec1ab);
  REQUIRE(execute_at_current_mode(hart, soc, i_instruction(0x105, 5, 1)) ==
          StopReason::InstLimitReached);
  REQUIRE(hart->xreg(5) == 0x7703112333475567);

  delete hart;
}

TEST_CASE("SM3 and SM4 instructions match known-answer vectors", "[crypto]") {
  ScriptedEntropySocModel soc(1024 * 1024, 0);
  auto* hart = create_seed_hart(soc);

  hart->reset(0);
  hart->set_xreg(1, 0x0123456789abcdef);
  REQUIRE(execute_at_current_mode(hart, soc, i_instruction(0x108, 5, 1)) ==
          StopReason::InstLimitReached);
  REQUIRE(hart->xreg(5) == 0x0000000045ef01ab);
  REQUIRE(execute_at_current_mode(hart, soc, i_instruction(0x109, 5, 1)) ==
          StopReason::InstLimitReached);
  REQUIRE(hart->xreg(5) == 0xffffffff9898dcdc);

  hart->set_xreg(1, 0);
  hart->set_xreg(2, 0);
  REQUIRE(execute_at_current_mode(hart, soc, r_instruction(0x18, 0, 5, 1, 2)) ==
          StopReason::InstLimitReached);
  REQUIRE(hart->xreg(5) == 0x000000005b5bd58e);
  REQUIRE(execute_at_current_mode(hart, soc, r_instruction(0x1a, 0, 5, 1, 2)) ==
          StopReason::InstLimitReached);
  REQUIRE(hart->xreg(5) == 0xffffffffc01a6bd6);

  delete hart;
}

TEST_CASE("vector crypto instructions match known-answer vectors",
          "[crypto][vector]") {
  if (!vector_crypto_config_available()) {
    SKIP("requires the rv64-vector-crypto generated hart");
  }

  udb::IssSocModel soc(1024 * 1024, 0);
  auto* hart = create_vector_crypto_hart(soc);
  hart->reset(0);
  enable_vector_state(hart, soc);

  constexpr uint64_t kStateAddress = 0x1000;
  constexpr uint64_t kKeyAddress = 0x1020;
  constexpr uint64_t kResultAddress = 0x1040;

  configure_vector(hart, soc, 4, 0b010000);
  REQUIRE(read_csr(hart, soc, 0xc20) == 4);
  REQUIRE((read_csr(hart, soc, 0xc21) & 0xff) == 0b010000);
  REQUIRE(read_csr(hart, soc, 0x008) == 0);

  // FIPS-197 AES-128: the state after AddRoundKey and round key one produce
  // the first middle-round state below.
  load_vector32(hart, soc, 8, kStateAddress,
                {0x30201000, 0x70605040, 0xb0a09080, 0xf0e0d0c0});
  load_vector32(hart, soc, 12, kKeyAddress,
                {0xfd74aad6, 0xfa72afd2, 0xf178a6da, 0xfe76abd6});
  store_vector32(hart, soc, 8, kResultAddress);
  REQUIRE(read_words(soc, kResultAddress) ==
          std::array<uint32_t, 4>{0x30201000, 0x70605040, 0xb0a09080,
                                  0xf0e0d0c0});
  store_vector32(hart, soc, 12, kResultAddress);
  REQUIRE(read_words(soc, kResultAddress) ==
          std::array<uint32_t, 4>{0xfd74aad6, 0xfa72afd2, 0xf178a6da,
                                  0xfe76abd6});

  // The final round isolates SubBytes and ShiftRows before the middle round
  // below adds MixColumns.
  REQUIRE(execute_at_current_mode(hart, soc,
                                  vector_crypto_instruction(0b101000, 8, 12, 3)) ==
          StopReason::InstLimitReached);
  store_vector32(hart, soc, 8, kResultAddress);
  REQUIRE(read_words(soc, kResultAddress) ==
          std::array<uint32_t, 4>{0x7194f9b5, 0xfe93cfdb, 0xa0cfd617,
                                  0x19a6616c});

  load_vector32(hart, soc, 8, kStateAddress,
                {0x30201000, 0x70605040, 0xb0a09080, 0xf0e0d0c0});
  REQUIRE(execute_at_current_mode(hart, soc,
                                  vector_crypto_instruction(0b101000, 8, 12, 2)) ==
          StopReason::InstLimitReached);
  store_vector32(hart, soc, 8, kResultAddress);
  REQUIRE(read_words(soc, kResultAddress) ==
          std::array<uint32_t, 4>{0xe810d889, 0x68ce5a85, 0xd843182d,
                                  0xe48f12cb});

  // SHA-256("abc") message schedule words W[16] through W[19].
  load_vector32(hart, soc, 8, kStateAddress,
                {0x61626380, 0x00000000, 0x00000000, 0x00000000});
  load_vector32(hart, soc, 12, kKeyAddress,
                {0x00000000, 0x00000000, 0x00000000, 0x00000000});
  load_vector32(hart, soc, 16, kResultAddress,
                {0x00000000, 0x00000000, 0x00000000, 0x00000018});
  REQUIRE(execute_at_current_mode(hart, soc,
                                  vector_crypto_instruction(0b101101, 8, 12, 16)) ==
          StopReason::InstLimitReached);
  store_vector32(hart, soc, 8, kResultAddress);
  REQUIRE(read_words(soc, kResultAddress) ==
          std::array<uint32_t, 4>{0x61626380, 0x000f0000, 0x7da86405,
                                  0x600003c6});

  // GM/T 0002-2012 SM4: first four round keys from the standard test key.
  load_vector32(hart, soc, 12, kStateAddress,
                {0xa292ffa1, 0xdf01febf, 0x99a12b0f, 0xc42410cc});
  REQUIRE(execute_at_current_mode(hart, soc,
                                  vector_crypto_instruction(0b100001, 8, 12, 0)) ==
          StopReason::InstLimitReached);
  store_vector32(hart, soc, 8, kResultAddress);
  REQUIRE(read_words(soc, kResultAddress) ==
          std::array<uint32_t, 4>{0xf12186f9, 0x41662b61, 0x5a6ab19a,
                                  0x7ba92077});

  // The GHASH multiplier is byte-bit reversed by the instruction.  0x80
  // represents the polynomial identity and must preserve the multiplicand.
  load_vector32(hart, soc, 8, kStateAddress,
                {0x00000080, 0x00000000, 0x00000000, 0x00000000});
  load_vector32(hart, soc, 12, kKeyAddress,
                {0x01234567, 0x89abcdef, 0xfedcba98, 0x76543210});
  REQUIRE(execute_at_current_mode(hart, soc,
                                  vector_crypto_instruction(0b101000, 8, 12, 17)) ==
          StopReason::InstLimitReached);
  store_vector32(hart, soc, 8, kResultAddress);
  REQUIRE(read_words(soc, kResultAddress) ==
          std::array<uint32_t, 4>{0x01234567, 0x89abcdef, 0xfedcba98,
                                  0x76543210});

  configure_vector(hart, soc, 2, 0b011000);
  load_vector64(hart, soc, 12, kStateAddress, {0x5, 0x2});
  load_vector64(hart, soc, 16, kKeyAddress, {0x3, 0x2});
  REQUIRE(execute_at_current_mode(hart, soc,
                                  vector_r_instruction(0b001100, 8, 12, 16)) ==
          StopReason::InstLimitReached);
  store_vector64(hart, soc, 8, kResultAddress);
  REQUIRE(read_doublewords(soc, kResultAddress) ==
          std::array<uint64_t, 2>{0xf, 0x4});

  delete hart;
}

TEST_CASE("vector AES round and key-schedule instructions match FIPS-197",
          "[crypto][vector]") {
  if (!vector_crypto_config_available()) {
    SKIP("requires the rv64-vector-crypto generated hart");
  }

  udb::IssSocModel soc(1024 * 1024, 0);
  auto* hart = create_vector_crypto_hart(soc);
  hart->reset(0);
  enable_vector_state(hart, soc);

  constexpr uint64_t kStateAddress = 0x1000;
  constexpr uint64_t kKeyAddress = 0x1020;
  constexpr uint64_t kResultAddress = 0x1040;
  constexpr std::array<std::array<uint32_t, 4>, 11> kAes128RoundKeys = {{
      {0x03020100, 0x07060504, 0x0b0a0908, 0x0f0e0d0c},
      {0xfd74aad6, 0xfa72afd2, 0xf178a6da, 0xfe76abd6},
      {0x0bcf92b6, 0xf1bd3d64, 0x00c59bbe, 0xfeb33068},
      {0x4e74ffb6, 0xbfc9c2d2, 0xbf0c596c, 0x41bf6904},
      {0xbcf7f747, 0x033e3595, 0xbc326cf9, 0xfd8d05fd},
      {0xe8a3aa3c, 0xeb9d9fa9, 0x57aff350, 0xaa22f6ad},
      {0x7d0f395e, 0x9692a6f7, 0xc13d55a7, 0x6b1fa30a},
      {0x1a70f914, 0x8ce25fe3, 0x4ddf0a44, 0x26c0a94e},
      {0x35874347, 0xb9651ca4, 0xf4ba16e0, 0xd27abfae},
      {0xd1329954, 0x685785f0, 0x9ced9310, 0x4e972cbe},
      {0x7f1d1113, 0x174a94e3, 0x8ba707f3, 0xc5302b4d},
  }};
  constexpr std::array<uint32_t, 4> kPlaintext = {
      0x33221100, 0x77665544, 0xbbaa9988, 0xffeeddcc};
  constexpr std::array<uint32_t, 4> kCiphertext = {
      0xd8e0c469, 0x30047b6a, 0x80b7cdd8, 0x5ac5b470};

  configure_vector(hart, soc, 4, 0b010000);

  // AES-128 key schedule: vaeskf1 produces round key one from key zero.
  load_vector32(hart, soc, 12, kKeyAddress, kAes128RoundKeys[0]);
  REQUIRE(execute_at_current_mode(
              hart, soc, vector_crypto_instruction(0b100010, 8, 12, 1)) ==
          StopReason::InstLimitReached);
  store_vector32(hart, soc, 8, kResultAddress);
  REQUIRE(read_words(soc, kResultAddress) == kAes128RoundKeys[1]);

  // AES-256 key schedule: the first two 128-bit input keys yield key two.
  load_vector32(hart, soc, 8, kStateAddress,
                {0x03020100, 0x07060504, 0x0b0a0908, 0x0f0e0d0c});
  load_vector32(hart, soc, 12, kKeyAddress,
                {0x13121110, 0x17161514, 0x1b1a1918, 0x1f1e1d1c});
  REQUIRE(execute_at_current_mode(
              hart, soc, vector_crypto_instruction(0b101010, 8, 12, 2)) ==
          StopReason::InstLimitReached);
  store_vector32(hart, soc, 8, kResultAddress);
  REQUIRE(read_words(soc, kResultAddress) ==
          std::array<uint32_t, 4>{0x9fc273a5, 0x98c476a1, 0x93ce7fa9,
                                  0x9cc072a5});

  const auto load_round_key = [&](size_t round) {
    load_vector32(hart, soc, 12, kKeyAddress, kAes128RoundKeys[round]);
  };
  const auto execute_aes = [&](uint8_t funct6, uint8_t selector) {
    REQUIRE(execute_at_current_mode(
                hart, soc, vector_crypto_instruction(funct6, 8, 12, selector)) ==
            StopReason::InstLimitReached);
  };

  // FIPS-197 AES-128 encrypts the standard plaintext with all .vs rounds.
  load_vector32(hart, soc, 8, kStateAddress, kPlaintext);
  load_round_key(0);
  execute_aes(0b101001, 7);  // vaesz.vs
  for (size_t round = 1; round < 10; ++round) {
    load_round_key(round);
    execute_aes(0b101001, 2);  // vaesem.vs
  }
  load_round_key(10);
  execute_aes(0b101001, 3);  // vaesef.vs
  store_vector32(hart, soc, 8, kResultAddress);
  REQUIRE(read_words(soc, kResultAddress) == kCiphertext);

  // The same FIPS-197 vector exercises the .vv encryption round forms.
  load_vector32(hart, soc, 8, kStateAddress, kPlaintext);
  load_round_key(0);
  execute_aes(0b101001, 7);  // vaesz.vs
  for (size_t round = 1; round < 10; ++round) {
    load_round_key(round);
    execute_aes(0b101000, 2);  // vaesem.vv
  }
  load_round_key(10);
  execute_aes(0b101000, 3);  // vaesef.vv
  store_vector32(hart, soc, 8, kResultAddress);
  REQUIRE(read_words(soc, kResultAddress) == kCiphertext);

  // Decrypt through the complete AES-128 round schedule using .vs forms.
  load_vector32(hart, soc, 8, kStateAddress, kCiphertext);
  load_round_key(10);
  execute_aes(0b101001, 7);  // vaesz.vs
  for (size_t round = 9; round > 0; --round) {
    load_round_key(round);
    execute_aes(0b101001, 0);  // vaesdm.vs
  }
  load_round_key(0);
  execute_aes(0b101001, 1);  // vaesdf.vs
  store_vector32(hart, soc, 8, kResultAddress);
  REQUIRE(read_words(soc, kResultAddress) == kPlaintext);

  // Repeat decryption with the .vv forms, whose fixed encoding differs.
  load_vector32(hart, soc, 8, kStateAddress, kCiphertext);
  load_round_key(10);
  execute_aes(0b101001, 7);  // vaesz.vs
  for (size_t round = 9; round > 0; --round) {
    load_round_key(round);
    execute_aes(0b101000, 0);  // vaesdm.vv
  }
  load_round_key(0);
  execute_aes(0b101000, 1);  // vaesdf.vv
  store_vector32(hart, soc, 8, kResultAddress);
  REQUIRE(read_words(soc, kResultAddress) == kPlaintext);

  delete hart;
}

TEST_CASE("vector SM4 and GHASH instructions match published vectors",
          "[crypto][vector]") {
  if (!vector_crypto_config_available()) {
    SKIP("requires the rv64-vector-crypto generated hart");
  }

  udb::IssSocModel soc(1024 * 1024, 0);
  auto* hart = create_vector_crypto_hart(soc);
  hart->reset(0);
  enable_vector_state(hart, soc);

  constexpr uint64_t kStateAddress = 0x1000;
  constexpr uint64_t kKeyAddress = 0x1020;
  constexpr uint64_t kInputAddress = 0x1040;
  constexpr uint64_t kResultAddress = 0x1060;
  configure_vector(hart, soc, 4, 0b010000);

  // GM/T 0002-2012: the first four SM4 encryption rounds of its test vector.
  load_vector32(hart, soc, 8, kStateAddress,
                {0x01234567, 0x89abcdef, 0xfedcba98, 0x76543210});
  load_vector32(hart, soc, 12, kKeyAddress,
                {0xf12186f9, 0x41662b61, 0x5a6ab19a, 0x7ba92077});
  REQUIRE(execute_at_current_mode(hart, soc,
                                  vector_crypto_instruction(0b101000, 8, 12, 16)) ==
          StopReason::InstLimitReached);
  store_vector32(hart, soc, 8, kResultAddress);
  REQUIRE(read_words(soc, kResultAddress) ==
          std::array<uint32_t, 4>{0x27fad345, 0xa18b4cb2, 0x11c1e22a,
                                  0xcc13e2ee});

  // vsm4r.vs selects the first key element group and has a distinct encoding.
  load_vector32(hart, soc, 8, kStateAddress,
                {0x01234567, 0x89abcdef, 0xfedcba98, 0x76543210});
  REQUIRE(execute_at_current_mode(hart, soc,
                                  vector_crypto_instruction(0b101001, 8, 12, 16)) ==
          StopReason::InstLimitReached);
  store_vector32(hart, soc, 8, kResultAddress);
  REQUIRE(read_words(soc, kResultAddress) ==
          std::array<uint32_t, 4>{0x27fad345, 0xa18b4cb2, 0x11c1e22a,
                                  0xcc13e2ee});

  // NIST SP 800-38D Test Case 2: GHASH(0, X, H) for one ciphertext block.
  load_vector32(hart, soc, 8, kStateAddress, {0, 0, 0, 0});
  load_vector32(hart, soc, 12, kKeyAddress,
                {0xd44be966, 0x3b2c8aef, 0x59fa4c88, 0x2e2b34ca});
  load_vector32(hart, soc, 16, kInputAddress,
                {0xceda8803, 0x92a3b660, 0xb9c228f3, 0x78feb271});
  REQUIRE(execute_at_current_mode(hart, soc,
                                  vector_crypto_instruction(0b101100, 8, 12, 16)) ==
          StopReason::InstLimitReached);
  store_vector32(hart, soc, 8, kResultAddress);
  REQUIRE(read_words(soc, kResultAddress) ==
          std::array<uint32_t, 4>{0x46c72e5e, 0x88627091, 0x68b0852c,
                                  0xb7de5353});

  delete hart;
}

TEST_CASE("vector crypto bit manipulation instructions match simple vectors",
          "[crypto][vector]") {
  if (!vector_crypto_config_available()) {
    SKIP("requires the rv64-vector-crypto generated hart");
  }

  udb::IssSocModel soc(1024 * 1024, 0);
  auto* hart = create_vector_crypto_hart(soc);
  hart->reset(0);
  enable_vector_state(hart, soc);

  constexpr uint64_t kStateAddress = 0x1000;
  constexpr uint64_t kKeyAddress = 0x1020;
  constexpr uint64_t kResultAddress = 0x1040;
  configure_vector(hart, soc, 2, 0b011000);

  load_vector64(hart, soc, 12, kStateAddress,
                {0x0123456789abcdef, 0xfedcba9876543210});
  REQUIRE(execute_at_current_mode(hart, soc,
                                  vector_r_instruction(0b010010, 8, 12, 8)) ==
          StopReason::InstLimitReached);
  store_vector64(hart, soc, 8, kResultAddress);
  REQUIRE(read_doublewords(soc, kResultAddress) ==
          std::array<uint64_t, 2>{0x80c4a2e691d5b3f7, 0x7f3b5d196e2a4c08});

  REQUIRE(execute_at_current_mode(hart, soc,
                                  vector_r_instruction(0b010010, 8, 12, 9)) ==
          StopReason::InstLimitReached);
  store_vector64(hart, soc, 8, kResultAddress);
  REQUIRE(read_doublewords(soc, kResultAddress) ==
          std::array<uint64_t, 2>{0xefcdab8967452301, 0x1032547698badcfe});

  load_vector64(hart, soc, 16, kKeyAddress,
                {0x00ff00ff00ff00ff, 0xf0f0f0f0f0f0f0f0});
  REQUIRE(execute_at_current_mode(
              hart, soc, vector_r_instruction(0b000001, 8, 12, 16, 0b000)) ==
          StopReason::InstLimitReached);
  store_vector64(hart, soc, 8, kResultAddress);
  REQUIRE(read_doublewords(soc, kResultAddress) ==
          std::array<uint64_t, 2>{0x010045008900cd00, 0x0e0c0a0806040200});

  hart->set_xreg(16, 0x0f0f0f0f0f0f0f0f);
  REQUIRE(execute_at_current_mode(
              hart, soc, vector_r_instruction(0b000001, 8, 12, 16, 0b100)) ==
          StopReason::InstLimitReached);
  store_vector64(hart, soc, 8, kResultAddress);
  REQUIRE(read_doublewords(soc, kResultAddress) ==
          std::array<uint64_t, 2>{0x0020406080a0c0e0, 0xf0d0b09070503010});

  load_vector64(hart, soc, 16, kKeyAddress, {4, 4});
  REQUIRE(execute_at_current_mode(
              hart, soc, vector_r_instruction(0b010101, 8, 12, 16, 0b000)) ==
          StopReason::InstLimitReached);
  store_vector64(hart, soc, 8, kResultAddress);
  REQUIRE(read_doublewords(soc, kResultAddress) ==
          std::array<uint64_t, 2>{0x123456789abcdef0, 0xedcba9876543210f});

  REQUIRE(execute_at_current_mode(
              hart, soc, vector_r_instruction(0b010100, 8, 12, 4, 0b011)) ==
          StopReason::InstLimitReached);
  store_vector64(hart, soc, 8, kResultAddress);
  REQUIRE(read_doublewords(soc, kResultAddress) ==
          std::array<uint64_t, 2>{0xf0123456789abcde, 0x0fedcba987654321});

  hart->set_xreg(16, 68);  // Rotation counts are reduced modulo SEW.
  REQUIRE(execute_at_current_mode(
              hart, soc, vector_r_instruction(0b010101, 8, 12, 16, 0b100)) ==
          StopReason::InstLimitReached);
  store_vector64(hart, soc, 8, kResultAddress);
  REQUIRE(read_doublewords(soc, kResultAddress) ==
          std::array<uint64_t, 2>{0x123456789abcdef0, 0xedcba9876543210f});

  load_vector64(hart, soc, 16, kKeyAddress, {4, 68});
  REQUIRE(execute_at_current_mode(
              hart, soc, vector_r_instruction(0b010100, 8, 12, 16, 0b000)) ==
          StopReason::InstLimitReached);
  store_vector64(hart, soc, 8, kResultAddress);
  REQUIRE(read_doublewords(soc, kResultAddress) ==
          std::array<uint64_t, 2>{0xf0123456789abcde, 0x0fedcba987654321});

  REQUIRE(execute_at_current_mode(
              hart, soc, vector_r_instruction(0b010100, 8, 12, 16, 0b100)) ==
          StopReason::InstLimitReached);
  store_vector64(hart, soc, 8, kResultAddress);
  REQUIRE(read_doublewords(soc, kResultAddress) ==
          std::array<uint64_t, 2>{0xf0123456789abcde, 0x0fedcba987654321});

  load_vector64(hart, soc, 12, kStateAddress,
                {0x8000000000000000, 0x8000000000000000});
  load_vector64(hart, soc, 16, kKeyAddress, {2, 3});
  REQUIRE(execute_at_current_mode(
              hart, soc, vector_r_instruction(0b001101, 8, 12, 16)) ==
          StopReason::InstLimitReached);
  store_vector64(hart, soc, 8, kResultAddress);
  REQUIRE(read_doublewords(soc, kResultAddress) ==
          std::array<uint64_t, 2>{1, 1});

  hart->set_xreg(16, 2);
  REQUIRE(execute_at_current_mode(
              hart, soc, vector_r_instruction(0b001101, 8, 12, 16, 0b110)) ==
          StopReason::InstLimitReached);
  store_vector64(hart, soc, 8, kResultAddress);
  REQUIRE(read_doublewords(soc, kResultAddress) ==
          std::array<uint64_t, 2>{1, 1});

  load_vector64(hart, soc, 12, kStateAddress, {5, 2});
  hart->set_xreg(16, 3);
  REQUIRE(execute_at_current_mode(
              hart, soc, vector_r_instruction(0b001100, 8, 12, 16, 0b110)) ==
          StopReason::InstLimitReached);
  store_vector64(hart, soc, 8, kResultAddress);
  REQUIRE(read_doublewords(soc, kResultAddress) ==
          std::array<uint64_t, 2>{0xf, 0x6});

  delete hart;
}

TEST_CASE("vector SHA-2 compression instructions match FIPS 180-4",
          "[crypto][vector]") {
  if (!vector_crypto_config_available()) {
    SKIP("requires the rv64-vector-crypto generated hart");
  }

  udb::IssSocModel soc(1024 * 1024, 0);
  auto* hart = create_vector_crypto_hart(soc);
  hart->reset(0);
  enable_vector_state(hart, soc);

  constexpr uint64_t kStateAddress = 0x1000;
  constexpr uint64_t kMessageAddress = 0x1040;
  constexpr uint64_t kResultAddress = 0x1080;

  // SHA-256("abc") initial state, with elements ordered low-to-high in each
  // vector element group. The message words already include their K constants.
  constexpr std::array<uint32_t, 4> kSha256Abef = {
      0x9b05688c, 0x510e527f, 0xbb67ae85, 0x6a09e667};
  constexpr std::array<uint32_t, 4> kSha256Cdgh = {
      0x5be0cd19, 0x1f83d9ab, 0xa54ff53a, 0x3c6ef372};
  constexpr std::array<uint32_t, 4> kSha256Message = {
      0xa3ec9318, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5};

  configure_vector(hart, soc, 4, 0b010000);
  load_vector32(hart, soc, 8, kStateAddress, kSha256Cdgh);
  load_vector32(hart, soc, 12, kStateAddress, kSha256Abef);
  load_vector32(hart, soc, 16, kMessageAddress, kSha256Message);
  REQUIRE(execute_at_current_mode(hart, soc,
                                  vector_crypto_instruction(0b101111, 8, 12, 16)) ==
          StopReason::InstLimitReached);
  store_vector32(hart, soc, 8, kResultAddress);
  REQUIRE(read_words(soc, kResultAddress) ==
          std::array<uint32_t, 4>{0xfa2a4622, 0x78ce7989, 0x5d6aebcd,
                                  0x5a6ad9ad});

  load_vector32(hart, soc, 8, kStateAddress, kSha256Cdgh);
  REQUIRE(execute_at_current_mode(hart, soc,
                                  vector_crypto_instruction(0b101110, 8, 12, 16)) ==
          StopReason::InstLimitReached);
  store_vector32(hart, soc, 8, kResultAddress);
  REQUIRE(read_words(soc, kResultAddress) ==
          std::array<uint32_t, 4>{0x0bfeaed9, 0x1711d50a, 0x6f3f5484,
                                  0x88918584});

  // The same first two SHA-512 rounds validate SEW=64 and LMUL=2 handling.
  constexpr std::array<uint64_t, 4> kSha512Abef = {
      0x9b05688c2b3e6c1f, 0x510e527fade682d1,
      0xbb67ae8584caa73b, 0x6a09e667f3bcc908};
  constexpr std::array<uint64_t, 4> kSha512Cdgh = {
      0x5be0cd19137e2179, 0x1f83d9abfb41bd6b,
      0xa54ff53a5f1d36f1, 0x3c6ef372fe94f82b};
  constexpr std::array<uint64_t, 4> kSha512Message = {
      0xa3ec9318d728ae22, 0x7137449123ef65cd,
      0xb5c0fbcfec4d3b2f, 0xe9b5dba58189dbbc};

  configure_vector(hart, soc, 4, 0b011001);
  load_vector64x4(hart, soc, 8, kStateAddress, kSha512Cdgh);
  load_vector64x4(hart, soc, 12, kStateAddress, kSha512Abef);
  load_vector64x4(hart, soc, 16, kMessageAddress, kSha512Message);
  REQUIRE(execute_at_current_mode(hart, soc,
                                  vector_crypto_instruction(0b101111, 8, 12, 16)) ==
          StopReason::InstLimitReached);
  store_vector64x4(hart, soc, 8, kResultAddress);
  REQUIRE(read_doublewords4(soc, kResultAddress) ==
          std::array<uint64_t, 4>{0x58cb02347ab51f91, 0xc3d4ebfd48650ffa,
                                  0xf6afceb8bcfcddf5, 0x1320f8c9fb872cc0});

  load_vector64x4(hart, soc, 8, kStateAddress, kSha512Cdgh);
  REQUIRE(execute_at_current_mode(hart, soc,
                                  vector_crypto_instruction(0b101110, 8, 12, 16)) ==
          StopReason::InstLimitReached);
  store_vector64x4(hart, soc, 8, kResultAddress);
  REQUIRE(read_doublewords4(soc, kResultAddress) ==
          std::array<uint64_t, 4>{0x6a9f6aeb8fd9ac9e, 0xc350c7406768e508,
                                  0x0884376fd2216b02, 0xba22226b49f04b2f});

  delete hart;
}

TEST_CASE("vector SM3 instructions match the standard abc block", "[crypto][vector]") {
  if (!vector_crypto_config_available()) {
    SKIP("requires the rv64-vector-crypto generated hart");
  }

  udb::IssSocModel soc(1024 * 1024, 0);
  auto* hart = create_vector_crypto_hart(soc);
  hart->reset(0);
  enable_vector_state(hart, soc);

  constexpr uint64_t kStateAddress = 0x1000;
  constexpr uint64_t kMessageAddress = 0x1040;
  constexpr uint64_t kResultAddress = 0x1080;
  constexpr std::array<uint32_t, 8> kSm3Words0To7 = {
      0x80636261, 0x00000000, 0x00000000, 0x00000000,
      0x00000000, 0x00000000, 0x00000000, 0x00000000};
  constexpr std::array<uint32_t, 8> kSm3Words8To15 = {
      0x00000000, 0x00000000, 0x00000000, 0x00000000,
      0x00000000, 0x00000000, 0x00000000, 0x18000000};
  constexpr std::array<uint32_t, 8> kSm3Words16To23 = {
      0x00e29290, 0x00000000, 0x06060c00, 0xed709c71,
      0x00000000, 0x1f800180, 0xa97d9f93, 0x00000000};

  configure_vector(hart, soc, 8, 0b010001);
  load_vector32x8(hart, soc, 12, kStateAddress, kSm3Words0To7);
  load_vector32x8(hart, soc, 16, kMessageAddress, kSm3Words8To15);
  REQUIRE(execute_at_current_mode(hart, soc,
                                  vector_crypto_instruction(0b100000, 8, 16, 12)) ==
          StopReason::InstLimitReached);
  store_vector32x8(hart, soc, 8, kResultAddress);
  REQUIRE(read_words8(soc, kResultAddress) == kSm3Words16To23);

  // SM3's initial state and message words are byte-reversed by vsm3c.vi.
  load_vector32x8(hart, soc, 8, kStateAddress,
                  {0x6f168073, 0xb9b21449, 0xd7422417, 0x00068ada,
                   0xbc306fa9, 0xaa383116, 0x4dee8de3, 0x4e0efbb0});
  load_vector32x8(hart, soc, 12, kMessageAddress, kSm3Words0To7);
  REQUIRE(execute_at_current_mode(hart, soc,
                                  vector_crypto_instruction(0b101011, 8, 12, 0)) ==
          StopReason::InstLimitReached);
  store_vector32x8(hart, soc, 8, kResultAddress);
  REQUIRE(read_words8(soc, kResultAddress) ==
          std::array<uint32_t, 8>{0x8c4252ea, 0x2bc1edb9, 0xe7de2c00,
                                  0x92726529, 0x233a35ac, 0xf429adb2,
                                  0x794be585, 0x89b150c5});

  delete hart;
}

TEST_CASE("vector crypto instructions enforce element-group legality",
          "[crypto][vector]") {
  if (!vector_crypto_config_available()) {
    SKIP("requires the rv64-vector-crypto generated hart");
  }

  udb::IssSocModel soc(1024 * 1024, 0);
  auto* hart = create_vector_crypto_hart(soc);
  const auto prepare = [&](uint8_t vl, uint16_t vtypei) {
    hart->reset(0);
    enable_vector_state(hart, soc);
    configure_vector(hart, soc, vl, vtypei);
  };

  // vsm4r requires SEW=32 and a VL divisible by its four-element group.
  prepare(4, 0b011000);
  REQUIRE(execute_at_current_mode(hart, soc,
                                  vector_crypto_instruction(0b101000, 8, 12, 16)) ==
          StopReason::Exception);

  prepare(3, 0b010000);
  REQUIRE(execute_at_current_mode(hart, soc,
                                  vector_crypto_instruction(0b101000, 8, 12, 16)) ==
          StopReason::Exception);

  // vstart must also be aligned to the instruction's element-group size.
  prepare(4, 0b010000);
  hart->set_xreg(1, 1);
  REQUIRE(execute_at_current_mode(hart, soc, csr_instruction(0x008, 0b001, 0,
                                                               1)) ==
          StopReason::InstLimitReached);
  REQUIRE(execute_at_current_mode(hart, soc,
                                  vector_crypto_instruction(0b101000, 8, 12, 16)) ==
          StopReason::Exception);

  // The .vs AES form cannot overwrite its scalar element-group key source.
  prepare(4, 0b010000);
  REQUIRE(execute_at_current_mode(hart, soc,
                                  vector_crypto_instruction(0b101001, 8, 8, 2)) ==
          StopReason::Exception);

  // SHA-2 compression forbids the destination from overlapping either source.
  prepare(4, 0b010000);
  REQUIRE(execute_at_current_mode(hart, soc,
                                  vector_crypto_instruction(0b101110, 8, 8, 12)) ==
          StopReason::Exception);

  // The SM3 256-bit element group needs LMUL=2 on a VLEN=128 hart.
  prepare(8, 0b010000);
  REQUIRE(execute_at_current_mode(hart, soc,
                                  vector_crypto_instruction(0b100000, 8, 16, 12)) ==
          StopReason::Exception);

  prepare(8, 0b010001);
  REQUIRE(execute_at_current_mode(hart, soc,
                                  vector_crypto_instruction(0b100000, 8, 8, 12)) ==
          StopReason::Exception);

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
