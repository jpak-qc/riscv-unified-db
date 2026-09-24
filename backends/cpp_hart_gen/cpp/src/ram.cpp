#include "udb/ram.hpp"

#include <stdexcept>

namespace udb {

  Ram::Ram(uint64_t base_address, uint64_t length) : MemMappedDevice(base_address, length) {
    if (length > kMaximumLength) {
      throw std::invalid_argument("The RAM address-tree implementation supports at most 4 GiB");
    }
  }

  uint64_t Ram::read(uint64_t offset, size_t bytes) {
    check_access(offset, bytes);

    uint64_t value = 0;
    for (size_t i = 0; i < bytes; ++i) {
      value |= static_cast<uint64_t>(read_byte(static_cast<uint32_t>(offset + i))) << (i * 8);
    }
    return value;
  }

  void Ram::write(uint64_t offset, uint64_t data, size_t bytes) {
    check_access(offset, bytes);

    for (size_t i = 0; i < bytes; ++i) {
      write_byte(static_cast<uint32_t>(offset + i), static_cast<uint8_t>(data >> (i * 8)));
    }
  }

  int Ram::memcpy_from_host(uint64_t offset, const uint8_t* host_ptr, size_t bytes) {
    if (!range_is_valid(offset, bytes)) {
      return -1;
    }

    for (size_t i = 0; i < bytes; ++i) {
      write_byte(static_cast<uint32_t>(offset + i), host_ptr[i]);
    }
    return static_cast<int>(bytes);
  }

  int Ram::memcpy_to_host(uint8_t* host_ptr, uint64_t offset, size_t bytes) const {
    if (!range_is_valid(offset, bytes)) {
      return -1;
    }

    for (size_t i = 0; i < bytes; ++i) {
      host_ptr[i] = read_byte(static_cast<uint32_t>(offset + i));
    }
    return static_cast<int>(bytes);
  }

  size_t Ram::root_index(uint32_t offset) { return (offset >> 24) & 0xff; }

  size_t Ram::level2_index(uint32_t offset) { return (offset >> 10) & 0x3fff; }

  size_t Ram::level3_index(uint32_t offset) { return (offset >> 8) & 0x3; }

  size_t Ram::level4_index(uint32_t offset) { return (offset >> 2) & 0x3f; }

  size_t Ram::byte_index(uint32_t offset) { return offset & 0x3; }

  bool Ram::range_is_valid(uint64_t offset, size_t bytes) const {
    return offset <= length() && bytes <= length() - offset;
  }

  void Ram::check_access(uint64_t offset, size_t bytes) const {
    if (bytes == 0 || bytes > sizeof(uint64_t) || !range_is_valid(offset, bytes)) {
      throw std::out_of_range("RAM access is outside the mapped RAM range");
    }
  }

  uint8_t Ram::read_byte(uint32_t offset) const {
    const auto& level2 = m_root[root_index(offset)];
    if (!level2) {
      return 0;
    }

    const auto& level3 = (*level2)[level2_index(offset)];
    if (!level3) {
      return 0;
    }

    const auto& level4 = (*level3)[level3_index(offset)];
    if (!level4) {
      return 0;
    }

    const auto& leaf = (*level4)[level4_index(offset)];
    return leaf ? (*leaf)[byte_index(offset)] : 0;
  }

  void Ram::write_byte(uint32_t offset, uint8_t data) {
    auto& level2 = m_root[root_index(offset)];
    if (!level2) {
      level2 = std::make_unique<Level2>();
    }

    auto& level3 = (*level2)[level2_index(offset)];
    if (!level3) {
      level3 = std::make_unique<Level3>();
    }

    auto& level4 = (*level3)[level3_index(offset)];
    if (!level4) {
      level4 = std::make_unique<Level4>();
    }

    auto& leaf = (*level4)[level4_index(offset)];
    if (!leaf) {
      leaf = std::make_unique<ByteLeaf>();
    }

    (*leaf)[byte_index(offset)] = data;
  }

}  // namespace udb
