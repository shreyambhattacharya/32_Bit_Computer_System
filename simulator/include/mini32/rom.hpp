#pragma once

#include <array>
#include <cstddef>
#include <cstdint>
#include <span>

namespace mini32 {

enum class RomFault : std::uint8_t {
    None,
    Misaligned,
    OutOfRange,
};

struct RomReadResult {
    std::uint32_t data{};
    RomFault fault{RomFault::None};

    [[nodiscard]] bool ok() const { return fault == RomFault::None; }
};

class Rom {
public:
    inline static constexpr std::uint32_t kBaseAddress = 0x00000000U;
    inline static constexpr std::size_t kSizeBytes = 64U * 1024U;
    inline static constexpr std::uint32_t kLastAddress =
        kBaseAddress + static_cast<std::uint32_t>(kSizeBytes - 1U);

    void load_bytes(std::uint32_t address, std::span<const std::uint8_t> image);
    void load32(std::uint32_t address, std::uint32_t word);

    [[nodiscard]] RomReadResult read32(std::uint32_t address) const;

private:
    std::array<std::uint8_t, kSizeBytes> bytes_{};
};

}  // namespace mini32
