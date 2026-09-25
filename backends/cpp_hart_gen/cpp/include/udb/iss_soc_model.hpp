#pragma once

#include <algorithm>

#include <cstdint>
#include <memory>
#include <optional>
#include <stdexcept>
#include <type_traits>

#include "udb/NotificationHandler.hpp"
#include "udb/clint.hpp"
#include "udb/ram.hpp"
#include "udb/soc_model.hpp"
#include "udb/system_memory.hpp"
#include "udb/test_interrupt_generator.hpp"
#include "udb/uart.hpp"


namespace udb {
  enum MEM_NOTIFICATION_EVENT
  {
    MEMREAD_EVENT = 0,
    MEMWRITE_EVENT
  };


  class MemAccessRange
  {
  public:
    MemAccessRange(uint64_t addr, size_t size) {m_addr = addr; m_size = size;}
    uint64_t GetAddress() {return  m_addr;}
    size_t GetSize() {return m_size;}

    bool operator==(const MemAccessRange& mr) const {
        return (this->m_addr == mr.m_addr && this->m_size == mr.m_size);
    }

  protected:
    uint64_t m_addr;
    size_t m_size;
  };

  class MemAccess : public MemAccessRange
  {
  public:
    MemAccess(uint64_t addr, size_t size, uint64_t data)
      : MemAccessRange(addr, size)
    {m_data = data;}

    uint64_t GetData() {return m_data;}
  private:
    uint64_t m_data;
  };



  class IssSocModel : public NotificationSource {
   public:
    IssSocModel(uint64_t size, uint64_t base_addr,
                std::optional<uint64_t> uart_base = std::nullopt,
                std::optional<uint64_t> clint_base = std::nullopt,
                uint64_t misaligned_max_atomicity_granule_size = 0)
        : m_misaligned_max_atomicity_granule_size(
              misaligned_max_atomicity_granule_size) {
      m_system_memory.add_device(std::make_unique<Ram>(base_addr, size));
      if (uart_base) {
        m_system_memory.add_device(
            std::make_unique<Uart>(*uart_base, Uart::kMinimumLength));
      }
      if (clint_base) {
        m_system_memory.add_device(
            std::make_unique<Clint>(*clint_base, Clint::kMinimumLength));
      }
      m_system_memory.add_device(std::make_unique<TestInterruptGenerator>(
          TestInterruptGenerator::kDefaultBaseAddress,
          TestInterruptGenerator::kMinimumLength));
    }
    IssSocModel() = delete;
    virtual ~IssSocModel() = default;

    uint64_t read_hpm_counter(uint64_t n) { return 0; }
    uint64_t read_mcycle() { return 0; }
    uint64_t read_mtime() {
      const auto* clint = m_system_memory.clint();
      return clint ? clint->mtime() : 0;
    }
    uint64_t sw_write_mcycle(uint64_t value) { return value; }
    virtual UdbEntropySourceSample poll_entropy_source() { return {0b01, 0, 0}; }
    void cache_block_zero(uint64_t cache_block_physical_address) {}
    void eei_ecall_from_m() {}
    void eei_ecall_from_s() {}
    void eei_ecall_from_u() {}
    void eei_ecall_from_vs() {}
    void eei_ebreak() {}
    void memory_model_acquire() {}
    void memory_model_release() {}
    void assert(uint8_t test, const char *message) {}
    void notify_mode_change(PrivilegeMode new_mode, PrivilegeMode old_mode) {}
    void prefetch_instruction(uint64_t virtual_address) {}
    void prefetch_read(uint64_t virtual_address) {}
    void prefetch_write(uint64_t virtual_address) {}
    void fence(uint8_t pi, uint8_t pr, uint8_t po, uint8_t pw, uint8_t si,
               uint8_t sr, uint8_t so, uint8_t sw) {}
    void fence_tso() {}
    void ifence() {}
    void order_pgtbl_writes_before_vmafence() {}
    void order_pgtbl_reads_after_vmafence() {}

    // Sail's ACT platform advances mtime after every two executed
    // instructions. While WFI is blocked, its clock advances on each poll.
    // The ISS samples pending lines at the next instruction boundary.
    void tick(bool waiting_for_interrupt) {
      if (auto* clint = m_system_memory.clint()) {
        clint->tick(waiting_for_interrupt);
      }
    }

