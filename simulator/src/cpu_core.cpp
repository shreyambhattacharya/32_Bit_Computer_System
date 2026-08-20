#include "mini32/cpu_core.hpp"

#include "mini32/alu.hpp"

namespace mini32 {
namespace {

bool signed_less_than(const std::uint32_t lhs, const std::uint32_t rhs) {
    const bool lhs_negative = (lhs & 0x80000000U) != 0U;
    const bool rhs_negative = (rhs & 0x80000000U) != 0U;
    return lhs_negative != rhs_negative ? lhs_negative : lhs < rhs;
}

}  // namespace

CpuCore::CpuCore(Bus& bus) : bus_(bus) {
    reset();
}

void CpuCore::reset() {
    registers_.reset();
    pc_ = 0U;
    instruction_register_ = 0U;
    operand_lhs_ = 0U;
    operand_rhs_ = 0U;
    alu_result_ = 0U;
    store_data_ = 0U;
    memory_data_ = 0U;
    pc_plus_4_ = 0U;
    next_pc_ = 0U;
    microstate_ = Microstate::Fetch;
    decoded_instruction_.reset();
    control_signals_.reset();
    retired_instructions_ = 0U;
    fault_info_ = {};
}

void CpuCore::tick() {
    switch (microstate_) {
    case Microstate::Fetch: {
        instruction_register_ = 0U;
        pc_plus_4_ = pc_ + kInstructionAlignment;
        next_pc_ = pc_plus_4_;
        const BusReadResult result = bus_.fetch32(pc_);
        if (!result.ok()) {
            CpuFault fault = CpuFault::UnmappedInstructionFetch;
            if (result.fault == BusFault::Misaligned) {
                fault = CpuFault::MisalignedInstructionFetch;
            } else if (result.fault == BusFault::NonExecutable) {
                fault = CpuFault::NonExecutableInstructionFetch;
            }
            enter_fault(fault);
            return;
        }
        instruction_register_ = result.data;
        microstate_ = Microstate::Decode;
        return;
    }
    case Microstate::Decode: {
        DecodeResult result = Decoder::decode(instruction_register_);
        if (!result.ok()) {
            enter_fault(result.error == DecodeError::IllegalOpcode ? CpuFault::IllegalInstruction
                                                                    : CpuFault::MalformedInstruction);
            return;
        }

        decoded_instruction_ = result.instruction;
        control_signals_ = Decoder::control_for(decoded_instruction_->opcode);
        if (!control_signals_.has_value()) {
            enter_fault(CpuFault::UnsupportedInstruction);
            return;
        }

        operand_lhs_ = registers_.read(decoded_instruction_->rs1);
        operand_rhs_ = control_signals_->alu_src_immediate
                           ? Decoder::immediate_value(control_signals_->immediate_kind,
                                                      decoded_instruction_->imm16)
                           : registers_.read(decoded_instruction_->rs2);
        store_data_ = registers_.read(decoded_instruction_->rs2);
        microstate_ = Microstate::Execute;
        return;
    }
    case Microstate::Execute:
        alu_result_ = Alu::execute(control_signals_->alu_operation, operand_lhs_, operand_rhs_);
        if (control_signals_->control_flow == ControlFlowKind::ConditionalBranch) {
            const std::uint32_t branch_target =
                pc_plus_4_ + Decoder::branch_displacement(decoded_instruction_->imm16);
            retire_to(branch_taken() ? branch_target : pc_plus_4_);
            return;
        }
        if (control_signals_->control_flow == ControlFlowKind::RelativeJump) {
            next_pc_ = pc_plus_4_ + Decoder::jump_displacement(decoded_instruction_->imm26);
            if (!control_signals_->reg_write) {
                retire_to(next_pc_);
                return;
            }
        }
        if (control_signals_->control_flow == ControlFlowKind::RegisterJump) {
            retire_to(operand_lhs_);
            return;
        }
        microstate_ = control_signals_->memory_operation == MemoryOperation::None
                          ? Microstate::Writeback
                          : Microstate::Memory;
        return;
    case Microstate::Memory: {
        if (control_signals_->memory_operation == MemoryOperation::Load) {
            const BusReadResult result = bus_.read32(alu_result_);
            if (!result.ok()) {
                enter_fault(result.fault == BusFault::Misaligned ? CpuFault::MisalignedLoad
                                                                  : CpuFault::UnmappedLoad,
                            alu_result_);
                return;
            }
            memory_data_ = result.data;
            microstate_ = Microstate::Writeback;
            return;
        }
        if (control_signals_->memory_operation == MemoryOperation::Store) {
            const BusWriteResult result = bus_.write32(alu_result_, store_data_);
            if (!result.ok()) {
                CpuFault fault = CpuFault::UnmappedStore;
                if (result.fault == BusFault::Misaligned) {
                    fault = CpuFault::MisalignedStore;
                } else if (result.fault == BusFault::ReadOnly) {
                    fault = CpuFault::ReadOnlyStore;
                }
                enter_fault(fault, alu_result_);
                return;
            }
            retire_to(next_pc_);
        }
        return;
    }
    case Microstate::Writeback:
        if (control_signals_->reg_write) {
            std::uint32_t writeback_value = alu_result_;
            if (control_signals_->writeback_source == WritebackSource::Memory) {
                writeback_value = memory_data_;
            } else if (control_signals_->writeback_source == WritebackSource::PcPlus4) {
                writeback_value = pc_plus_4_;
            }
            const std::uint8_t destination =
                control_signals_->register_destination == RegisterDestination::ReturnAddress
                    ? 31U
                    : decoded_instruction_->rd;
            registers_.write(destination, writeback_value);
        }
        pc_ = next_pc_;
        ++retired_instructions_;
        bus_.retire_tick();
        microstate_ = control_signals_->halt ? Microstate::Halted : Microstate::Fetch;
        return;
    case Microstate::Halted:
    case Microstate::Fault:
        return;
    }
}

bool CpuCore::branch_taken() const {
    switch (control_signals_->branch_predicate) {
    case BranchPredicate::Equal:
        return operand_lhs_ == operand_rhs_;
    case BranchPredicate::NotEqual:
        return operand_lhs_ != operand_rhs_;
    case BranchPredicate::SignedLessThan:
        return signed_less_than(operand_lhs_, operand_rhs_);
    case BranchPredicate::SignedGreaterEqual:
        return !signed_less_than(operand_lhs_, operand_rhs_);
    case BranchPredicate::None:
        return false;
    }
    return false;
}

void CpuCore::retire_to(const std::uint32_t next_pc) {
    pc_ = next_pc;
    ++retired_instructions_;
    bus_.retire_tick();
    microstate_ = Microstate::Fetch;
}

StepResult CpuCore::step() {
    if (halted()) {
        return StepResult::Halted;
    }
    if (faulted()) {
        return StepResult::Faulted;
    }

    const std::size_t retired_before = retired_instructions_;
    while (!halted() && !faulted() && retired_instructions_ == retired_before) {
        tick();
    }
    return faulted() ? StepResult::Faulted
                     : (halted() ? StepResult::Halted : StepResult::Retired);
}

void CpuCore::enter_fault(const CpuFault code, const std::optional<std::uint32_t> data_address) {
    fault_info_ = {.code = code,
                   .pc = pc_,
                   .instruction = instruction_register_,
                   .data_address = data_address};
    microstate_ = Microstate::Fault;
}

}  // namespace mini32
