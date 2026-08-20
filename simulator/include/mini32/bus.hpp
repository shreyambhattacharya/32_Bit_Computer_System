#pragma once

#include <cstdint>

#include "mini32/debug_device.hpp"
#include "mini32/gpio.hpp"
#include "mini32/rom.hpp"
#include "mini32/ram.hpp"
#include "mini32/uart.hpp"
#include "mini32/timer.hpp"

namespace mini32 {

enum class BusFault : std::uint8_t {
    None,
    Misaligned,
    Unmapped,
    ReadOnly,
    NonExecutable,
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
    Bus(const Rom& rom, Ram& ram, Uart& uart, DebugDevice& debug)
        : Bus(rom, ram, uart, debug, default_timer(), default_gpio()) {}
    Bus(const Rom& rom, Ram& ram, Uart& uart, DebugDevice& debug, Timer& timer, Gpio& gpio)
        : rom_(rom), ram_(ram), uart_(uart), debug_(debug), timer_(timer), gpio_(gpio) {}

    [[nodiscard]] BusReadResult read32(std::uint32_t address) const;
    [[nodiscard]] BusReadResult fetch32(std::uint32_t address) const;
    [[nodiscard]] BusWriteResult write32(std::uint32_t address, std::uint32_t value);
    void retire_tick() { timer_.retire_tick(); }

private:
    static Timer& default_timer();
    static Gpio& default_gpio();
    const Rom& rom_;
    Ram& ram_;
    Uart& uart_;
    DebugDevice& debug_;
    Timer& timer_;
    Gpio& gpio_;
};

}  // namespace mini32
