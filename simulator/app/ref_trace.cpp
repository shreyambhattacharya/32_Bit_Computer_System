// Machine-readable Mini32 architectural retirement trace generator.
#include <array>
#include <charconv>
#include <cstdint>
#include <fstream>
#include <iomanip>
#include <iostream>
#include <limits>
#include <optional>
#include <sstream>
#include <string>
#include <string_view>
#include <vector>

#include "mini32/bus.hpp"
#include "mini32/cpu_core.hpp"
#include "mini32/debug_device.hpp"
#include "mini32/decoder.hpp"
#include "mini32/ram.hpp"
#include "mini32/rom.hpp"
#include "mini32/uart.hpp"

namespace {
constexpr std::size_t kDefaultInstructionLimit = 1'000'000U;

void usage(const char* executable) {
    std::cerr << "Usage: " << executable << " <rom-image> [--max-instructions N]\n";
}

bool parse_limit(const std::string_view text, std::size_t& value) {
    unsigned long long parsed{};
    const auto [end, error] = std::from_chars(text.data(), text.data() + text.size(), parsed);
    if (error != std::errc{} || end != text.data() + text.size() ||
        parsed > std::numeric_limits<std::size_t>::max()) return false;
    value = static_cast<std::size_t>(parsed);
    return true;
}

std::string hex32(const std::uint32_t value) {
    std::ostringstream output;
    output << std::nouppercase << std::hex << std::setw(8) << std::setfill('0') << value;
    return output.str();
}

const char* fault_name(const mini32::CpuFault fault) {
    using mini32::CpuFault;
    switch (fault) {
    case CpuFault::None: return "None";
    case CpuFault::MisalignedInstructionFetch: return "MisalignedInstructionFetch";
    case CpuFault::UnmappedInstructionFetch: return "UnmappedInstructionFetch";
    case CpuFault::NonExecutableInstructionFetch: return "NonExecutableInstructionFetch";
    case CpuFault::IllegalInstruction: return "IllegalInstruction";
    case CpuFault::MalformedInstruction: return "MalformedInstruction";
    case CpuFault::UnsupportedInstruction: return "UnsupportedInstruction";
    case CpuFault::MisalignedLoad: return "MisalignedLoad";
    case CpuFault::UnmappedLoad: return "UnmappedLoad";
    case CpuFault::MisalignedStore: return "MisalignedStore";
    case CpuFault::UnmappedStore: return "UnmappedStore";
    case CpuFault::ReadOnlyStore: return "ReadOnlyStore";
    }
    return "Unknown";
}

std::optional<std::vector<std::uint8_t>> load_image(const char* filename) {
    std::ifstream input(filename, std::ios::binary | std::ios::ate);
    if (!input.is_open()) return std::nullopt;
    const std::streamsize size = input.tellg();
    if (size < 0 || static_cast<std::uintmax_t>(size) > mini32::Rom::kSizeBytes || (size % 4) != 0) {
        return std::nullopt;
    }
    input.seekg(0);
    std::vector<std::uint8_t> image(static_cast<std::size_t>(size));
    if (!image.empty() && !input.read(reinterpret_cast<char*>(image.data()), size)) return std::nullopt;
    return image;
}

void emit_retire(const std::size_t index, const std::uint32_t pc, const std::uint32_t instruction,
                 const std::uint32_t next_pc, const std::optional<std::uint8_t> register_write,
                 const std::uint32_t register_value, const bool memory_write,
                 const std::uint32_t memory_address, const std::uint32_t memory_value) {
    std::cout << "{\"type\":\"retire\",\"index\":" << index
              << ",\"pc\":\"" << hex32(pc) << "\",\"instruction\":\"" << hex32(instruction)
              << "\",\"next_pc\":\"" << hex32(next_pc) << "\",\"reg_write\":"
              << (register_write.has_value() ? "true" : "false") << ",\"rd\":"
              << (register_write.has_value() ? static_cast<unsigned>(*register_write) : 0U)
              << ",\"reg_value\":\"" << hex32(register_value) << "\",\"mem_write\":"
              << (memory_write ? "true" : "false") << ",\"mem_addr\":\"" << hex32(memory_address)
              << "\",\"mem_value\":\"" << hex32(memory_value) << "\"}\n";
}
}  // namespace

