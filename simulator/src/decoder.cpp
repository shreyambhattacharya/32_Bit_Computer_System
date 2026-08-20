#include "mini32/decoder.hpp"

namespace mini32 {
namespace {

constexpr std::uint32_t kOpcodeShift = 26U;
constexpr std::uint32_t kRegisterMask = 0x1FU;
constexpr std::uint32_t kReservedRMask = 0x7FFU;
constexpr std::uint32_t kReservedJrMask = 0x1FFFFFU;

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

enum class InstructionFormat : std::uint8_t {
    R,
    I,
    S,
    B,
    J,
    Jr,
};

InstructionFormat format_for(const Opcode opcode) {
    if (is_r_format(opcode)) {
        return InstructionFormat::R;
    }
    switch (opcode) {
    case Opcode::Addi:
    case Opcode::Andi:
    case Opcode::Ori:
    case Opcode::Xori:
    case Opcode::Lui:
    case Opcode::Lw:
        return InstructionFormat::I;
    case Opcode::Sw:
        return InstructionFormat::S;
    case Opcode::Beq:
    case Opcode::Bne:
    case Opcode::Blt:
    case Opcode::Bge:
        return InstructionFormat::B;
    case Opcode::J:
    case Opcode::Jal:
        return InstructionFormat::J;
    case Opcode::Jr:
        return InstructionFormat::Jr;
    default:
        return InstructionFormat::R;
    }
}

}  // namespace

DecodeResult Decoder::decode(const std::uint32_t instruction) {
    const auto raw_opcode = static_cast<std::uint8_t>(instruction >> kOpcodeShift);
    if (!is_known_opcode(raw_opcode)) {
        return {.error = DecodeError::IllegalOpcode};
    }

    const auto opcode = static_cast<Opcode>(raw_opcode);
    if ((opcode == Opcode::Nop || opcode == Opcode::Halt) &&
        (instruction & 0x03FFFFFFU) != 0U) {
        return {.error = DecodeError::MalformedEncoding};
    }
    const InstructionFormat format = format_for(opcode);
    if (format == InstructionFormat::R && (instruction & kReservedRMask) != 0U) {
        return {.error = DecodeError::MalformedEncoding};
    }
    if (format == InstructionFormat::Jr && (instruction & kReservedJrMask) != 0U) {
        return {.error = DecodeError::MalformedEncoding};
    }
    if (opcode == Opcode::Lui && ((instruction >> 16U) & kRegisterMask) != 0U) {
        return {.error = DecodeError::MalformedEncoding};
    }

    DecodedInstruction decoded{.opcode = opcode};
    switch (format) {
    case InstructionFormat::R:
        decoded.rd = static_cast<std::uint8_t>((instruction >> 21U) & kRegisterMask);
        decoded.rs1 = static_cast<std::uint8_t>((instruction >> 16U) & kRegisterMask);
        decoded.rs2 = static_cast<std::uint8_t>((instruction >> 11U) & kRegisterMask);
        break;
    case InstructionFormat::I:
        decoded.rd = static_cast<std::uint8_t>((instruction >> 21U) & kRegisterMask);
        decoded.rs1 = static_cast<std::uint8_t>((instruction >> 16U) & kRegisterMask);
        decoded.imm16 = static_cast<std::uint16_t>(instruction & 0xFFFFU);
        break;
    case InstructionFormat::S:
        decoded.rs2 = static_cast<std::uint8_t>((instruction >> 21U) & kRegisterMask);
        decoded.rs1 = static_cast<std::uint8_t>((instruction >> 16U) & kRegisterMask);
        decoded.imm16 = static_cast<std::uint16_t>(instruction & 0xFFFFU);
        break;
    case InstructionFormat::B:
        decoded.rs1 = static_cast<std::uint8_t>((instruction >> 21U) & kRegisterMask);
        decoded.rs2 = static_cast<std::uint8_t>((instruction >> 16U) & kRegisterMask);
        decoded.imm16 = static_cast<std::uint16_t>(instruction & 0xFFFFU);
        break;
    case InstructionFormat::J:
        decoded.imm26 = instruction & 0x03FFFFFFU;
        break;
    case InstructionFormat::Jr:
        decoded.rs1 = static_cast<std::uint8_t>((instruction >> 21U) & kRegisterMask);
        break;
    }
    return {.instruction = decoded};
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
    case Opcode::And:
        return ControlSignals{.reg_write = true, .alu_operation = AluOperation::And};
    case Opcode::Or:
        return ControlSignals{.reg_write = true, .alu_operation = AluOperation::Or};
    case Opcode::Xor:
        return ControlSignals{.reg_write = true, .alu_operation = AluOperation::Xor};
    case Opcode::Slt:
        return ControlSignals{.reg_write = true, .alu_operation = AluOperation::Slt};
    case Opcode::Shl:
        return ControlSignals{.reg_write = true, .alu_operation = AluOperation::ShiftLeft};
    case Opcode::Shr:
        return ControlSignals{.reg_write = true, .alu_operation = AluOperation::ShiftRight};
    case Opcode::Addi:
        return ControlSignals{.reg_write = true, .alu_src_immediate = true,
                              .alu_operation = AluOperation::Add,
                              .immediate_kind = ImmediateKind::Signed16};
    case Opcode::Andi:
        return ControlSignals{.reg_write = true, .alu_src_immediate = true,
                              .alu_operation = AluOperation::And,
                              .immediate_kind = ImmediateKind::ZeroExtended16};
    case Opcode::Ori:
        return ControlSignals{.reg_write = true, .alu_src_immediate = true,
                              .alu_operation = AluOperation::Or,
                              .immediate_kind = ImmediateKind::ZeroExtended16};
    case Opcode::Xori:
        return ControlSignals{.reg_write = true, .alu_src_immediate = true,
                              .alu_operation = AluOperation::Xor,
                              .immediate_kind = ImmediateKind::ZeroExtended16};
    case Opcode::Lui:
        return ControlSignals{.reg_write = true, .alu_src_immediate = true,
                              .alu_operation = AluOperation::Add,
                              .immediate_kind = ImmediateKind::Upper16};
    case Opcode::Lw:
        return ControlSignals{.reg_write = true, .alu_src_immediate = true,
                              .alu_operation = AluOperation::Add,
                              .writeback_source = WritebackSource::Memory,
                              .immediate_kind = ImmediateKind::Signed16,
                              .memory_operation = MemoryOperation::Load};
    case Opcode::Sw:
        return ControlSignals{.alu_src_immediate = true, .alu_operation = AluOperation::Add,
                              .immediate_kind = ImmediateKind::Signed16,
                              .memory_operation = MemoryOperation::Store};
    case Opcode::Beq:
        return ControlSignals{.control_flow = ControlFlowKind::ConditionalBranch,
                              .branch_predicate = BranchPredicate::Equal};
    case Opcode::Bne:
        return ControlSignals{.control_flow = ControlFlowKind::ConditionalBranch,
                              .branch_predicate = BranchPredicate::NotEqual};
    case Opcode::Blt:
        return ControlSignals{.control_flow = ControlFlowKind::ConditionalBranch,
                              .branch_predicate = BranchPredicate::SignedLessThan};
    case Opcode::Bge:
        return ControlSignals{.control_flow = ControlFlowKind::ConditionalBranch,
                              .branch_predicate = BranchPredicate::SignedGreaterEqual};
    case Opcode::J:
        return ControlSignals{.control_flow = ControlFlowKind::RelativeJump};
    case Opcode::Jal:
        return ControlSignals{.reg_write = true, .writeback_source = WritebackSource::PcPlus4,
                              .register_destination = RegisterDestination::ReturnAddress,
                              .control_flow = ControlFlowKind::RelativeJump};
    case Opcode::Jr:
        return ControlSignals{.control_flow = ControlFlowKind::RegisterJump};
    case Opcode::Halt:
        return ControlSignals{.halt = true};
    default:
        return std::nullopt;
    }
}

std::uint32_t Decoder::branch_displacement(const std::uint16_t immediate) {
    return immediate_value(ImmediateKind::Signed16, immediate) * 4U;
}

std::uint32_t Decoder::jump_displacement(const std::uint32_t immediate) {
    const std::uint32_t encoded = immediate & 0x03FFFFFFU;
    const std::uint32_t sign_extended = (encoded & 0x02000000U) == 0U
                                            ? encoded
                                            : (encoded | 0xFC000000U);
    return sign_extended * 4U;
}

std::uint32_t Decoder::immediate_value(const ImmediateKind kind, const std::uint16_t immediate) {
    switch (kind) {
    case ImmediateKind::None:
        return 0U;
    case ImmediateKind::Signed16:
        return (immediate & 0x8000U) == 0U ? immediate : 0xFFFF0000U | immediate;
    case ImmediateKind::ZeroExtended16:
        return immediate;
    case ImmediateKind::Upper16:
        return static_cast<std::uint32_t>(immediate) << 16U;
    }
    return 0U;
}

}  // namespace mini32
