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

}  // namespace

int main() {
    const auto nop = mini32::Decoder::decode(0U);
    CHECK(nop.ok());
    CHECK(nop.instruction->opcode == mini32::Opcode::Nop);

    const auto add = mini32::Decoder::decode(encode_r(mini32::Opcode::Add, 3U, 1U, 2U));
    CHECK(add.ok());
    CHECK(add.instruction->rd == 3U);
    CHECK(add.instruction->rs1 == 1U);
    CHECK(add.instruction->rs2 == 2U);

    const auto sub = mini32::Decoder::decode(encode_r(mini32::Opcode::Sub, 4U, 3U, 2U));
    CHECK(sub.ok());
    CHECK(sub.instruction->opcode == mini32::Opcode::Sub);

    const auto addi = mini32::Decoder::decode(encode_i(mini32::Opcode::Addi, 5U, 1U, 0x7FFFU));
    CHECK(addi.ok());
    CHECK(addi.instruction->imm16 == 0x7FFFU);
    CHECK(mini32::Decoder::sign_extend_16(0x0001U) == 0x00000001U);
    CHECK(mini32::Decoder::sign_extend_16(0x7FFFU) == 0x00007FFFU);
    CHECK(mini32::Decoder::sign_extend_16(0x8000U) == 0xFFFF8000U);
    CHECK(mini32::Decoder::sign_extend_16(0xFFFFU) == 0xFFFFFFFFU);

    const auto malformed = mini32::Decoder::decode(encode_r(mini32::Opcode::Add, 3U, 1U, 2U) | 1U);
    CHECK(!malformed.ok());
    CHECK(malformed.error == mini32::DecodeError::MalformedEncoding);

    const auto illegal = mini32::Decoder::decode(0xFC000000U);
    CHECK(!illegal.ok());
    CHECK(illegal.error == mini32::DecodeError::IllegalOpcode);
}
