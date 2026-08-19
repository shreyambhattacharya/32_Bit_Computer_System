#include <cstdint>

#include "mini32/alu.hpp"
#include "test_support.hpp"

using mini32::Alu;
using mini32::AluOperation;

int main() {
    CHECK(Alu::execute(AluOperation::Add, 0U, 0U) == 0U);
    CHECK(Alu::execute(AluOperation::Add, 1U, 1U) == 2U);
    CHECK(Alu::execute(AluOperation::Add, 0xFFFFFFFFU, 1U) == 0U);

    CHECK(Alu::execute(AluOperation::Sub, 0U, 0U) == 0U);
    CHECK(Alu::execute(AluOperation::Sub, 10U, 5U) == 5U);
    CHECK(Alu::execute(AluOperation::Sub, 5U, 10U) == 0xFFFFFFFBU);
    CHECK(Alu::execute(AluOperation::Sub, 0U, 1U) == 0xFFFFFFFFU);

    CHECK(Alu::execute(AluOperation::And, 0xAA55AA55U, 0x0FF00FF0U) == 0x0A500A50U);
    CHECK(Alu::execute(AluOperation::Or, 0xAA55AA55U, 0x0FF00FF0U) == 0xAFF5AFF5U);
    CHECK(Alu::execute(AluOperation::Xor, 0xAA55AA55U, 0x0FF00FF0U) == 0xA5A5A5A5U);

    CHECK(Alu::execute(AluOperation::Slt, 0U, 1U) == 1U);
    CHECK(Alu::execute(AluOperation::Slt, 1U, 0U) == 0U);
    CHECK(Alu::execute(AluOperation::Slt, 0xFFFFFFFFU, 0U) == 1U);
    CHECK(Alu::execute(AluOperation::Slt, 0U, 0xFFFFFFFFU) == 0U);
    CHECK(Alu::execute(AluOperation::Slt, 0x80000000U, 0x7FFFFFFFU) == 1U);

    CHECK(Alu::execute(AluOperation::ShiftLeft, 1U, 0U) == 1U);
    CHECK(Alu::execute(AluOperation::ShiftLeft, 1U, 1U) == 2U);
    CHECK(Alu::execute(AluOperation::ShiftLeft, 1U, 31U) == 0x80000000U);
    CHECK(Alu::execute(AluOperation::ShiftLeft, 1U, 32U) == 1U);
    CHECK(Alu::execute(AluOperation::ShiftLeft, 1U, 33U) == 2U);
    CHECK(Alu::execute(AluOperation::ShiftRight, 0x80000000U, 0U) == 0x80000000U);
    CHECK(Alu::execute(AluOperation::ShiftRight, 0x80000000U, 1U) == 0x40000000U);
    CHECK(Alu::execute(AluOperation::ShiftRight, 0x80000000U, 31U) == 1U);
    CHECK(Alu::execute(AluOperation::ShiftRight, 0x80000000U, 32U) == 0x80000000U);
    CHECK(Alu::execute(AluOperation::ShiftRight, 0x80000000U, 33U) == 0x40000000U);
}
