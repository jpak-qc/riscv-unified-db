#pragma once

#include <cstddef>
#include <cstdint>

#include "udb/mem_mapped_device.hpp"

namespace udb {

  // Minimal NS16550-compatible console UART. It models the transmit holding
  // register and reports that the transmitter is always ready.
  class Uart final : public MemMappedDevice {
   public:
    static constexpr uint64_t kMinimumLength = 8;
    static constexpr uint64_t kTransmitHoldingRegisterOffset = 0;
    static constexpr uint64_t kLineStatusRegisterOffset = 5;
    static constexpr uint8_t kTransmitterEmpty = 0x20;

    Uart(uint64_t base_address, uint64_t length);

    uint64_t read(uint64_t offset, size_t bytes) override;
    void write(uint64_t offset, uint64_t data, size_t bytes) override;

   private:
    void check_access(uint64_t offset, size_t bytes) const;
  };

}  // namespace udb