    bool machine_software_interrupt_pending() const {
      const auto* clint = m_system_memory.clint();
      return clint && clint->machine_software_interrupt_pending();
    }
    bool supervisor_software_interrupt_pending() const {
      const auto* test_interrupt_generator = m_system_memory.test_interrupt_generator();
      return test_interrupt_generator &&
             test_interrupt_generator->supervisor_software_interrupt_pending();
    }
    bool machine_timer_interrupt_pending() const {
      const auto* clint = m_system_memory.clint();
      return clint && clint->machine_timer_interrupt_pending();
    }
    bool machine_external_interrupt_pending() const {
      const auto* test_interrupt_generator = m_system_memory.test_interrupt_generator();
      return test_interrupt_generator &&
             test_interrupt_generator->machine_external_interrupt_pending();
    }
    bool supervisor_external_interrupt_pending() const {
      const auto* test_interrupt_generator = m_system_memory.test_interrupt_generator();
      return test_interrupt_generator &&
             test_interrupt_generator->supervisor_external_interrupt_pending();
    }

    uint64_t read_physical_memory_8(uint64_t paddr) {
      return read_physical_memory(paddr, 1);
    }
    uint64_t read_physical_memory_16(uint64_t paddr) {
      return read_physical_memory(paddr, 2);
    }
    uint64_t read_physical_memory_32(uint64_t paddr) {
      return read_physical_memory(paddr, 4);
    }
    uint64_t read_physical_memory_64(uint64_t paddr) {
      return read_physical_memory(paddr, 8);
    }
    uint8_t physical_memory_accessible_Q_(uint64_t paddr, uint64_t len,
                                          MemoryOperation::ValueType op) const {
      if (len == 0 || (len % 8) != 0) {
        return 0;
      }

      const size_t bytes = len / 8;
      if (op == MemoryOperation::Fetch) {
        return m_system_memory.is_main_memory(paddr, bytes);
      }

      return m_system_memory.contains(paddr, bytes);
    }
    void write_physical_memory_8(uint64_t paddr, uint64_t value) {
      write_physical_memory(paddr, value, 1);
    }
    void write_physical_memory_16(uint64_t paddr, uint64_t value) {
      write_physical_memory(paddr, value, 2);
    }
    void write_physical_memory_32(uint64_t paddr, uint64_t value) {
      write_physical_memory(paddr, value, 4);
    }
    void write_physical_memory_64(uint64_t paddr, uint64_t value) {
      write_physical_memory(paddr, value, 8);
    }

    int memcpy_from_host(uint64_t guest_paddr, const uint8_t *host_ptr,
                         uint64_t size) {
      return m_system_memory.memcpy_from_host(guest_paddr, host_ptr, size);
    }
    int memcpy_to_host(uint8_t *host_ptr, uint64_t guest_paddr, uint64_t size) {
      return m_system_memory.memcpy_to_host(host_ptr, guest_paddr, size);
    }

