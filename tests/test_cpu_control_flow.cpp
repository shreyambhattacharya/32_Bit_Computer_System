#include <cstdint>
#include <initializer_list>

#include "instruction_encoding.hpp"
#include "mini32/bus.hpp"
#include "mini32/cpu_core.hpp"
#include "mini32/ram.hpp"
#include "mini32/rom.hpp"
#include "test_support.hpp"

namespace {

void load_program(mini32::Rom& rom, const std::initializer_list<std::uint32_t> program) {
    std::uint32_t address = 0U;
    for (const std::uint32_t instruction : program) {
        rom.load32(address, instruction);
        address += 4U;
    }
}

void run_until_halted(mini32::CpuCore& cpu) {
    for (std::uint32_t instructions = 0U; instructions < 100U && !cpu.halted(); ++instructions) {
        static_cast<void>(cpu.step());
    }
    CHECK(cpu.halted());
}

std::uint32_t branch_pc(const mini32::Opcode opcode, const std::uint16_t lhs,
                        const std::uint16_t rhs) {
    mini32::Rom rom;
    mini32::Ram ram;
    load_program(rom, {
        test_encoding::encode_i(mini32::Opcode::Addi, 1U, 0U, lhs),
        test_encoding::encode_i(mini32::Opcode::Addi, 2U, 0U, rhs),
        test_encoding::encode_b(opcode, 1U, 2U, 1U),
        0U,
        static_cast<std::uint32_t>(mini32::Opcode::Halt) << 26U,
    });
    mini32::Bus bus(rom, ram);
    mini32::CpuCore cpu(bus);
    static_cast<void>(cpu.step());
    static_cast<void>(cpu.step());
    CHECK(cpu.step() == mini32::StepResult::Retired);
    CHECK(cpu.retired_instructions() == 3U);
    return cpu.program_counter();
}

}  // namespace

