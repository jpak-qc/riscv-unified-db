#pragma once

#include <array>
#include <cstddef>
#include <cstdint>
#include <memory>

#include "udb/mem_mapped_device.hpp"

namespace udb {

  // RAM backed by a lazily allocated, five-level address tree.
  //
  // A RAM-relative 32-bit offset is split as follows:
  //   [31:24] [23:10] [9:8] [7:2] [1:0]
  //      8       14      2      6      2 bits
  // Each field indexes one level. The final two bits select a byte in a
  // four-byte leaf.
  class Ram final : public MemMappedDevice {
   public:
    Ram(uint64_t base_address, uint64_t length);

    uint64_t read(uint64_t offset, size_t bytes) override;
    void write(uint64_t offset, uint64_t data, size_t bytes) override;

    int memcpy_from_host(uint64_t offset, const uint8_t* host_ptr, size_t bytes);
    int memcpy_to_host(uint8_t* host_ptr, uint64_t offset, size_t bytes) const;

   private:
    static constexpr uint64_t kMaximumLength = uint64_t{1} << 32;

    using ByteLeaf = std::array<uint8_t, 1 << 2>;
    using Level4 = std::array<std::unique_ptr<ByteLeaf>, 1 << 6>;
    using Level3 = std::array<std::unique_ptr<Level4>, 1 << 2>;
    using Level2 = std::array<std::unique_ptr<Level3>, 1 << 14>;
    using Root = std::array<std::unique_ptr<Level2>, 1 << 8>;

    static size_t root_index(uint32_t offset);
    static size_t level2_index(uint32_t offset);
    static size_t level3_index(uint32_t offset);
    static size_t level4_index(uint32_t offset);
    static size_t byte_index(uint32_t offset);

    bool range_is_valid(uint64_t offset, size_t bytes) const;
    void check_access(uint64_t offset, size_t bytes) const;
    uint8_t read_byte(uint32_t offset) const;
    void write_byte(uint32_t offset, uint8_t data);

    Root m_root{};
  };

}  // namespace udb