    uint8_t atomic_check_then_write_32(uint64_t paddr, uint64_t compare_value,
                                       uint64_t write_value) {
      write_main_memory(paddr, write_value, 4);
      return true;
    }
    uint8_t atomic_check_then_write_64(uint64_t paddr, uint64_t compare_value,
                                       uint64_t write_value) {
      write_main_memory(paddr, write_value, 8);
      return true;
    }
    uint8_t atomically_set_pte_a(uint64_t pte_addr, uint64_t pte_value,
                                 uint32_t pte_len) {
      return true;
    }
    uint8_t atomically_set_pte_a_d(uint64_t pte_addr, uint64_t pte_value,
                                   uint32_t pte_len) {
      return true;
    }
    uint64_t atomic_read_modify_write_8(uint64_t phys_addr, uint64_t value,
                                        AmoOperation op) {
      return atomic_read_modify_write_small_<uint8_t>(phys_addr, value, op);
    }
    uint64_t atomic_read_modify_write_16(uint64_t phys_addr, uint64_t value,
                                         AmoOperation op) {
      return atomic_read_modify_write_small_<uint16_t>(phys_addr, value, op);
    }
    uint64_t atomic_read_modify_write_32(uint64_t phys_addr, uint64_t value,
                                         AmoOperation op) {
      switch (op.value()) {
        case AmoOperation::Swap: {
          uint32_t orig = read_main_memory(phys_addr, 4);
          write_main_memory(phys_addr, value, 4);
          return orig;
        }
        case AmoOperation::Add: {
          uint32_t orig = read_main_memory(phys_addr, 4);
          write_main_memory(phys_addr, orig + value, 4);
          return orig;
        }
        case AmoOperation::And: {
          uint32_t orig = read_main_memory(phys_addr, 4);
          write_main_memory(phys_addr, orig & value, 4);
          return orig;
        }
        case AmoOperation::Or: {
          uint32_t orig = read_main_memory(phys_addr, 4);
          write_main_memory(phys_addr, orig | value, 4);
          return orig;
        }
        case AmoOperation::Xor: {
          uint32_t orig = read_main_memory(phys_addr, 4);
          write_main_memory(phys_addr, orig ^ value, 4);
          return orig;
        }
        case AmoOperation::Max: {
          uint32_t orig = read_main_memory(phys_addr, 4);
          write_main_memory(phys_addr,
                         std::max(static_cast<int32_t>(orig),
                                  static_cast<int32_t>(value & 0xffffffff)),
                         4);
          return orig;
        }
        case AmoOperation::Maxu: {
          uint32_t orig = read_main_memory(phys_addr, 4);
          write_main_memory(
              phys_addr,
              std::max(orig, static_cast<uint32_t>(value & 0xffffffff)), 4);
          return orig;
        }
        case AmoOperation::Min: {
          uint32_t orig = read_main_memory(phys_addr, 4);
          write_main_memory(phys_addr,
                         std::min(static_cast<int32_t>(orig),
                                  static_cast<int32_t>(value & 0xffffffff)),
                         4);
          return orig;
        }
        case AmoOperation::Minu: {
          uint32_t orig = read_main_memory(phys_addr, 4);
          write_main_memory(
              phys_addr,
              std::min(orig, static_cast<uint32_t>(value & 0xffffffff)), 4);
          return orig;
        }
        default:
          __builtin_unreachable();
      }
    }
    uint64_t atomic_read_modify_write_64(uint64_t phys_addr, uint64_t value,
                                         AmoOperation op) {
      switch (op.value()) {
        case AmoOperation::Swap: {
          uint64_t orig = read_main_memory(phys_addr, 8);
          write_main_memory(phys_addr, value, 8);
          return orig;
        }
        case AmoOperation::Add: {
          uint64_t orig = read_main_memory(phys_addr, 8);
          write_main_memory(phys_addr, orig + value, 8);
          return orig;
        }
        case AmoOperation::And: {
          uint64_t orig = read_main_memory(phys_addr, 8);
          write_main_memory(phys_addr, orig & value, 8);
          return orig;
        }
        case AmoOperation::Or: {
          uint64_t orig = read_main_memory(phys_addr, 8);
          write_main_memory(phys_addr, orig | value, 8);
          return orig;
        }
        case AmoOperation::Xor: {
          uint64_t orig = read_main_memory(phys_addr, 8);
          write_main_memory(phys_addr, orig ^ value, 8);
          return orig;
        }
        case AmoOperation::Max: {
          uint64_t orig = read_main_memory(phys_addr, 8);
          write_main_memory(
              phys_addr,
              std::max(static_cast<int64_t>(orig), static_cast<int64_t>(value)),
              8);
          return orig;
        }
        case AmoOperation::Maxu: {
          uint64_t orig = read_main_memory(phys_addr, 8);
          write_main_memory(phys_addr, std::max(orig, value), 8);
          return orig;
        }
        case AmoOperation::Min: {
          uint64_t orig = read_main_memory(phys_addr, 8);
          write_main_memory(
              phys_addr,
              std::min(static_cast<int64_t>(orig), static_cast<int64_t>(value)),
              8);
          return orig;
        }
        case AmoOperation::Minu: {
          uint64_t orig = read_main_memory(phys_addr, 8);
          write_main_memory(phys_addr, std::min(orig, value), 8);
          return orig;
        }
        default:
          __builtin_unreachable();
      }
    }

