#include "mini32/alu.hpp"

#include <cstdint>

namespace mini32 {

std::uint32_t Alu::execute(
    const AluOperation operation, const std::uint32_t lhs, const std::uint32_t rhs) {
    switch (operation) {
    case AluOperation::Add:
        return lhs + rhs;
    case AluOperation::Sub:
        return lhs - rhs;
    case AluOperation::And:
        return lhs & rhs;
    case AluOperation::Or:
        return lhs | rhs;
    case AluOperation::Xor:
        return lhs ^ rhs;
    case AluOperation::Slt:
        return static_cast<std::int32_t>(lhs) < static_cast<std::int32_t>(rhs) ? 1U : 0U;
    case AluOperation::ShiftLeft:
        return lhs << (rhs & 0x1FU);
    case AluOperation::ShiftRight:
        return lhs >> (rhs & 0x1FU);
    }

    return 0U;
}

}  // namespace mini32
