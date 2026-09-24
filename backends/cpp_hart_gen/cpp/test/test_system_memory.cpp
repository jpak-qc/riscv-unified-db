#include <catch2/catch_test_macros.hpp>
#include <memory>
#include <stdexcept>

#include "udb/clint.hpp"
#include "udb/ram.hpp"
#include "udb/system_memory.hpp"
#include "udb/test_interrupt_generator.hpp"
#include "udb/uart.hpp"

using namespace udb;

namespace {

  constexpr uint64_t kRamBase = 0x80000000;
  constexpr uint64_t kRamLength = 0x02000000;
  constexpr uint64_t kClintBase = 0x02000000;
  constexpr uint64_t kUartBase = 0x10000000;

  SystemMemory make_system_memory() {
    SystemMemory memory;
    memory.add_device(std::make_unique<Ram>(kRamBase, kRamLength));
    memory.add_device(std::make_unique<Clint>(kClintBase, Clint::kMinimumLength));
    memory.add_device(std::make_unique<Uart>(kUartBase, Uart::kMinimumLength));
    memory.add_device(std::make_unique<TestInterruptGenerator>(
        TestInterruptGenerator::kDefaultBaseAddress, TestInterruptGenerator::kMinimumLength));
    return memory;
  }

}  // namespace

TEST_CASE("RAM uses a sparse little-endian address tree", "[system_memory]") {
  Ram ram(kRamBase, kRamLength);

  REQUIRE(ram.read(0x00000000, 8) == 0);
  REQUIRE(ram.read(0x01000000, 1) == 0);  // Crosses the root-table boundary.

  ram.write(0x000003fe, 0x1122334455667788ULL, 8);
  REQUIRE(ram.read(0x000003fe, 8) == 0x1122334455667788ULL);
  REQUIRE(ram.read(0x000003fe, 1) == 0x88);
  REQUIRE(ram.read(0x000003ff, 2) == 0x6677);

  ram.write(0x01000000, 0xa5, 1);
  REQUIRE(ram.read(0x01000000, 1) == 0xa5);
}

TEST_CASE("SystemMemory routes a complete access to its mapped device", "[system_memory]") {
  auto memory = make_system_memory();

  memory.write(kRamBase + 0x24, 0xdeadbeef, 4);
  REQUIRE(memory.read(kRamBase + 0x24, 4) == 0xdeadbeef);
  REQUIRE(memory.is_main_memory(kRamBase + 0x24, 4));
  REQUIRE_FALSE(memory.is_io(kRamBase + 0x24, 4));

  REQUIRE(memory.read(kUartBase + Uart::kLineStatusRegisterOffset, 1) == Uart::kTransmitterEmpty);
  REQUIRE(memory.is_io(kUartBase + Uart::kLineStatusRegisterOffset, 1));

  memory.write(kClintBase + Clint::kMsipOffset, 1, 4);
  REQUIRE(memory.clint()->machine_software_interrupt_pending());

  memory.write(TestInterruptGenerator::kDefaultBaseAddress, (uint64_t{1} << 31) | (1 << 11), 4);
  REQUIRE(memory.test_interrupt_generator()->machine_external_interrupt_pending());
}

TEST_CASE("SystemMemory rejects unmapped, crossing, and overlapping accesses", "[system_memory]") {
  auto memory = make_system_memory();

  REQUIRE_FALSE(memory.contains(kRamBase + kRamLength - 1, 2));
  REQUIRE_THROWS_AS(memory.read(kRamBase + kRamLength - 1, 2), std::out_of_range);
  REQUIRE_THROWS_AS(memory.write(0x40000000, 0, 4), std::out_of_range);

  REQUIRE_THROWS_AS(memory.add_device(std::make_unique<Ram>(kRamBase + 0x1000, 0x1000)),
                    std::invalid_argument);
}

TEST_CASE("CLINT preserves partial register accesses and timer state", "[system_memory]") {
  auto memory = make_system_memory();

  memory.write(kClintBase + Clint::kMsipOffset + 1, 0xab, 1);
  REQUIRE(memory.read(kClintBase + Clint::kMsipOffset, 4) == 0xab00);
  REQUIRE_FALSE(memory.clint()->machine_software_interrupt_pending());

  memory.write(kClintBase + Clint::kMsipOffset, 1, 1);
  REQUIRE(memory.clint()->machine_software_interrupt_pending());

  memory.write(kClintBase + Clint::kMtimecmpOffset, 1, 8);
  memory.clint()->tick(false);
  memory.clint()->tick(false);
  memory.clint()->tick(false);
  REQUIRE(memory.clint()->mtime() == 1);
  REQUIRE(memory.clint()->machine_timer_interrupt_pending());
}
