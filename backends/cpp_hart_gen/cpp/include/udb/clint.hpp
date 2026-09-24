#pragma once

#include <cstddef>
#include <cstdint>

#include "udb/mem_mapped_device.hpp"

namespace udb {

  // Core-Local Interruptor (CLINT) with one hart's MSIP, MTIMECMP, and MTIME
  // registers. These registers are memory mapped but also expose interrupt
  // state to the ISS between instructions.
  class Clint final : public MemMappedDevice {
   public:
    static constexpr uint64_t kMinimumLength = 0xc000;
    static constexpr uint64_t kMsipOffset = 0x0000;
    static constexpr uint64_t kMtimecmpOffset = 0x4000;
    static constexpr uint64_t kMtimeOffset = 0xbff8;

    Clint(uint64_t base_address, uint64_t length);

    uint64_t read(uint64_t offset, size_t bytes) override;
    void write(uint64_t offset, uint64_t data, size_t bytes) override;

    void tick(bool waiting_for_interrupt);
    bool machine_software_interrupt_pending() const;
    bool machine_timer_interrupt_pending() const;
    uint64_t mtime() const;

   private:
    static constexpr uint64_t kInstructionsPerTick = 2;

    static bool access_fits(uint64_t offset, size_t bytes, uint64_t register_offset,
                            size_t register_bytes);
    static uint64_t low_bits_mask(size_t bytes);
    static uint64_t read_register(uint64_t value, uint64_t offset, uint64_t register_offset,
                                  size_t bytes);
    static void write_register(uint64_t& register_value, uint64_t value, uint64_t offset,
                               uint64_t register_offset, size_t bytes);

    uint64_t m_msip = 0;
    uint64_t m_mtimecmp = ~uint64_t{0};
    uint64_t m_mtime = 0;
    uint64_t m_instructions_since_tick = 0;
  };

}  // namespace udb
