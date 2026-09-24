#include "udb/test_interrupt_generator.hpp"

#include <stdexcept>

namespace udb {

  TestInterruptGenerator::TestInterruptGenerator(uint64_t base_address, uint64_t length)
      : MemMappedDevice(base_address, length) {
    if (length < kMinimumLength) {
      throw std::invalid_argument(
          "Test interrupt generator range does not contain its control register");
    }
  }

  uint64_t TestInterruptGenerator::read(uint64_t offset, size_t bytes) {
    check_access(offset, bytes);
    return 0;
  }

  void TestInterruptGenerator::write(uint64_t offset, uint64_t data, size_t bytes) {
    check_access(offset, bytes);

    const bool set = (data & (uint64_t{1} << 31)) != 0;
    if ((data & (uint64_t{1} << 11)) != 0) {
      m_machine_external_interrupt_pending = set;
    }
    if ((data & (uint64_t{1} << 9)) != 0) {
      m_supervisor_external_interrupt_pending = set;
    }
    if ((data & (uint64_t{1} << 1)) != 0) {
      m_supervisor_software_interrupt_pending = set;
    }
  }

  bool TestInterruptGenerator::supervisor_software_interrupt_pending() const {
    return m_supervisor_software_interrupt_pending;
  }

  bool TestInterruptGenerator::machine_external_interrupt_pending() const {
    return m_machine_external_interrupt_pending;
  }

  bool TestInterruptGenerator::supervisor_external_interrupt_pending() const {
    return m_supervisor_external_interrupt_pending;
  }

  void TestInterruptGenerator::check_access(uint64_t offset, size_t bytes) const {
    if (bytes == 0 || bytes > sizeof(uint64_t) || offset >= length() || bytes > length() - offset) {
      throw std::out_of_range("Test interrupt generator access is outside its mapped range");
    }
  }

}  // namespace udb