int main(const int argc, char* argv[]) {
    if (argc != 2 && argc != 4) { usage(argv[0]); return 2; }
    std::size_t limit = kDefaultInstructionLimit;
    if (argc == 4 && (std::string_view(argv[2]) != "--max-instructions" || !parse_limit(argv[3], limit))) {
        usage(argv[0]); return 2;
    }
    const auto image = load_image(argv[1]);
    if (!image.has_value()) {
        std::cerr << "ROM image must exist, be <= 65536 bytes, and contain whole words\n";
        return 2;
    }

    mini32::Rom rom;
    rom.load_bytes(0U, *image);
    mini32::Ram ram;
    mini32::Uart uart;
    mini32::DebugDevice debug;
    mini32::Bus bus(rom, ram, uart, debug);
    mini32::CpuCore cpu(bus);

    for (std::size_t step = 0; step < limit && !cpu.halted() && !cpu.faulted(); ++step) {
        const std::uint32_t pc = cpu.program_counter();
        const mini32::BusReadResult fetched = bus.fetch32(pc);
        const std::uint32_t instruction = fetched.ok() ? fetched.data : 0U;
        std::array<std::uint32_t, mini32::kRegisterCount> before{};
        for (std::uint8_t index = 0; index < mini32::kRegisterCount; ++index) before[index] = cpu.registers().read(index);

        const std::size_t retired_before = cpu.retired_instructions();
        const mini32::StepResult step_result = cpu.step();
        (void)step_result;
        if (cpu.retired_instructions() == retired_before) continue;

        std::optional<std::uint8_t> changed_register;
        std::uint32_t register_value{};
        for (std::uint8_t index = 0; index < mini32::kRegisterCount; ++index) {
            const std::uint32_t after = cpu.registers().read(index);
            if (after == before[index]) continue;
            if (changed_register.has_value()) {
                std::cerr << "reference trace error: one instruction changed multiple registers\n";
                return 3;
            }
            changed_register = index;
            register_value = after;
        }

        bool memory_write = false;
        std::uint32_t memory_address{};
        std::uint32_t memory_value{};
        const mini32::DecodeResult decoded = mini32::Decoder::decode(instruction);
        if (decoded.ok() && decoded.instruction->opcode == mini32::Opcode::Sw) {
            memory_write = true;
            memory_address = before[decoded.instruction->rs1] +
                             mini32::Decoder::immediate_value(mini32::ImmediateKind::Signed16,
                                                              decoded.instruction->imm16);
            memory_value = before[decoded.instruction->rs2];
        }
        emit_retire(retired_before, pc, instruction, cpu.program_counter(), changed_register, register_value,
                    memory_write, memory_address, memory_value);
    }

    if (!cpu.halted() && !cpu.faulted()) {
        std::cerr << "reference trace instruction limit reached\n";
        return 3;
    }
    std::cout << "{\"type\":\"final\",\"status\":\"" << (cpu.halted() ? "halted" : "faulted")
              << "\",\"pc\":\"" << hex32(cpu.program_counter()) << "\",\"retired\":"
              << cpu.retired_instructions();
    if (cpu.faulted()) {
        const mini32::FaultInfo& fault = cpu.fault_info();
        std::cout << ",\"fault\":\"" << fault_name(fault.code) << "\",\"fault_pc\":\""
                  << hex32(fault.pc) << "\",\"fault_instruction\":\"" << hex32(fault.instruction)
                  << "\",\"fault_address_valid\":" << (fault.data_address.has_value() ? "true" : "false")
                  << ",\"fault_address\":\"" << hex32(fault.data_address.value_or(0U)) << "\"";
    }
    std::cout << "}\n";
    return 0;
}
