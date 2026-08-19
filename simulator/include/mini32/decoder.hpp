#pragma once

#include <cstdint>
#include <optional>

#include "mini32/alu.hpp"
#include "mini32/isa.hpp"

namespace mini32 {

enum class DecodeError : std::uint8_t {
    None,
    IllegalOpcode,
    MalformedEncoding,
};

struct DecodedInstruction {
    Opcode opcode{};
    std::uint8_t rd{};
    std::uint8_t rs1{};
    std::uint8_t rs2{};
    std::uint16_t imm16{};
    std::uint32_t imm26{};
};

struct DecodeResult {
    std::optional<DecodedInstruction> instruction{};
    DecodeError error{DecodeError::None};

    [[nodiscard]] bool ok() const { return error == DecodeError::None; }
};

enum class WritebackSource : std::uint8_t {
    Alu,
    Memory,
    PcPlus4,
};

enum class RegisterDestination : std::uint8_t {
    DecodedRd,
    ReturnAddress,
};

enum class ControlFlowKind : std::uint8_t {
    Sequential,
    ConditionalBranch,
    RelativeJump,
    RegisterJump,
};

enum class BranchPredicate : std::uint8_t {
    None,
    Equal,
    NotEqual,
    SignedLessThan,
    SignedGreaterEqual,
};

enum class ImmediateKind : std::uint8_t {
    None,
    Signed16,
    ZeroExtended16,
    Upper16,
};

enum class MemoryOperation : std::uint8_t {
    None,
    Load,
    Store,
};

struct ControlSignals {
    bool reg_write{};
    bool alu_src_immediate{};
    AluOperation alu_operation{AluOperation::Add};
    WritebackSource writeback_source{WritebackSource::Alu};
    RegisterDestination register_destination{RegisterDestination::DecodedRd};
    ImmediateKind immediate_kind{ImmediateKind::None};
    MemoryOperation memory_operation{MemoryOperation::None};
    ControlFlowKind control_flow{ControlFlowKind::Sequential};
    BranchPredicate branch_predicate{BranchPredicate::None};
    bool halt{};
};

class Decoder {
public:
    [[nodiscard]] static DecodeResult decode(std::uint32_t instruction);
    [[nodiscard]] static std::optional<ControlSignals> control_for(Opcode opcode);
    [[nodiscard]] static std::uint32_t immediate_value(ImmediateKind kind,
                                                        std::uint16_t immediate);
    [[nodiscard]] static std::uint32_t branch_displacement(std::uint16_t immediate);
    [[nodiscard]] static std::uint32_t jump_displacement(std::uint32_t immediate);
};

}  // namespace mini32
