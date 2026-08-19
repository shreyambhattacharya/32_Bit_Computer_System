#include <cstdint>

#include "mini32/decoder.hpp"
#include "test_support.hpp"

namespace {

std::uint32_t encode_r(const mini32::Opcode opcode, const std::uint8_t rd,
                       const std::uint8_t rs1, const std::uint8_t rs2) {
    return (static_cast<std::uint32_t>(opcode) << 26U) |
           (static_cast<std::uint32_t>(rd) << 21U) |
           (static_cast<std::uint32_t>(rs1) << 16U) |
           (static_cast<std::uint32_t>(rs2) << 11U);
}

std::uint32_t encode_i(const mini32::Opcode opcode, const std::uint8_t rd,
                       const std::uint8_t rs1, const std::uint16_t immediate) {
    return (static_cast<std::uint32_t>(opcode) << 26U) |
           (static_cast<std::uint32_t>(rd) << 21U) |
           (static_cast<std::uint32_t>(rs1) << 16U) | immediate;
}

std::uint32_t encode_s(const std::uint8_t rs2, const std::uint8_t rs1,
                       const std::uint16_t immediate) {
    return (static_cast<std::uint32_t>(mini32::Opcode::Sw) << 26U) |
           (static_cast<std::uint32_t>(rs2) << 21U) |
           (static_cast<std::uint32_t>(rs1) << 16U) | immediate;
}

}  // namespace

