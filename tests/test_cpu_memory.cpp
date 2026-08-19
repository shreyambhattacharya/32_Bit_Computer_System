#include <cstdint>
#include <initializer_list>

#include "mini32/bus.hpp"
#include "mini32/cpu_core.hpp"
#include "mini32/isa.hpp"
#include "mini32/ram.hpp"
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

std::uint32_t encode_s(const std::uint8_t rs2, const std::uint8_t rs1,
                       const std::uint16_t immediate) {
    return (static_cast<std::uint32_t>(mini32::Opcode::Sw) << 26U) |
           (static_cast<std::uint32_t>(rs2) << 21U) |
           (static_cast<std::uint32_t>(rs1) << 16U) | immediate;
}

void load_program(mini32::Rom& rom, const std::initializer_list<std::uint32_t> program) {
    std::uint32_t address = 0U;
    for (const std::uint32_t instruction : program) {
        rom.load32(address, instruction);
        address += 4U;
    }
}

void retire(mini32::CpuCore& cpu, const std::uint32_t count) {
    for (std::uint32_t index = 0U; index < count; ++index) {
        CHECK(cpu.step() == mini32::StepResult::Retired);
    }
}

}  // namespace

int main() {
    {
        mini32::Rom rom;
        mini32::Ram ram;
        load_program(rom, {
            encode_i(mini32::Opcode::Lui, 1U, 0U, 0x1000U),
            encode_i(mini32::Opcode::Addi, 2U, 0U, 42U),
            encode_s(2U, 1U, 0U),
            encode_i(mini32::Opcode::Lw, 3U, 1U, 0U),
            static_cast<std::uint32_t>(mini32::Opcode::Halt) << 26U,
        });
        mini32::Bus bus(rom, ram);
        mini32::CpuCore cpu(bus);

        retire(cpu, 2U);
        cpu.tick(); CHECK(cpu.microstate() == mini32::Microstate::Decode);
        cpu.tick(); CHECK(cpu.microstate() == mini32::Microstate::Execute);
        cpu.tick(); CHECK(cpu.microstate() == mini32::Microstate::Memory);
        cpu.tick(); CHECK(cpu.microstate() == mini32::Microstate::Fetch);
        CHECK(ram.read32(mini32::Ram::kBaseAddress).data == 42U);
        CHECK(cpu.retired_instructions() == 3U);

        cpu.tick(); CHECK(cpu.microstate() == mini32::Microstate::Decode);
        cpu.tick(); CHECK(cpu.microstate() == mini32::Microstate::Execute);
        cpu.tick(); CHECK(cpu.microstate() == mini32::Microstate::Memory);
        CHECK(cpu.registers().read(3U) == 0U);
        cpu.tick(); CHECK(cpu.microstate() == mini32::Microstate::Writeback);
        CHECK(cpu.registers().read(3U) == 0U);
        cpu.tick(); CHECK(cpu.microstate() == mini32::Microstate::Fetch);
        CHECK(cpu.registers().read(3U) == 42U);
        CHECK(cpu.step() == mini32::StepResult::Halted);
        CHECK(cpu.halted());
        CHECK(cpu.program_counter() == 0x14U);
        CHECK(cpu.retired_instructions() == 5U);
        CHECK(cpu.step() == mini32::StepResult::Halted);
        cpu.tick();
        CHECK(cpu.halted());
        cpu.reset();
        CHECK(ram.read32(mini32::Ram::kBaseAddress).data == 42U);
    }

    {
        mini32::Rom rom;
        mini32::Ram ram;
        load_program(rom, {
            encode_i(mini32::Opcode::Lui, 1U, 0U, 0x1000U),
            encode_i(mini32::Opcode::Addi, 1U, 1U, 8U),
            encode_i(mini32::Opcode::Addi, 2U, 0U, 99U),
            encode_s(2U, 1U, 0xFFFCU),
            encode_i(mini32::Opcode::Lw, 3U, 1U, 0xFFFCU),
            static_cast<std::uint32_t>(mini32::Opcode::Halt) << 26U,
        });
        mini32::Bus bus(rom, ram);
        mini32::CpuCore cpu(bus);
        retire(cpu, 5U);
        CHECK(cpu.registers().read(3U) == 99U);
        CHECK(ram.read32(mini32::Ram::kBaseAddress + 4U).data == 99U);
    }

    {
        mini32::Rom rom;
        mini32::Ram ram;
        load_program(rom, {
            encode_i(mini32::Opcode::Addi, 1U, 0U, 0xFF00U),
            encode_i(mini32::Opcode::Andi, 2U, 1U, 0x8000U),
            encode_i(mini32::Opcode::Ori, 3U, 0U, 0xFFFFU),
            encode_i(mini32::Opcode::Xori, 4U, 3U, 0xFFFFU),
            encode_i(mini32::Opcode::Lui, 5U, 0U, 0x2000U),
            encode_i(mini32::Opcode::Addi, 12U, 0U, 16U),
            encode_r(mini32::Opcode::And, 6U, 1U, 3U),
            encode_r(mini32::Opcode::Or, 7U, 2U, 4U),
            encode_r(mini32::Opcode::Xor, 8U, 3U, 1U),
            encode_r(mini32::Opcode::Slt, 9U, 1U, 0U),
            encode_r(mini32::Opcode::Shl, 10U, 3U, 12U),
            encode_r(mini32::Opcode::Shr, 11U, 10U, 12U),
        });
        mini32::Bus bus(rom, ram);
        mini32::CpuCore cpu(bus);
        retire(cpu, 12U);
        CHECK(cpu.registers().read(2U) == 0x8000U);
        CHECK(cpu.registers().read(3U) == 0xFFFFU);
        CHECK(cpu.registers().read(4U) == 0U);
        CHECK(cpu.registers().read(5U) == 0x20000000U);
        CHECK(cpu.registers().read(6U) == 0xFF00U);
        CHECK(cpu.registers().read(7U) == 0x8000U);
        CHECK(cpu.registers().read(8U) == 0xFFFF00FFU);
        CHECK(cpu.registers().read(9U) == 1U);
        CHECK(cpu.registers().read(10U) == 0xFFFF0000U);
        CHECK(cpu.registers().read(11U) == 0xFFFFU);
    }

    const auto verify_fault = [](const std::initializer_list<std::uint32_t> program,
                                 const mini32::CpuFault expected, const std::uint32_t address,
                                 const std::uint32_t expected_pc) {
        mini32::Rom rom;
        mini32::Ram ram;
        load_program(rom, program);
        mini32::Bus bus(rom, ram);
        mini32::CpuCore cpu(bus);
        while (!cpu.faulted()) {
            static_cast<void>(cpu.step());
        }
        CHECK(cpu.fault_info().code == expected);
        CHECK(cpu.fault_info().data_address.has_value());
        CHECK(*cpu.fault_info().data_address == address);
        CHECK(cpu.program_counter() == expected_pc);
        CHECK(ram.read32(mini32::Ram::kBaseAddress).data == 0U);
        const auto retired = cpu.retired_instructions();
        cpu.tick();
        CHECK(cpu.faulted());
        CHECK(cpu.retired_instructions() == retired);
    };

    verify_fault({
                     encode_i(mini32::Opcode::Lui, 1U, 0U, 0x1000U),
                     encode_i(mini32::Opcode::Addi, 1U, 1U, 2U),
                     encode_i(mini32::Opcode::Lw, 2U, 1U, 0U),
                 }, mini32::CpuFault::MisalignedLoad, 0x10000002U, 8U);
    verify_fault({
                     encode_i(mini32::Opcode::Lui, 1U, 0U, 0x1000U),
                     encode_i(mini32::Opcode::Addi, 1U, 1U, 2U),
                     encode_i(mini32::Opcode::Addi, 2U, 0U, 7U),
                     encode_s(2U, 1U, 0U),
                 }, mini32::CpuFault::MisalignedStore, 0x10000002U, 12U);
    verify_fault({
                     encode_i(mini32::Opcode::Addi, 1U, 0U, 7U),
                     encode_s(1U, 0U, 0U),
                 }, mini32::CpuFault::ReadOnlyStore, 0U, 4U);
    verify_fault({
                     encode_i(mini32::Opcode::Lui, 1U, 0U, 0x3000U),
                     encode_i(mini32::Opcode::Lw, 2U, 1U, 0U),
                 }, mini32::CpuFault::UnmappedLoad, 0x30000000U, 4U);
    verify_fault({
                     encode_i(mini32::Opcode::Lui, 1U, 0U, 0x3000U),
                     encode_i(mini32::Opcode::Addi, 2U, 0U, 1U),
                     encode_s(2U, 1U, 0U),
                 }, mini32::CpuFault::UnmappedStore, 0x30000000U, 8U);
}
