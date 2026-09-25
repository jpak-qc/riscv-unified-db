#pragma once

#include <cstddef>
#include <cstdint>

#include "udb/mem_mapped_device.hpp"

namespace udb {

  // Test-only interrupt controller used by riscv-arch-test. A write selects one
  // or more pending lines and bit 31 chooses whether to set or clear them.
  class TestInterruptGenerator final : public MemMappedDevice {
   public:
    static constexpr uint64_t kDefaultBaseAddress = 0x0c000004;
    static constexpr uint64_t kMinimumLength = sizeof(uint32_t);

    TestInterruptGenerator(uint64_t base_address, uint64_t length);

    uint64_t read(uint64_t offset, size_t bytes) override;
    void write(uint64_t offset, uint64_t data, size_t bytes) override;

    bool supervisor_software_interrupt_pending() const;
    bool machine_external_interrupt_pending() const;
    bool supervisor_external_interrupt_pending() const;

   private:
    void check_access(uint64_t offset, size_t bytes) const;

    bool m_machine_external_interrupt_pending = false;
    bool m_supervisor_external_interrupt_pending = false;
    bool m_supervisor_software_interrupt_pending = false;
  };

}  // namespace udb
