#include "udb/system_memory.hpp"

#include <stdexcept>

#include "udb/clint.hpp"
#include "udb/ram.hpp"
#include "udb/test_interrupt_generator.hpp"
#include "udb/uart.hpp"

namespace udb {

  void SystemMemory::add_device(std::unique_ptr<MemMappedDevice> device) {
    if (!device) {
      throw std::invalid_argument("Cannot add a null memory-mapped device");
    }

    for (const auto& existing_device : m_devices) {
      if (ranges_overlap(*existing_device, *device)) {
        throw std::invalid_argument("Memory-mapped device ranges overlap");
      }
    }

    auto* ram = dynamic_cast<Ram*>(device.get());
    auto* clint = dynamic_cast<Clint*>(device.get());
    auto* uart = dynamic_cast<Uart*>(device.get());
    auto* test_interrupt_generator = dynamic_cast<TestInterruptGenerator*>(device.get());

    if (ram) {
      if (m_ram) {
        throw std::invalid_argument("SystemMemory may contain only one RAM device");
      }
    } else if (clint) {
      if (m_clint) {
        throw std::invalid_argument("SystemMemory may contain only one CLINT device");
      }
    } else if (uart) {
      if (m_uart) {
        throw std::invalid_argument("SystemMemory may contain only one UART device");
      }
    } else if (test_interrupt_generator) {
      if (m_test_interrupt_generator) {
        throw std::invalid_argument("SystemMemory may contain only one test interrupt generator");
      }
    }

    m_devices.push_back(std::move(device));
    if (ram) {
      m_ram = ram;
    } else if (clint) {
      m_clint = clint;
    } else if (uart) {
      m_uart = uart;
    } else if (test_interrupt_generator) {
      m_test_interrupt_generator = test_interrupt_generator;
    }
  }

  uint64_t SystemMemory::read(uint64_t physical_address, size_t bytes) {
    auto* device = find_device(physical_address, bytes);
    if (!device) {
      throw std::out_of_range("Physical read does not target a mapped device");
    }
    return device->read(physical_address - device->base_address(), bytes);
  }

  void SystemMemory::write(uint64_t physical_address, uint64_t data, size_t bytes) {
    auto* device = find_device(physical_address, bytes);
    if (!device) {
      throw std::out_of_range("Physical write does not target a mapped device");
    }
    device->write(physical_address - device->base_address(), data, bytes);
  }

  int SystemMemory::memcpy_from_host(uint64_t physical_address, const uint8_t* host_ptr,
                                     size_t bytes) {
    if (!m_ram || !m_ram->contains(physical_address, bytes)) {
      return -1;
    }
    return m_ram->memcpy_from_host(physical_address - m_ram->base_address(), host_ptr, bytes);
  }

  int SystemMemory::memcpy_to_host(uint8_t* host_ptr, uint64_t physical_address,
                                   size_t bytes) const {
    if (!m_ram || !m_ram->contains(physical_address, bytes)) {
      return -1;
    }
    return m_ram->memcpy_to_host(host_ptr, physical_address - m_ram->base_address(), bytes);
  }

  bool SystemMemory::contains(uint64_t physical_address, size_t bytes) const {
    return find_device(physical_address, bytes) != nullptr;
  }

  bool SystemMemory::is_main_memory(uint64_t physical_address, size_t bytes) const {
    return m_ram && m_ram->contains(physical_address, bytes);
  }

  bool SystemMemory::is_io(uint64_t physical_address, size_t bytes) const {
    return contains(physical_address, bytes) && !is_main_memory(physical_address, bytes);
  }

  Ram& SystemMemory::ram() {
    if (!m_ram) {
      throw std::logic_error("SystemMemory has no RAM device");
    }
    return *m_ram;
  }

  const Ram& SystemMemory::ram() const {
    if (!m_ram) {
      throw std::logic_error("SystemMemory has no RAM device");
    }
    return *m_ram;
  }

  Clint* SystemMemory::clint() { return m_clint; }

  const Clint* SystemMemory::clint() const { return m_clint; }

  Uart* SystemMemory::uart() { return m_uart; }

  const Uart* SystemMemory::uart() const { return m_uart; }

  TestInterruptGenerator* SystemMemory::test_interrupt_generator() {
    return m_test_interrupt_generator;
  }

  const TestInterruptGenerator* SystemMemory::test_interrupt_generator() const {
    return m_test_interrupt_generator;
  }

  bool SystemMemory::ranges_overlap(const MemMappedDevice& first, const MemMappedDevice& second) {
    return first.contains(second.base_address(), 1) || second.contains(first.base_address(), 1);
  }

  MemMappedDevice* SystemMemory::find_device(uint64_t physical_address, size_t bytes) {
    for (const auto& device : m_devices) {
      if (device->contains(physical_address, bytes)) {
        return device.get();
      }
    }
    return nullptr;
  }

  const MemMappedDevice* SystemMemory::find_device(uint64_t physical_address, size_t bytes) const {
    for (const auto& device : m_devices) {
      if (device->contains(physical_address, bytes)) {
        return device.get();
      }
    }
    return nullptr;
  }

}  // namespace udb