int main() {
    const auto nop = mini32::Decoder::decode(0U);
    CHECK(nop.ok());
    CHECK(nop.instruction->opcode == mini32::Opcode::Nop);

    for (const mini32::Opcode opcode : {mini32::Opcode::Add, mini32::Opcode::Sub,
                                        mini32::Opcode::And, mini32::Opcode::Or,
                                        mini32::Opcode::Xor, mini32::Opcode::Slt,
                                        mini32::Opcode::Shl, mini32::Opcode::Shr}) {
        const auto result = mini32::Decoder::decode(encode_r(opcode, 3U, 1U, 2U));
        CHECK(result.ok());
        CHECK(result.instruction->opcode == opcode);
        CHECK(result.instruction->rd == 3U);
        CHECK(result.instruction->rs1 == 1U);
        CHECK(result.instruction->rs2 == 2U);
    }
    CHECK(mini32::Decoder::decode(static_cast<std::uint32_t>(mini32::Opcode::Halt) << 26U).ok());

    for (const mini32::Opcode opcode : {mini32::Opcode::Addi, mini32::Opcode::Andi,
                                        mini32::Opcode::Ori, mini32::Opcode::Xori,
                                        mini32::Opcode::Lw}) {
        const auto result = mini32::Decoder::decode(encode_i(opcode, 5U, 1U, 0x8001U));
        CHECK(result.ok());
        CHECK(result.instruction->rd == 5U);
        CHECK(result.instruction->rs1 == 1U);
        CHECK(result.instruction->imm16 == 0x8001U);
    }
    const auto lui = mini32::Decoder::decode(encode_i(mini32::Opcode::Lui, 5U, 0U, 0x1000U));
    CHECK(lui.ok());
    CHECK(lui.instruction->rd == 5U);
    CHECK(lui.instruction->imm16 == 0x1000U);

    const auto store = mini32::Decoder::decode(encode_s(9U, 4U, 0xFFF0U));
    CHECK(store.ok());
    CHECK(store.instruction->rs2 == 9U);
    CHECK(store.instruction->rs1 == 4U);
    CHECK(store.instruction->imm16 == 0xFFF0U);

    const std::uint32_t valid_jr = (static_cast<std::uint32_t>(mini32::Opcode::Jr) << 26U) | (7U << 21U);
    CHECK(mini32::Decoder::decode(valid_jr).ok());
    CHECK(!mini32::Decoder::decode(valid_jr | (1U << 20U)).ok());
    CHECK(!mini32::Decoder::decode(valid_jr | 1U).ok());

    const std::uint32_t branch = (static_cast<std::uint32_t>(mini32::Opcode::Beq) << 26U) |
                                 (6U << 21U) | (7U << 16U) | 0xFFFCU;
    const auto decoded_branch = mini32::Decoder::decode(branch);
    CHECK(decoded_branch.ok());
    CHECK(decoded_branch.instruction->rs1 == 6U);
    CHECK(decoded_branch.instruction->rs2 == 7U);
    CHECK(decoded_branch.instruction->imm16 == 0xFFFCU);
    const std::uint32_t jump = (static_cast<std::uint32_t>(mini32::Opcode::J) << 26U) | 0x03ABCDE0U;
    const auto decoded_jump = mini32::Decoder::decode(jump);
    CHECK(decoded_jump.ok());
    CHECK(decoded_jump.instruction->imm26 == 0x03ABCDE0U);

    const auto malformed = mini32::Decoder::decode(encode_r(mini32::Opcode::Add, 3U, 1U, 2U) | 1U);
    CHECK(!malformed.ok());
    CHECK(malformed.error == mini32::DecodeError::MalformedEncoding);
    const auto illegal = mini32::Decoder::decode(0xFC000000U);
    CHECK(!illegal.ok());
    CHECK(illegal.error == mini32::DecodeError::IllegalOpcode);

    CHECK(mini32::Decoder::immediate_value(mini32::ImmediateKind::Signed16, 0x0000U) == 0U);
    CHECK(mini32::Decoder::immediate_value(mini32::ImmediateKind::Signed16, 0x7FFFU) == 0x7FFFU);
    CHECK(mini32::Decoder::immediate_value(mini32::ImmediateKind::Signed16, 0x8000U) == 0xFFFF8000U);
    CHECK(mini32::Decoder::immediate_value(mini32::ImmediateKind::Signed16, 0xFFFFU) == 0xFFFFFFFFU);
    CHECK(mini32::Decoder::immediate_value(mini32::ImmediateKind::ZeroExtended16, 0x0000U) == 0U);
    CHECK(mini32::Decoder::immediate_value(mini32::ImmediateKind::ZeroExtended16, 0x7FFFU) == 0x7FFFU);
    CHECK(mini32::Decoder::immediate_value(mini32::ImmediateKind::ZeroExtended16, 0x8000U) == 0x8000U);
    CHECK(mini32::Decoder::immediate_value(mini32::ImmediateKind::ZeroExtended16, 0xFFFFU) == 0xFFFFU);
    CHECK(mini32::Decoder::immediate_value(mini32::ImmediateKind::Upper16, 0x0000U) == 0U);
    CHECK(mini32::Decoder::immediate_value(mini32::ImmediateKind::Upper16, 0x1000U) == 0x10000000U);
    CHECK(mini32::Decoder::immediate_value(mini32::ImmediateKind::Upper16, 0x2000U) == 0x20000000U);
    CHECK(mini32::Decoder::immediate_value(mini32::ImmediateKind::Upper16, 0xFFFFU) == 0xFFFF0000U);
    CHECK(mini32::Decoder::branch_displacement(0x0001U) == 4U);
    CHECK(mini32::Decoder::branch_displacement(0xFFFFU) == 0xFFFFFFFCU);
    CHECK(mini32::Decoder::jump_displacement(0x00000000U) == 0U);
    CHECK(mini32::Decoder::jump_displacement(0x00000001U) == 4U);
    CHECK(mini32::Decoder::jump_displacement(0x01FFFFFFU) == 0x07FFFFFCU);
    CHECK(mini32::Decoder::jump_displacement(0x03FFFFFFU) == 0xFFFFFFFCU);
    CHECK(mini32::Decoder::jump_displacement(0x03FFFFFEU) == 0xFFFFFFF8U);
    CHECK(mini32::Decoder::jump_displacement(0x02000000U) == 0xF8000000U);

    for (const mini32::Opcode opcode : {mini32::Opcode::Nop, mini32::Opcode::Add,
                                        mini32::Opcode::Sub, mini32::Opcode::And,
                                        mini32::Opcode::Or, mini32::Opcode::Xor,
                                        mini32::Opcode::Slt, mini32::Opcode::Shl,
                                        mini32::Opcode::Shr, mini32::Opcode::Addi,
                                        mini32::Opcode::Andi, mini32::Opcode::Ori,
                                        mini32::Opcode::Xori, mini32::Opcode::Lui,
                                        mini32::Opcode::Lw, mini32::Opcode::Sw,
                                        mini32::Opcode::Beq, mini32::Opcode::Bne,
                                        mini32::Opcode::Blt, mini32::Opcode::Bge,
                                        mini32::Opcode::J, mini32::Opcode::Jal,
                                        mini32::Opcode::Jr, mini32::Opcode::Halt}) {
        CHECK(mini32::Decoder::control_for(opcode).has_value());
    }
}
