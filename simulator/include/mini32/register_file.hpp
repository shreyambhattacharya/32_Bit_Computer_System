#pragma once

#include <array>
#include <cstdint>

#include "mini32/isa.hpp"

namespace mini32 {

class RegisterFile {
public:
    void reset();

    [[nodiscard]] std::uint32_t read(std::uint8_t index) const;
    void write(std::uint8_t index, std::uint32_t value);

private:
    void validate_index(std::uint8_t index) const;

    std::array<std::uint32_t, kRegisterCount> registers_{};
};

}  // namespace mini32
