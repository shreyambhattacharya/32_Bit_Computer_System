#include "mini32/cpu_core.hpp"

#include "mini32/alu.hpp"

namespace mini32 {

CpuCore::CpuCore(const Bus& bus) : bus_(bus) {
    reset();
}

void CpuCore::reset() {
    registers_.reset();
    pc_ = 0U;
    instruction_register_ = 0U;
    operand_lhs_ = 0U;
    operand_rhs_ = 0U;
    alu_result_ = 0U;
    microstate_ = Microstate::Fetch;
    decoded_instruction_.reset();
    control_signals_.reset();
    retired_instructions_ = 0U;
    fault_info_ = {};
}

void CpuCore::tick() {
    switch (microstate_) {
    case Microstate::Fetch: {
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
                           ? Decoder::sign_extend_16(decoded_instruction_->imm16)
                           : registers_.read(decoded_instruction_->rs2);
        microstate_ = Microstate::Execute;
        return;
    }
    case Microstate::Execute:
        alu_result_ = Alu::execute(control_signals_->alu_operation, operand_lhs_, operand_rhs_);
        microstate_ = Microstate::Writeback;
        return;
    case Microstate::Writeback:
        if (control_signals_->reg_write) {
            registers_.write(decoded_instruction_->rd, alu_result_);
        }
        // Sequential PC update is performed once, at successful instruction retirement.
        pc_ += kInstructionAlignment;
        ++retired_instructions_;
        microstate_ = Microstate::Fetch;
        return;
    case Microstate::Memory:
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

void CpuCore::enter_fault(const CpuFault code) {
    fault_info_ = {.code = code, .pc = pc_, .instruction = instruction_register_};
    microstate_ = Microstate::Fault;
}

}  // namespace mini32
