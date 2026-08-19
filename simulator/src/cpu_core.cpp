#include "mini32/cpu_core.hpp"

#include "mini32/alu.hpp"

namespace mini32 {

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
        const BusReadResult result = bus_.read32(pc_);
        if (!result.ok()) {
            enter_fault(result.fault == BusFault::Misaligned
                            ? CpuFault::MisalignedInstructionFetch
                            : CpuFault::UnmappedInstructionFetch);
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
            pc_ += kInstructionAlignment;
            ++retired_instructions_;
            microstate_ = Microstate::Fetch;
        }
        return;
    }
    case Microstate::Writeback:
        if (control_signals_->reg_write) {
            const std::uint32_t writeback_value =
                control_signals_->writeback_source == WritebackSource::Memory ? memory_data_ : alu_result_;
            registers_.write(decoded_instruction_->rd, writeback_value);
        }
        // Sequential PC update is performed once, at successful instruction retirement.
        pc_ += kInstructionAlignment;
        ++retired_instructions_;
        microstate_ = control_signals_->halt ? Microstate::Halted : Microstate::Fetch;
        return;
    case Microstate::Halted:
    case Microstate::Fault:
        return;
    }
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
