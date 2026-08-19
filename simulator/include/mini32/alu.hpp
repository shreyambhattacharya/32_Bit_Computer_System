#pragma once

#include <cstdint>

namespace mini32 {

enum class AluOperation : std::uint8_t {
    Add,
    Sub,
    And,
    Or,
    Xor,
    Slt,
    ShiftLeft,
    ShiftRight,
};

class Alu {
public:
    [[nodiscard]] static std::uint32_t execute(
        AluOperation operation, std::uint32_t lhs, std::uint32_t rhs);
};

}  // namespace mini32
