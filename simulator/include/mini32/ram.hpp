#pragma once

#include <array>
#include <cstddef>
#include <cstdint>

namespace mini32 {

enum class RamFault : std::uint8_t {
    None,
    Misaligned,
    OutOfRange,
};

struct RamReadResult {
    std::uint32_t data{};
    RamFault fault{RamFault::None};

    [[nodiscard]] bool ok() const { return fault == RamFault::None; }
};

struct RamWriteResult {
    RamFault fault{RamFault::None};

    [[nodiscard]] bool ok() const { return fault == RamFault::None; }
};

class Ram {
public:
    inline static constexpr std::uint32_t kBaseAddress = 0x10000000U;
    inline static constexpr std::size_t kSizeBytes = 64U * 1024U;
    inline static constexpr std::uint32_t kLastAddress =
        kBaseAddress + static_cast<std::uint32_t>(kSizeBytes - 1U);

    [[nodiscard]] RamReadResult read32(std::uint32_t address) const;
    [[nodiscard]] RamWriteResult write32(std::uint32_t address, std::uint32_t value);

    // Host-side inspection only; guest code has no byte-access instructions in v0.1.
    [[nodiscard]] std::uint8_t debug_read_byte(std::uint32_t address) const;

private:
    std::array<std::uint8_t, kSizeBytes> bytes_{};
};

}  // namespace mini32