int main() {
    CHECK(branch_pc(mini32::Opcode::Beq, 5U, 5U) == 16U);
    CHECK(branch_pc(mini32::Opcode::Beq, 5U, 4U) == 12U);
    CHECK(branch_pc(mini32::Opcode::Bne, 5U, 4U) == 16U);
    CHECK(branch_pc(mini32::Opcode::Bne, 5U, 5U) == 12U);
    CHECK(branch_pc(mini32::Opcode::Blt, 1U, 2U) == 16U);
    CHECK(branch_pc(mini32::Opcode::Blt, 2U, 1U) == 12U);
    CHECK(branch_pc(mini32::Opcode::Blt, 0xFFFFU, 0U) == 16U);
    CHECK(branch_pc(mini32::Opcode::Blt, 0U, 0xFFFFU) == 12U);
    CHECK(branch_pc(mini32::Opcode::Bge, 5U, 5U) == 16U);
    CHECK(branch_pc(mini32::Opcode::Bge, 5U, 4U) == 16U);
    CHECK(branch_pc(mini32::Opcode::Bge, 4U, 5U) == 12U);
    CHECK(branch_pc(mini32::Opcode::Bge, 0U, 0xFFFFU) == 16U);

    {
        mini32::Rom rom;
        mini32::Ram ram;
        load_program(rom, {
            test_encoding::encode_i(mini32::Opcode::Lui, 1U, 0U, 0x8000U),
            test_encoding::encode_i(mini32::Opcode::Addi, 2U, 0U, 0U),
            test_encoding::encode_b(mini32::Opcode::Blt, 1U, 2U, 1U),
            0U,
            static_cast<std::uint32_t>(mini32::Opcode::Halt) << 26U,
        });
        mini32::Bus bus(rom, ram);
        mini32::CpuCore cpu(bus);
        static_cast<void>(cpu.step());
        static_cast<void>(cpu.step());
        CHECK(cpu.step() == mini32::StepResult::Retired);
        CHECK(cpu.program_counter() == 16U);
    }

    {
        mini32::Rom rom;
        mini32::Ram ram;
        load_program(rom, {
            test_encoding::encode_i(mini32::Opcode::Addi, 1U, 0U, 5U),
            test_encoding::encode_i(mini32::Opcode::Addi, 2U, 0U, 5U),
            test_encoding::encode_b(mini32::Opcode::Beq, 1U, 2U, 1U),
            test_encoding::encode_i(mini32::Opcode::Addi, 3U, 0U, 99U),
            test_encoding::encode_i(mini32::Opcode::Addi, 3U, 0U, 42U),
            static_cast<std::uint32_t>(mini32::Opcode::Halt) << 26U,
        });
        mini32::Bus bus(rom, ram);
        mini32::CpuCore cpu(bus);
        run_until_halted(cpu);
        CHECK(cpu.registers().read(3U) == 42U);
        CHECK(cpu.retired_instructions() == 5U);
    }

    {
        mini32::Rom rom;
        mini32::Ram ram;
        load_program(rom, {
            test_encoding::encode_i(mini32::Opcode::Addi, 1U, 0U, 3U),
            test_encoding::encode_i(mini32::Opcode::Addi, 2U, 0U, 0U),
            test_encoding::encode_r(mini32::Opcode::Add, 2U, 2U, 1U),
            test_encoding::encode_i(mini32::Opcode::Addi, 1U, 1U, 0xFFFFU),
            test_encoding::encode_b(mini32::Opcode::Bne, 1U, 0U, 0xFFFDU),
            static_cast<std::uint32_t>(mini32::Opcode::Halt) << 26U,
        });
        mini32::Bus bus(rom, ram);
        mini32::CpuCore cpu(bus);
        run_until_halted(cpu);
        CHECK(cpu.registers().read(1U) == 0U);
        CHECK(cpu.registers().read(2U) == 6U);
        CHECK(cpu.retired_instructions() == 12U);
    }

    {
        mini32::Rom rom;
        mini32::Ram ram;
        load_program(rom, {
            test_encoding::encode_j(mini32::Opcode::J, 1U),
            test_encoding::encode_i(mini32::Opcode::Addi, 1U, 0U, 99U),
            test_encoding::encode_i(mini32::Opcode::Addi, 1U, 0U, 42U),
            static_cast<std::uint32_t>(mini32::Opcode::Halt) << 26U,
        });
        mini32::Bus bus(rom, ram);
        mini32::CpuCore cpu(bus);
        CHECK(cpu.step() == mini32::StepResult::Retired);
        CHECK(cpu.program_counter() == 8U);
        run_until_halted(cpu);
        CHECK(cpu.registers().read(1U) == 42U);
    }

    {
        mini32::Rom rom;
        mini32::Ram ram;
        load_program(rom, {0U, test_encoding::encode_j(mini32::Opcode::J, 0x03FFFFFFU)});
        mini32::Bus bus(rom, ram);
        mini32::CpuCore cpu(bus);
        CHECK(cpu.step() == mini32::StepResult::Retired);
        CHECK(cpu.step() == mini32::StepResult::Retired);
        CHECK(cpu.program_counter() == 4U);
    }

    {
        mini32::Rom rom;
        mini32::Ram ram;
        load_program(rom, {
            test_encoding::encode_i(mini32::Opcode::Addi, 1U, 0U, 3U),
            test_encoding::encode_j(mini32::Opcode::Jal, 2U),
            test_encoding::encode_i(mini32::Opcode::Addi, 2U, 0U, 9U),
            static_cast<std::uint32_t>(mini32::Opcode::Halt) << 26U,
            test_encoding::encode_i(mini32::Opcode::Addi, 3U, 0U, 7U),
            test_encoding::encode_jr(31U),
        });
        mini32::Bus bus(rom, ram);
        mini32::CpuCore cpu(bus);
        run_until_halted(cpu);
        CHECK(cpu.registers().read(1U) == 3U);
        CHECK(cpu.registers().read(2U) == 9U);
        CHECK(cpu.registers().read(3U) == 7U);
        CHECK(cpu.registers().read(31U) == 8U);
        CHECK(cpu.registers().read(0U) == 0U);
        CHECK(cpu.retired_instructions() == 6U);
    }

    {
        mini32::Rom rom;
        mini32::Ram ram;
        load_program(rom, {test_encoding::encode_j(mini32::Opcode::Jal, 1U)});
        mini32::Bus bus(rom, ram);
        mini32::CpuCore cpu(bus);
        cpu.tick(); CHECK(cpu.microstate() == mini32::Microstate::Decode);
        cpu.tick(); CHECK(cpu.microstate() == mini32::Microstate::Execute);
        cpu.tick(); CHECK(cpu.microstate() == mini32::Microstate::Writeback);
        CHECK(cpu.registers().read(31U) == 0U);
        cpu.tick(); CHECK(cpu.microstate() == mini32::Microstate::Fetch);
        CHECK(cpu.program_counter() == 8U);
        CHECK(cpu.registers().read(31U) == 4U);
        CHECK(cpu.retired_instructions() == 1U);
    }

    {
        mini32::Rom rom;
        mini32::Ram ram;
        load_program(rom, {
            test_encoding::encode_i(mini32::Opcode::Addi, 1U, 0U, 2U),
            test_encoding::encode_jr(1U),
        });
        mini32::Bus bus(rom, ram);
        mini32::CpuCore cpu(bus);
        CHECK(cpu.step() == mini32::StepResult::Retired);
        CHECK(cpu.step() == mini32::StepResult::Retired);
        CHECK(cpu.program_counter() == 2U);
        CHECK(cpu.step() == mini32::StepResult::Faulted);
        CHECK(cpu.fault_info().code == mini32::CpuFault::MisalignedInstructionFetch);
    }

    {
        mini32::Rom rom;
        mini32::Ram ram;
        load_program(rom, {
            test_encoding::encode_i(mini32::Opcode::Lui, 1U, 0U, 0x1000U),
            test_encoding::encode_jr(1U),
        });
        mini32::Bus bus(rom, ram);
        mini32::CpuCore cpu(bus);
        CHECK(cpu.step() == mini32::StepResult::Retired);
        CHECK(cpu.step() == mini32::StepResult::Retired);
        CHECK(cpu.program_counter() == mini32::Ram::kBaseAddress);
        CHECK(cpu.step() == mini32::StepResult::Faulted);
        CHECK(cpu.fault_info().code == mini32::CpuFault::NonExecutableInstructionFetch);
        CHECK(cpu.retired_instructions() == 2U);
        cpu.tick();
        CHECK(cpu.faulted());
    }
}
