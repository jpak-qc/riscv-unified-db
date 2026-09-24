#include "udb/uart.hpp"

#include <cstdio>
#include <stdexcept>

namespace udb {

  Uart::Uart(uint64_t base_address, uint64_t length) : MemMappedDevice(base_address, length) {
    if (length < kMinimumLength) {
      throw std::invalid_argument("UART range does not contain all required registers");
    }
  }

  uint64_t Uart::read(uint64_t offset, size_t bytes) {
    check_access(offset, bytes);

    uint64_t value = 0;
    for (size_t i = 0; i < bytes; ++i) {
      const uint64_t register_offset = offset + i;
      const uint8_t byte = register_offset == kLineStatusRegisterOffset ? kTransmitterEmpty : 0;
      value |= static_cast<uint64_t>(byte) << (i * 8);
    }
    return value;
  }

  void Uart::write(uint64_t offset, uint64_t data, size_t bytes) {
    check_access(offset, bytes);

    for (size_t i = 0; i < bytes; ++i) {
      if (offset + i == kTransmitHoldingRegisterOffset) {
        std::putchar(static_cast<int>((data >> (i * 8)) & 0xff));
        std::fflush(stdout);
      }
    }
  }

  void Uart::check_access(uint64_t offset, size_t bytes) const {
    if (bytes == 0 || bytes > sizeof(uint64_t) || offset >= length() || bytes > length() - offset) {
      throw std::out_of_range("UART access is outside the mapped UART range");
    }
  }

}  // namespace udb
