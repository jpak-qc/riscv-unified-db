#pragma once

#include <cstddef>
#include <cstdint>

namespace udb {

  // Base class for anything reached through the ISS physical address map.
  //
  // SystemMemory selects a device using its physical address range, then calls
  // read() or write() with an address relative to this device's base address.
  class MemMappedDevice {
   public:
    MemMappedDevice(uint64_t base_address, uint64_t length);
    virtual ~MemMappedDevice() = default;

    MemMappedDevice(const MemMappedDevice&) = delete;
    MemMappedDevice& operator=(const MemMappedDevice&) = delete;
    MemMappedDevice(MemMappedDevice&&) = delete;
    MemMappedDevice& operator=(MemMappedDevice&&) = delete;

    // Device-relative offset and access size, in bytes.
    virtual uint64_t read(uint64_t offset, size_t bytes) = 0;
    virtual void write(uint64_t offset, uint64_t data, size_t bytes) = 0;

    uint64_t base_address() const { return m_base_address; }
    uint64_t length() const { return m_length; }

    // True only when the complete physical access is within this device.
    // This avoids overflow-prone address + size range checks.
    bool contains(uint64_t physical_address, size_t bytes) const;

   private:
    uint64_t m_base_address;
    uint64_t m_length;
  };

}  // namespace udb
