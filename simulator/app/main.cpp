#include <charconv>
#include <cstdint>
#include <fstream>
#include <iomanip>
#include <iostream>
#include <limits>
#include <string>
#include <string_view>
#include <vector>

#ifdef _WIN32
#include <fcntl.h>
#include <io.h>
#endif

#include "mini32/bus.hpp"
#include "mini32/cpu_core.hpp"
#include "mini32/debug_device.hpp"
#include "mini32/ram.hpp"
#include "mini32/rom.hpp"
#include "mini32/uart.hpp"

namespace {

constexpr std::size_t kDefaultInstructionLimit = 1'000'000U;

void print_usage(const char* executable) {
    std::cerr << "Usage: " << executable << " <rom-image> [--max-instructions N]\n";
}

bool parse_limit(const std::string_view text, std::size_t& limit) {
    unsigned long long parsed{};
    const auto [end, error] = std::from_chars(text.data(), text.data() + text.size(), parsed);
    if (error != std::errc{} || end != text.data() + text.size() ||
        parsed > std::numeric_limits<std::size_t>::max()) {
        return false;
    }
    limit = static_cast<std::size_t>(parsed);
    return true;
}

const char* fault_name(const mini32::CpuFault fault) {
    switch (fault) {
    case mini32::CpuFault::None: return "None";
    case mini32::CpuFault::MisalignedInstructionFetch: return "MisalignedInstructionFetch";
    case mini32::CpuFault::UnmappedInstructionFetch: return "UnmappedInstructionFetch";
    case mini32::CpuFault::NonExecutableInstructionFetch: return "NonExecutableInstructionFetch";
    case mini32::CpuFault::IllegalInstruction: return "IllegalInstruction";
    case mini32::CpuFault::MalformedInstruction: return "MalformedInstruction";
    case mini32::CpuFault::UnsupportedInstruction: return "UnsupportedInstruction";
    case mini32::CpuFault::MisalignedLoad: return "MisalignedLoad";
    case mini32::CpuFault::MisalignedStore: return "MisalignedStore";
    case mini32::CpuFault::UnmappedLoad: return "UnmappedLoad";
    case mini32::CpuFault::UnmappedStore: return "UnmappedStore";
    case mini32::CpuFault::ReadOnlyStore: return "ReadOnlyStore";
    }
    return "Unknown";
}

void print_hex(const char* label, const std::uint32_t value) {
    std::cerr << label << "0x" << std::hex << std::setw(8) << std::setfill('0') << value
              << std::dec << std::setfill(' ') << '\n';
}

}  // namespace

int main(const int argc, char* argv[]) {
#ifdef _WIN32
    // UART is a byte device: do not translate a guest '\n' into host CRLF.
    if (_setmode(_fileno(stdout), _O_BINARY) == -1) {
        std::cerr << "unable to configure UART stdout sink\n";
        return 2;
    }
#endif

    if (argc != 2 && argc != 4) {
        print_usage(argv[0]);
        return 2;
    }

    std::size_t instruction_limit = kDefaultInstructionLimit;
    if (argc == 4) {
        if (std::string_view(argv[2]) != "--max-instructions" ||
            !parse_limit(argv[3], instruction_limit)) {
            print_usage(argv[0]);
            return 2;
        }
    }

    std::ifstream input(argv[1], std::ios::binary | std::ios::ate);
    if (!input.is_open()) {
        std::cerr << "unable to open ROM image: " << argv[1] << '\n';
        return 2;
    }
    const std::streamsize image_size = input.tellg();
    if (image_size < 0 || static_cast<std::uintmax_t>(image_size) > mini32::Rom::kSizeBytes) {
        std::cerr << "ROM image must be at most " << mini32::Rom::kSizeBytes << " bytes\n";
        return 2;
    }
    if ((image_size % 4) != 0) {
        std::cerr << "ROM image size must be divisible by 4 bytes\n";
        return 2;
    }
    input.seekg(0);
    std::vector<std::uint8_t> image(static_cast<std::size_t>(image_size));
    if (!image.empty() && !input.read(reinterpret_cast<char*>(image.data()), image_size)) {
        std::cerr << "unable to read ROM image: " << argv[1] << '\n';
        return 2;
    }

    mini32::Rom rom;
    rom.load_bytes(0U, image);
    mini32::Ram ram;
    mini32::Uart uart([](const std::uint8_t byte) { std::cout.put(static_cast<char>(byte)); });
    mini32::DebugDevice debug;
    mini32::Bus bus(rom, ram, uart, debug);
    mini32::CpuCore cpu(bus);

    while (!cpu.halted() && !cpu.faulted()) {
        if (cpu.retired_instructions() >= instruction_limit) {
            std::cerr << "instruction limit exceeded after " << cpu.retired_instructions()
                      << " instructions\n";
            return 1;
        }
        const mini32::StepResult result = cpu.step();
        if (result == mini32::StepResult::Halted) {
            std::cerr << "CPU halted after " << cpu.retired_instructions() << " instructions\n";
            return 0;
        }
    }

    const mini32::FaultInfo& fault = cpu.fault_info();
    std::cerr << "Mini32 fault: " << fault_name(fault.code) << '\n';
    print_hex("PC: ", fault.pc);
    print_hex("instruction: ", fault.instruction);
    if (fault.data_address.has_value()) {
        print_hex("data address: ", *fault.data_address);
    }
    return 1;
}
