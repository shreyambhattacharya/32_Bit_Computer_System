#pragma once

#include <cstdint>

namespace mini32 {

enum class MmioFault : std::uint8_t {
    None,
    Misaligned,
    OutOfRange,
};

struct MmioReadResult {
    std::uint32_t data{};
    MmioFault fault{MmioFault::None};

    [[nodiscard]] bool ok() const { return fault == MmioFault::None; }
};

struct MmioWriteResult {
    MmioFault fault{MmioFault::None};

    [[nodiscard]] bool ok() const { return fault == MmioFault::None; }
};

}  // namespace mini32
