#include "mini32/register_file.hpp"

#include <algorithm>
#include <stdexcept>

namespace mini32 {

void RegisterFile::reset() {
    registers_.fill(0U);
}

std::uint32_t RegisterFile::read(const std::uint8_t index) const {
    validate_index(index);
    return index == 0U ? 0U : registers_[index];
}

void RegisterFile::write(const std::uint8_t index, const std::uint32_t value) {
    validate_index(index);
    if (index != 0U) {
        registers_[index] = value;
    }
}

void RegisterFile::validate_index(const std::uint8_t index) const {
    if (index >= kRegisterCount) {
        throw std::out_of_range("Mini32 register index is outside r0-r31");
    }
}

}  // namespace mini32
