#pragma once

#include <cstddef>
#include <cstdint>
#include <optional>

#include "mini32/bus.hpp"
#include "mini32/decoder.hpp"
#include "mini32/register_file.hpp"

namespace mini32 {

enum class Microstate : std::uint8_t {
    Fetch,
    Decode,
    Execute,
    Memory,
    Writeback,
    Halted,
    Fault,
};

enum class CpuFault : std::uint8_t {
    None,
    MisalignedInstructionFetch,
    UnmappedInstructionFetch,
    NonExecutableInstructionFetch,
    IllegalInstruction,
    MalformedInstruction,
    UnsupportedInstruction,
    MisalignedLoad,
    MisalignedStore,
    UnmappedLoad,
    UnmappedStore,
    ReadOnlyStore,
};

struct FaultInfo {
    CpuFault code{CpuFault::None};
    std::uint32_t pc{};
    std::uint32_t instruction{};
    std::optional<std::uint32_t> data_address{};
};

enum class StepResult : std::uint8_t {
    Retired,
    Halted,
    Faulted,
};

class CpuCore {
public:
    explicit CpuCore(Bus& bus);

    void reset();
    void tick();
    [[nodiscard]] StepResult step();

    [[nodiscard]] const RegisterFile& registers() const { return registers_; }
    [[nodiscard]] std::uint32_t program_counter() const { return pc_; }
    [[nodiscard]] Microstate microstate() const { return microstate_; }
    [[nodiscard]] std::size_t retired_instructions() const { return retired_instructions_; }
    [[nodiscard]] bool faulted() const { return microstate_ == Microstate::Fault; }
    [[nodiscard]] bool halted() const { return microstate_ == Microstate::Halted; }
    [[nodiscard]] const FaultInfo& fault_info() const { return fault_info_; }

private:
    void enter_fault(CpuFault code, std::optional<std::uint32_t> data_address = std::nullopt);
    [[nodiscard]] bool branch_taken() const;
    void retire_to(std::uint32_t next_pc);

    Bus& bus_;
    RegisterFile registers_{};
    std::uint32_t pc_{};
    std::uint32_t instruction_register_{};
    std::uint32_t operand_lhs_{};
    std::uint32_t operand_rhs_{};
    std::uint32_t alu_result_{};
    std::uint32_t store_data_{};
    std::uint32_t memory_data_{};
    std::uint32_t pc_plus_4_{};
    std::uint32_t next_pc_{};
    Microstate microstate_{Microstate::Fetch};
    std::optional<DecodedInstruction> decoded_instruction_{};
    std::optional<ControlSignals> control_signals_{};
    std::size_t retired_instructions_{};
    FaultInfo fault_info_{};
};

}  // namespace mini32
