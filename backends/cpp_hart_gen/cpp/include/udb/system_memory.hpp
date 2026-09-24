#pragma once

#include <cstddef>
#include <cstdint>
#include <memory>
#include <vector>

#include "udb/mem_mapped_device.hpp"

namespace udb {

  class Clint;
  class Ram;
  class TestInterruptGenerator;
  class Uart;

  // Owns the ISS memory-mapped devices and performs the software equivalent
  // of the address decoder shown on the whiteboard.
  class SystemMemory {
   public:
    SystemMemory() = default;

    void add_device(std::unique_ptr<MemMappedDevice> device);

    uint64_t read(uint64_t physical_address, size_t bytes);
    void write(uint64_t physical_address, uint64_t data, size_t bytes);
    int memcpy_from_host(uint64_t physical_address, const uint8_t* host_ptr, size_t bytes);
    int memcpy_to_host(uint8_t* host_ptr, uint64_t physical_address, size_t bytes) const;

    bool contains(uint64_t physical_address, size_t bytes) const;
    bool is_main_memory(uint64_t physical_address, size_t bytes) const;
    bool is_io(uint64_t physical_address, size_t bytes) const;

    Ram& ram();
    const Ram& ram() const;
    Clint* clint();
    const Clint* clint() const;
    Uart* uart();
    const Uart* uart() const;
    TestInterruptGenerator* test_interrupt_generator();
    const TestInterruptGenerator* test_interrupt_generator() const;

   private:
    static bool ranges_overlap(const MemMappedDevice& first, const MemMappedDevice& second);

    MemMappedDevice* find_device(uint64_t physical_address, size_t bytes);
    const MemMappedDevice* find_device(uint64_t physical_address, size_t bytes) const;

    std::vector<std::unique_ptr<MemMappedDevice>> m_devices;

    // These are non-owning convenience pointers. m_devices owns the objects.
    Ram* m_ram = nullptr;
    Clint* m_clint = nullptr;
    Uart* m_uart = nullptr;
    TestInterruptGenerator* m_test_interrupt_generator = nullptr;
  };

}  // namespace udb
