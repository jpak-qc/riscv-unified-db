#include "udb/mem_mapped_device.hpp"

#include <stdexcept>

namespace udb {

  MemMappedDevice::MemMappedDevice(uint64_t base_address, uint64_t length)
      : m_base_address(base_address), m_length(length) {
    if (length == 0) {
      throw std::invalid_argument("A memory-mapped device must have non-zero length");
    }
  }

  bool MemMappedDevice::contains(uint64_t physical_address, size_t bytes) const {
    if (bytes == 0 || physical_address < m_base_address) {
      return false;
    }

    const uint64_t offset = physical_address - m_base_address;
    return offset < m_length && bytes <= m_length - offset;
  }

}  // namespace udb
