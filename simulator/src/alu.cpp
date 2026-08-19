#include "mini32/alu.hpp"

#include <cstdint>

namespace mini32 {
namespace {

bool signed_less_than(const std::uint32_t lhs, const std::uint32_t rhs) {
    const bool lhs_negative = (lhs & 0x80000000U) != 0U;
    const bool rhs_negative = (rhs & 0x80000000U) != 0U;
    return lhs_negative != rhs_negative ? lhs_negative : lhs < rhs;
}

}  // namespace

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
        return signed_less_than(lhs, rhs) ? 1U : 0U;
    case AluOperation::ShiftLeft:
        return lhs << (rhs & 0x1FU);
    case AluOperation::ShiftRight:
        return lhs >> (rhs & 0x1FU);
    }

    return 0U;
}

}  // namespace mini32
