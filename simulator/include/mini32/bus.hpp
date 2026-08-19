#pragma once

#include <cstdint>

#include "mini32/rom.hpp"

namespace mini32 {

enum class BusFault : std::uint8_t {
    None,
    Misaligned,
    Unmapped,
};

struct BusReadResult {
    std::uint32_t data{};
    BusFault fault{BusFault::None};

    [[nodiscard]] bool ok() const { return fault == BusFault::None; }
};

class Bus {
public:
    explicit Bus(const Rom& rom) : rom_(rom) {}

    [[nodiscard]] BusReadResult read32(std::uint32_t address) const;

private:
    const Rom& rom_;
};

}  // namespace mini32
