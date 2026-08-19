#pragma once

#include <cstdint>

#include "mini32/rom.hpp"
#include "mini32/ram.hpp"

namespace mini32 {

enum class BusFault : std::uint8_t {
    None,
    Misaligned,
    Unmapped,
    ReadOnly,
};

struct BusWriteResult {
    BusFault fault{BusFault::None};

    [[nodiscard]] bool ok() const { return fault == BusFault::None; }
};

struct BusReadResult {
    std::uint32_t data{};
    BusFault fault{BusFault::None};

    [[nodiscard]] bool ok() const { return fault == BusFault::None; }
};

class Bus {
public:
    Bus(const Rom& rom, Ram& ram) : rom_(rom), ram_(ram) {}

    [[nodiscard]] BusReadResult read32(std::uint32_t address) const;
    [[nodiscard]] BusWriteResult write32(std::uint32_t address, std::uint32_t value);

private:
    const Rom& rom_;
    Ram& ram_;
};

}  // namespace mini32
