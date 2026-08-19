#include "mini32/decoder.hpp"

namespace mini32 {
namespace {

constexpr std::uint32_t kOpcodeShift = 26U;
constexpr std::uint32_t kRegisterMask = 0x1FU;
constexpr std::uint32_t kReservedRMask = 0x7FFU;

bool is_known_opcode(const std::uint8_t raw_opcode) {
    return raw_opcode <= static_cast<std::uint8_t>(Opcode::Halt);
}

bool is_r_format(const Opcode opcode) {
    switch (opcode) {
    case Opcode::Nop:
    case Opcode::Add:
    case Opcode::Sub:
    case Opcode::And:
    case Opcode::Or:
    case Opcode::Xor:
    case Opcode::Slt:
    case Opcode::Shl:
    case Opcode::Shr:
    case Opcode::Halt:
        return true;
    default:
        return false;
    }
}

}  // namespace

DecodeResult Decoder::decode(const std::uint32_t instruction) {
    const auto raw_opcode = static_cast<std::uint8_t>(instruction >> kOpcodeShift);
    if (!is_known_opcode(raw_opcode)) {
        return {.error = DecodeError::IllegalOpcode};
    }

    const auto opcode = static_cast<Opcode>(raw_opcode);
    if (opcode == Opcode::Nop && instruction != 0U) {
        return {.error = DecodeError::MalformedEncoding};
    }
    if (is_r_format(opcode) && (instruction & kReservedRMask) != 0U) {
        return {.error = DecodeError::MalformedEncoding};
    }
    if (opcode == Opcode::Jr && (instruction & 0xFFFFU) != 0U) {
        return {.error = DecodeError::MalformedEncoding};
    }
    if (opcode == Opcode::Lui && ((instruction >> 16U) & kRegisterMask) != 0U) {
        return {.error = DecodeError::MalformedEncoding};
    }

    return {
        .instruction = DecodedInstruction{
            .opcode = opcode,
            .rd = static_cast<std::uint8_t>((instruction >> 21U) & kRegisterMask),
            .rs1 = static_cast<std::uint8_t>((instruction >> 16U) & kRegisterMask),
            .rs2 = static_cast<std::uint8_t>((instruction >> 11U) & kRegisterMask),
            .imm16 = static_cast<std::uint16_t>(instruction & 0xFFFFU),
        },
    };
}

std::optional<ControlSignals> Decoder::control_for(const Opcode opcode) {
    switch (opcode) {
    case Opcode::Nop:
        return ControlSignals{.reg_write = false, .alu_src_immediate = false,
                              .alu_operation = AluOperation::Add};
    case Opcode::Add:
        return ControlSignals{.reg_write = true, .alu_src_immediate = false,
                              .alu_operation = AluOperation::Add};
    case Opcode::Sub:
        return ControlSignals{.reg_write = true, .alu_src_immediate = false,
                              .alu_operation = AluOperation::Sub};
    case Opcode::Addi:
        return ControlSignals{.reg_write = true, .alu_src_immediate = true,
                              .alu_operation = AluOperation::Add};
    default:
        return std::nullopt;
    }
}

std::uint32_t Decoder::sign_extend_16(const std::uint16_t immediate) {
    if ((immediate & 0x8000U) == 0U) {
        return immediate;
    }
    return 0xFFFF0000U | immediate;
}

}  // namespace mini32
