#pragma once

#include <gelf.h>

#include <limits>
#include <string>
#include <utility>
#include <vector>
#include <algorithm>

#include "udb/soc_model.hpp"

namespace udb {
  // Class to read data out of an ELF file
  class Memory;
  class ElfReader {
    // ElfException is thrown when something goes wrong when reading an ELF file
    class ElfException : public std::exception {
     public:
      ElfException() = default;
      ElfException(const std::string& what) : std::exception(), m_what(what) {}
      ElfException(std::string&& what)
          : std::exception(), m_what(std::move(what)) {}

      const char* what() const noexcept override { return m_what.c_str(); }

     private:
      const std::string m_what;
    };

   public:
    ElfReader() = delete;
    ElfReader(const std::string& path);
    ~ElfReader();

    // return the smallest and largest address from any LOADable segment
    std::pair<uint64_t, uint64_t> mem_range();

    // return starting address
    uint64_t entry();

    // get the address of a symbol named 'name', and put it in 'result'
    //
    // returns false if the symbol is not found, true otherwise
    bool getSym(const std::string& name, Elf64_Addr* result);

    // Loads all LOADable sections from an ELF into 'm'
    //
    // returns the start address
    template <SocModel SocType>
    uint64_t loadLoadableSegments(SocType& soc);

    // Patches zero-byte alignment padding (0x0000 = c.unimp in compressed ISA)
    // to 0x0001 (c.nop) in executable segments to prevent spurious traps.
    // Call after loadLoadableSegments.
    template <SocModel SocType>
    void patchCUnimpToNop(SocType& soc);

   private:
    int m_fd;
    Elf* m_elf;
    unsigned char m_class;
    uint64_t m_entry;
  };

  template <SocModel SocType>
  uint64_t ElfReader::loadLoadableSegments(SocType& soc) {
    size_t n;

    if (elf_getphdrnum(m_elf, &n) != 0) {
      throw ElfException("Could not find number of Program Headers");
    }

    for (size_t i = 0; i < n; i++) {
      GElf_Phdr phdr;
      if(gelf_getphdr(m_elf, i, &phdr) != &phdr) {
        throw ElfException("Cannot get program header");
      }

      if (phdr.p_type == PT_LOAD) {
        Elf_Data* d = elf_getdata_rawchunk(m_elf, phdr.p_offset,
                                            phdr.p_filesz, ELF_T_BYTE);
        soc.memcpy_from_host(phdr.p_vaddr,
                              reinterpret_cast<const uint8_t*>(d->d_buf),
                              d->d_size);
      }
    }

    GElf_Ehdr ehdr;
    if(gelf_getehdr(m_elf, &ehdr) != &ehdr) {
      throw ElfException("Cannot get ELF header");
    }

    return ehdr.e_entry;
  }

  template <SocModel SocType>
  void ElfReader::patchCUnimpToNop(SocType& soc) {
    size_t n;

    if (elf_getphdrnum(m_elf, &n) != 0) {
      return;
    }

    for (size_t i = 0; i < n; i++) {
      GElf_Phdr phdr;
      if (gelf_getphdr(m_elf, i, &phdr) != &phdr) {
        continue;
      }

      // Only patch executable (text) segments
      if (phdr.p_type != PT_LOAD || !(phdr.p_flags & PF_X)) {
        continue;
      }

      uint64_t seg_addr = phdr.p_vaddr;
      uint64_t seg_size = phdr.p_memsz;

      // Read the segment back from SoC memory into a local buffer
      std::vector<uint8_t> buf(seg_size, 0);
      int copied = soc.memcpy_to_host(buf.data(), seg_addr, seg_size);
      if (copied < 0) {
        continue;
      }

      // Replace 16-bit aligned 0x0000 (c.unimp) with 0x0001 (c.nop)
      bool patched = false;
      for (uint64_t off = 0; off + 1 < seg_size; off += 2) {
        if (buf[off] == 0x00 && buf[off + 1] == 0x00) {
          buf[off]     = 0x01;
          buf[off + 1] = 0x00;
          patched = true;
        }
      }

      if (patched) {
        soc.memcpy_from_host(seg_addr, buf.data(), seg_size);
      }
    }
  }
}
