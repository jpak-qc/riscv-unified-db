
#include <catch2/catch_test_macros.hpp>
#include <udb/defines.hpp>
#include <udb/hart_factory.hxx>
#include <udb/iss_soc_model.hpp>
#include <udb/util.hpp>

using namespace udb;

namespace {

  struct MemoryWriteObserver {
    IssSocModel& soc;
    uint64_t address;
    uint64_t observed_value = 0;
    bool observed = false;

    static int on_notification(void* user_param, uint64_t, uint64_t event, void* data) {
      auto& observer = *static_cast<MemoryWriteObserver*>(user_param);
      if (event != MEMWRITE_EVENT) {
        return 0;
      }

      auto& access = *static_cast<MemAccess*>(data);
      if (access.GetAddress() != observer.address) {
        return 0;
      }

      observer.soc.memcpy_to_host(reinterpret_cast<uint8_t*>(&observer.observed_value),
                                  observer.address, sizeof(observer.observed_value));
      observer.observed = true;
      return 0;
    }
  };

}  // namespace

TEST_CASE("concat", "[util]") {
  Bits<4> a{0x1};
  Bits<4> b{0x2};
  Bits<4> c{0x3};
  REQUIRE(concat(a, b, c) == 0x123_b);
}

// Regression test for highest_set_bit(0), the return code from which,
// when cast with `$signed`, needs to be -1.
static const std::string cfg_yaml = R"(
$schema: https://riscv.org/udb/schemas/config_schema-0.1.0.json
kind: architecture configuration
type: fully configured
name: rv64-highest-set-bit-test
description: For highest_set_bit() testing

implemented_extensions:
  - [I, "2.1"]

params:
  MXLEN: 64
)";

TEST_CASE("highest_set_bit(0) returns -1", "[util]") {
  IssSocModel soc(1024 * 1024, 0);
  auto* hart_base = HartFactory::create("rv64", 0, cfg_yaml, soc);
  auto* hart = static_cast<Rv64_Hart<IssSocModel>*>(hart_base);

  REQUIRE(hart->highest_set_bit(Bits<64>{0}).make_signed() == SignedBits<8>{-1});

  delete hart_base;
}

TEST_CASE("highest_set_bit finds the top set bit", "[util]") {
  IssSocModel soc(1024 * 1024, 0);
  auto* hart_base = HartFactory::create("rv64", 0, cfg_yaml, soc);
  auto* hart = static_cast<Rv64_Hart<IssSocModel>*>(hart_base);

  REQUIRE(hart->highest_set_bit(Bits<64>{0x1}) == Bits<8>{0});
  REQUIRE(hart->highest_set_bit(Bits<64>{0x8000000000000000ULL}) == Bits<8>{63});

  delete hart_base;
}

TEST_CASE("bit_insert supports runtime-width targets", "[util]") {
  _PossiblyUnknownRuntimeBits<256, false> target{0_b, 256_b};

  const auto result = bit_insert<31, 0, 256>(target, 0xdeadbeef_b);

  REQUIRE(result.width() == 256);
  REQUIRE(result == 0xdeadbeef_b);
}

TEST_CASE("RAM write notifications observe the completed write", "[util]") {
  constexpr uint64_t kRamBase = 0x80000000;
  constexpr uint64_t kAddress = kRamBase + 0x80;
  constexpr uint64_t kValue = 0x1122334455667788;

  IssSocModel soc(0x1000, kRamBase);
  MemoryWriteObserver observer{soc, kAddress};
  soc.AttachHandler(MemoryWriteObserver::on_notification, 0, &observer);

  soc.write_physical_memory_64(kAddress, kValue);

  REQUIRE(observer.observed);
  REQUIRE(observer.observed_value == kValue);
}