    uint8_t pma_applies_Q_(PmaAttribute attr, uint64_t paddr, uint32_t len) {
      const size_t bytes = len / 8;
      const bool is_io = m_system_memory.is_io(paddr, bytes);
      const bool is_ram = m_system_memory.is_main_memory(paddr, bytes);

      switch (attr.value()) {
        case PmaAttribute::RsrvNone:
        case PmaAttribute::RsrvNonEventual:
        case PmaAttribute::AmoNone:
          return false;
        case PmaAttribute::MAG16:
          return is_ram && m_misaligned_max_atomicity_granule_size >= 16;
        case PmaAttribute::MAG8:
          return is_ram && m_misaligned_max_atomicity_granule_size >= 8;
        case PmaAttribute::MAG4:
          return is_ram && m_misaligned_max_atomicity_granule_size >= 4;
        case PmaAttribute::MAG2:
          return is_ram && m_misaligned_max_atomicity_granule_size >= 2;
        case PmaAttribute::RsrvEventual:
        case PmaAttribute::AmoSwap:
        case PmaAttribute::AmoLogical:
        case PmaAttribute::AmoArithmetic:
        case PmaAttribute::HardwarePageTableRead:
        case PmaAttribute::HardwarePageTableWrite:
        case PmaAttribute::MainMemory:
        case PmaAttribute::Cacheable:
        case PmaAttribute::Coherent:
        case PmaAttribute::Idempotent:
          return is_ram;
        case PmaAttribute::IO:
          return is_io;
        default:
          __builtin_unreachable();
      }
    }


    // builtins for qc_iu

    void delay(uint64_t) { }

    void iss_syscall(uint64_t, uint64_t) { }

    uint32_t read_device_32(uint64_t) { return 0; }

    void write_device_32(uint64_t, uint32_t) { }

    void sync_read_after_write_device(bool, uint32_t) {}

    void sync_write_after_read_device(bool, uint32_t) {}

   private:
    template <typename T>
    uint64_t atomic_read_modify_write_small_(uint64_t phys_addr, uint64_t value,
                                              AmoOperation op) {
      const T orig = static_cast<T>(read_main_memory(phys_addr, sizeof(T)));
      const T rhs = static_cast<T>(value);
      T result;

      switch (op.value()) {
        case AmoOperation::Swap:
          result = rhs;
          break;
        case AmoOperation::Add:
          result = static_cast<T>(orig + rhs);
          break;
        case AmoOperation::And:
          result = static_cast<T>(orig & rhs);
          break;
        case AmoOperation::Or:
          result = static_cast<T>(orig | rhs);
          break;
        case AmoOperation::Xor:
          result = static_cast<T>(orig ^ rhs);
          break;
        case AmoOperation::Max:
          result = static_cast<T>(std::max(static_cast<std::make_signed_t<T>>(orig),
                                            static_cast<std::make_signed_t<T>>(rhs)));
          break;
        case AmoOperation::Maxu:
          result = std::max(orig, rhs);
          break;
        case AmoOperation::Min:
          result = static_cast<T>(std::min(static_cast<std::make_signed_t<T>>(orig),
                                            static_cast<std::make_signed_t<T>>(rhs)));
          break;
        case AmoOperation::Minu:
          result = std::min(orig, rhs);
          break;
        default:
          __builtin_unreachable();
      }

      write_main_memory(phys_addr, result, sizeof(T));
      return orig;
    }

    uint64_t read_physical_memory(uint64_t physical_address, size_t bytes) {
      if (m_system_memory.is_main_memory(physical_address, bytes)) {
        MemAccessRange memory_access(physical_address, bytes);
        Notify(MEMREAD_EVENT, &memory_access);
      }
      return m_system_memory.read(physical_address, bytes);
    }

    void write_physical_memory(uint64_t physical_address, uint64_t data,
                               size_t bytes) {
      const bool is_main_memory = m_system_memory.is_main_memory(physical_address, bytes);
      m_system_memory.write(physical_address, data, bytes);
      if (is_main_memory) {
        MemAccess memory_access(physical_address, bytes, data);
        Notify(MEMWRITE_EVENT, &memory_access);
      }
    }

    uint64_t read_main_memory(uint64_t physical_address, size_t bytes) {
      if (!m_system_memory.is_main_memory(physical_address, bytes)) {
        throw std::out_of_range("Atomic access does not target RAM");
      }
      return read_physical_memory(physical_address, bytes);
    }

    void write_main_memory(uint64_t physical_address, uint64_t data,
                           size_t bytes) {
      if (!m_system_memory.is_main_memory(physical_address, bytes)) {
        throw std::out_of_range("Atomic access does not target RAM");
      }
      write_physical_memory(physical_address, data, bytes);
    }

    SystemMemory m_system_memory;
    uint64_t m_misaligned_max_atomicity_granule_size;

  };

  static_assert(SocModel<IssSocModel>,
                "IssSocModel does not obey SocModel interface");
}  // namespace udb
