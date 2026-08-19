#include <array>
#include <cstdint>

#include "mini32/bus.hpp"
#include "mini32/cpu_core.hpp"
#include "mini32/isa.hpp"
#include "mini32/rom.hpp"
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

void load_program(mini32::Rom& rom, const std::initializer_list<std::uint32_t> program) {
    std::uint32_t address = 0U;
    for (const std::uint32_t instruction : program) {
        rom.load32(address, instruction);
        address += 4U;
    }
}

}  // namespace

int main() {
    mini32::Rom rom;
    load_program(rom, {encode_i(mini32::Opcode::Addi, 1U, 0U, 7U)});
    const mini32::Bus bus(rom);
    mini32::CpuCore cpu(bus);

    CHECK(cpu.microstate() == mini32::Microstate::Fetch);
    cpu.tick();
    CHECK(cpu.microstate() == mini32::Microstate::Decode);
    CHECK(cpu.registers().read(1U) == 0U);
    cpu.tick();
    CHECK(cpu.microstate() == mini32::Microstate::Execute);
    CHECK(cpu.registers().read(1U) == 0U);
    cpu.tick();
    CHECK(cpu.microstate() == mini32::Microstate::Writeback);
    CHECK(cpu.registers().read(1U) == 0U);
    cpu.tick();
    CHECK(cpu.microstate() == mini32::Microstate::Fetch);
    CHECK(cpu.registers().read(1U) == 7U);
    CHECK(cpu.program_counter() == 4U);
    CHECK(cpu.retired_instructions() == 1U);

    rom = mini32::Rom{};
    load_program(rom, {
        0U,
        encode_i(mini32::Opcode::Addi, 1U, 0U, 7U),
        encode_i(mini32::Opcode::Addi, 2U, 0U, 5U),
        encode_r(mini32::Opcode::Add, 3U, 1U, 2U),
        encode_r(mini32::Opcode::Sub, 4U, 3U, 2U),
    });
    mini32::CpuCore integration_cpu(bus);
    for (std::uint32_t instruction = 0U; instruction < 5U; ++instruction) {
        CHECK(integration_cpu.step() == mini32::StepResult::Retired);
    }
    CHECK(integration_cpu.registers().read(0U) == 0U);
    CHECK(integration_cpu.registers().read(1U) == 7U);
    CHECK(integration_cpu.registers().read(2U) == 5U);
    CHECK(integration_cpu.registers().read(3U) == 12U);
    CHECK(integration_cpu.registers().read(4U) == 7U);
    CHECK(integration_cpu.program_counter() == 0x14U);
    CHECK(integration_cpu.retired_instructions() == 5U);
    CHECK(integration_cpu.microstate() == mini32::Microstate::Fetch);
    CHECK(!integration_cpu.faulted());

    rom = mini32::Rom{};
    load_program(rom, {
        encode_i(mini32::Opcode::Addi, 5U, 0U, 0xFFFFU),
        encode_i(mini32::Opcode::Addi, 0U, 0U, 123U),
    });
    mini32::CpuCore immediate_cpu(bus);
    CHECK(immediate_cpu.step() == mini32::StepResult::Retired);
    CHECK(immediate_cpu.registers().read(5U) == 0xFFFFFFFFU);
    CHECK(immediate_cpu.step() == mini32::StepResult::Retired);
    CHECK(immediate_cpu.registers().read(0U) == 0U);

    rom = mini32::Rom{};
    rom.load32(0U, 0xFC000000U);
    mini32::CpuCore illegal_cpu(bus);
    CHECK(illegal_cpu.step() == mini32::StepResult::Faulted);
    CHECK(illegal_cpu.fault_info().code == mini32::CpuFault::IllegalInstruction);
    illegal_cpu.tick();
    CHECK(illegal_cpu.faulted());

    rom = mini32::Rom{};
    rom.load32(0U, encode_r(mini32::Opcode::Add, 1U, 0U, 0U) | 1U);
    mini32::CpuCore malformed_cpu(bus);
    CHECK(malformed_cpu.step() == mini32::StepResult::Faulted);
    CHECK(malformed_cpu.fault_info().code == mini32::CpuFault::MalformedInstruction);
    malformed_cpu.tick();
    CHECK(malformed_cpu.faulted());

    rom = mini32::Rom{};
    mini32::CpuCore unmapped_cpu(bus);
    for (std::uint32_t instruction = 0U; instruction < 16384U; ++instruction) {
        CHECK(unmapped_cpu.step() == mini32::StepResult::Retired);
    }
    CHECK(unmapped_cpu.program_counter() == 0x00010000U);
    CHECK(unmapped_cpu.step() == mini32::StepResult::Faulted);
    CHECK(unmapped_cpu.fault_info().code == mini32::CpuFault::UnmappedInstructionFetch);
}
