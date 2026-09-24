#include "udb/clint.hpp"

#include <stdexcept>

namespace udb {

  Clint::Clint(uint64_t base_address, uint64_t length) : MemMappedDevice(base_address, length) {
    if (length < kMinimumLength) {
      throw std::invalid_argument("CLINT range does not contain all required registers");
    }
  }

  uint64_t Clint::read(uint64_t offset, size_t bytes) {
    if (access_fits(offset, bytes, kMsipOffset, sizeof(uint32_t))) {
      return read_register(m_msip, offset, kMsipOffset, bytes);
    }
    if (access_fits(offset, bytes, kMtimecmpOffset, sizeof(uint64_t))) {
      return read_register(m_mtimecmp, offset, kMtimecmpOffset, bytes);
    }
    if (access_fits(offset, bytes, kMtimeOffset, sizeof(uint64_t))) {
      return read_register(m_mtime, offset, kMtimeOffset, bytes);
    }

    throw std::out_of_range("Unsupported CLINT read");
  }

  void Clint::write(uint64_t offset, uint64_t data, size_t bytes) {
    if (access_fits(offset, bytes, kMsipOffset, sizeof(uint32_t))) {
      write_register(m_msip, data, offset, kMsipOffset, bytes);
      m_msip &= 0xffffffff;
      return;
    }
    if (access_fits(offset, bytes, kMtimecmpOffset, sizeof(uint64_t))) {
      write_register(m_mtimecmp, data, offset, kMtimecmpOffset, bytes);
      return;
    }
    if (access_fits(offset, bytes, kMtimeOffset, sizeof(uint64_t))) {
      write_register(m_mtime, data, offset, kMtimeOffset, bytes);
      return;
    }

    throw std::out_of_range("Unsupported CLINT write");
  }

  void Clint::tick(bool waiting_for_interrupt) {
    if (waiting_for_interrupt) {
      ++m_mtime;
      return;
    }

    if (m_instructions_since_tick == kInstructionsPerTick) {
      ++m_mtime;
      m_instructions_since_tick = 0;
    }
    ++m_instructions_since_tick;
  }

  bool Clint::machine_software_interrupt_pending() const { return (m_msip & 1) != 0; }

  bool Clint::machine_timer_interrupt_pending() const { return m_mtime >= m_mtimecmp; }

  uint64_t Clint::mtime() const { return m_mtime; }

  bool Clint::access_fits(uint64_t offset, size_t bytes, uint64_t register_offset,
                          size_t register_bytes) {
    return bytes != 0 && offset >= register_offset && offset - register_offset <= register_bytes &&
           bytes <= register_bytes - (offset - register_offset);
  }

  uint64_t Clint::low_bits_mask(size_t bytes) {
    return bytes == sizeof(uint64_t) ? ~uint64_t{0} : (uint64_t{1} << (bytes * 8)) - 1;
  }

  uint64_t Clint::read_register(uint64_t value, uint64_t offset, uint64_t register_offset,
                                size_t bytes) {
    return (value >> ((offset - register_offset) * 8)) & low_bits_mask(bytes);
  }

  void Clint::write_register(uint64_t& register_value, uint64_t value, uint64_t offset,
                             uint64_t register_offset, size_t bytes) {
    const uint64_t shift = (offset - register_offset) * 8;
    const uint64_t mask = low_bits_mask(bytes) << shift;
    register_value = (register_value & ~mask) | ((value & low_bits_mask(bytes)) << shift);
  }

}  // namespace udb
