#include <catch2/catch_test_macros.hpp>
#include <yaml-cpp/yaml.h>

#include <udb/bits.hpp>
#include <udb/cfgs/rv64/hart.hxx>
#include <udb/config_validator.hpp>
#include <udb/iss_soc_model.hpp>
#include <udb/stop_reason.h>

using namespace udb;

namespace {

using TestHart = Rv64_Hart<IssSocModel>;

Config make_zvfbfa_test_config() {
#ifndef UDB_VECTOR_ALTFMT_TEST_CONFIG
  throw std::runtime_error("UDB_VECTOR_ALTFMT_TEST_CONFIG compile definition is missing");
#else
  auto yaml = YAML::LoadFile(UDB_VECTOR_ALTFMT_TEST_CONFIG);
  YAML::Node zfbfmin;
  zfbfmin.push_back("Zfbfmin");
  zfbfmin.push_back("1.0.0");
  yaml["implemented_extensions"].push_back(zfbfmin);

  YAML::Node zvfbfa;
  zvfbfa.push_back("Zvfbfa");
  zvfbfa.push_back("0.8.0");
  yaml["implemented_extensions"].push_back(zvfbfa);

  const auto json = ConfigValidator::validate(yaml);
  return Config(json.at("implemented_extensions"), json.at("params"));
#endif
}

uint32_t vector_op_instruction(uint8_t funct6, uint8_t vm, uint8_t vs2,
                               uint8_t vs1, uint8_t funct3, uint8_t vd) {
  return (static_cast<uint32_t>(funct6) << 26) |
         (static_cast<uint32_t>(vm) << 25) |
         (static_cast<uint32_t>(vs2) << 20) |
         (static_cast<uint32_t>(vs1) << 15) |
         (static_cast<uint32_t>(funct3) << 12) |
         (static_cast<uint32_t>(vd) << 7) | 0x57;
}

void enable_vector_fp_state(TestHart& hart, bool altfmt) {
  hart.reset(0);
  auto& csrs = hart._csrContainer();
  auto xlen = Bits<8>{64};

  csrs.mstatus.VS()._hw_write(Bits<2>{3});
  csrs.mstatus.FS()._hw_write(Bits<2>{3});
  csrs.fcsr.FRM()._hw_write(Bits<3>{0});
  csrs.vstart.VALUE()._hw_write(Bits<64>{0}, xlen);
  csrs.vtype.VILL()._hw_write(Bits<1>{0}, xlen);
  csrs.vtype.ALTFMT()._hw_write(Bits<1>{altfmt ? 1 : 0});
  csrs.vtype.VSEW()._hw_write(Bits<3>{1});
  csrs.vtype.VLMUL()._hw_write(Bits<3>{0});
  csrs.vl.VALUE()._hw_write(Bits<64>{1}, xlen);
  hart.set_vreg(1, 0);
  hart.set_vreg(2, 0);
  hart.set_vreg(3, 0);
}

int execute_one(TestHart& hart, IssSocModel& soc, uint32_t instruction) {
  hart.set_pc(0);
  soc.write_physical_memory_32(0, instruction);
  return hart.run_one();
}

}  // namespace

TEST_CASE("vtype.ALTFMT reserves non-Zvfbfa vector floating-point instructions",
          "[cpp_hart][vector][zvfbfa]") {
  IssSocModel soc(1024 * 1024, 0);
  TestHart hart(0, soc, make_zvfbfa_test_config());

  const uint32_t vfcvt_f_x_v = vector_op_instruction(
      0b010010, 1, 3, 0, 0b001, 1);
  const uint32_t vfadd_vv = vector_op_instruction(0b000000, 1, 3, 2, 0b001, 1);

  enable_vector_fp_state(hart, false);
  REQUIRE(execute_one(hart, soc, vfcvt_f_x_v) == StopReason::InstLimitReached);

  enable_vector_fp_state(hart, true);
  REQUIRE(execute_one(hart, soc, vfcvt_f_x_v) == StopReason::Exception);

  enable_vector_fp_state(hart, true);
  REQUIRE(execute_one(hart, soc, vfadd_vv) == StopReason::InstLimitReached);
}
