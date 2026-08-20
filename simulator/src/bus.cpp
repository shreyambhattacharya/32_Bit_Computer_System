#include "mini32/bus.hpp"

namespace mini32 {
namespace {

BusFault bus_fault(const MmioFault fault) {
    return fault == MmioFault::Misaligned ? BusFault::Misaligned : BusFault::Unmapped;
}

}  // namespace

Timer& Bus::default_timer() {
    static Timer timer;
    return timer;
}

Gpio& Bus::default_gpio() {
    static Gpio gpio;
    return gpio;
}

BusReadResult Bus::read32(const std::uint32_t address) const {
    if ((address & 0x3U) != 0U) {
        return {.fault = BusFault::Misaligned};
    }

    if (address >= Rom::kBaseAddress && address <= Rom::kLastAddress) {
        const RomReadResult rom_result = rom_.read32(address);
        if (rom_result.ok()) {
            return {.data = rom_result.data};
        }
        return {.fault = rom_result.fault == RomFault::Misaligned ? BusFault::Misaligned
                                                                    : BusFault::Unmapped};
    }
    if (address >= Ram::kBaseAddress && address <= Ram::kLastAddress) {
        const RamReadResult ram_result = ram_.read32(address);
        if (ram_result.ok()) {
            return {.data = ram_result.data};
        }
        return {.fault = ram_result.fault == RamFault::Misaligned ? BusFault::Misaligned
                                                                    : BusFault::Unmapped};
    }
    if (address >= Uart::kBaseAddress && address <= Uart::kLastAddress) {
        const MmioReadResult uart_result = uart_.read32(address);
        return uart_result.ok() ? BusReadResult{.data = uart_result.data}
                                : BusReadResult{.fault = bus_fault(uart_result.fault)};
    }
    if (address >= Timer::kBaseAddress && address <= Timer::kLastAddress) {
        const MmioReadResult timer_result = timer_.read32(address);
        return timer_result.ok() ? BusReadResult{.data = timer_result.data}
                                 : BusReadResult{.fault = bus_fault(timer_result.fault)};
    }
    if (address >= Gpio::kBaseAddress && address <= Gpio::kLastAddress) {
        const MmioReadResult gpio_result = gpio_.read32(address);
        return gpio_result.ok() ? BusReadResult{.data = gpio_result.data}
                                : BusReadResult{.fault = bus_fault(gpio_result.fault)};
    }
    if (address >= DebugDevice::kBaseAddress && address <= DebugDevice::kLastAddress) {
        const MmioReadResult debug_result = debug_.read32(address);
        return debug_result.ok() ? BusReadResult{.data = debug_result.data}
                                 : BusReadResult{.fault = bus_fault(debug_result.fault)};
    }

    return {.fault = BusFault::Unmapped};
}

BusReadResult Bus::fetch32(const std::uint32_t address) const {
    if ((address & 0x3U) != 0U) {
        return {.fault = BusFault::Misaligned};
    }
    if (address >= Rom::kBaseAddress && address <= Rom::kLastAddress) {
        const RomReadResult rom_result = rom_.read32(address);
        return rom_result.ok() ? BusReadResult{.data = rom_result.data}
                               : BusReadResult{.fault = BusFault::Unmapped};
    }
    if (address >= Ram::kBaseAddress && address <= Ram::kLastAddress) {
        return {.fault = BusFault::NonExecutable};
    }
    if ((address >= Uart::kBaseAddress && address <= Uart::kLastAddress) ||
        (address >= Timer::kBaseAddress && address <= Timer::kLastAddress) ||
        (address >= Gpio::kBaseAddress && address <= Gpio::kLastAddress) ||
        (address >= DebugDevice::kBaseAddress && address <= DebugDevice::kLastAddress)) {
        return {.fault = BusFault::NonExecutable};
    }
    return {.fault = BusFault::Unmapped};
}

BusWriteResult Bus::write32(const std::uint32_t address, const std::uint32_t value) {
    if ((address & 0x3U) != 0U) {
        return {.fault = BusFault::Misaligned};
    }
    if (address >= Rom::kBaseAddress && address <= Rom::kLastAddress) {
        return {.fault = BusFault::ReadOnly};
    }
    if (address >= Ram::kBaseAddress && address <= Ram::kLastAddress) {
        const RamWriteResult ram_result = ram_.write32(address, value);
        return {.fault = ram_result.fault == RamFault::None ? BusFault::None
                                                              : BusFault::Unmapped};
    }
    if (address >= Uart::kBaseAddress && address <= Uart::kLastAddress) {
        const MmioWriteResult uart_result = uart_.write32(address, value);
        return {.fault = uart_result.ok() ? BusFault::None : bus_fault(uart_result.fault)};
    }
    if (address >= Timer::kBaseAddress && address <= Timer::kLastAddress) {
        const MmioWriteResult timer_result = timer_.write32(address, value);
        return {.fault = timer_result.ok() ? BusFault::None : bus_fault(timer_result.fault)};
    }
    if (address >= Gpio::kBaseAddress && address <= Gpio::kLastAddress) {
        const MmioWriteResult gpio_result = gpio_.write32(address, value);
        return {.fault = gpio_result.ok() ? BusFault::None : bus_fault(gpio_result.fault)};
    }
    if (address >= DebugDevice::kBaseAddress && address <= DebugDevice::kLastAddress) {
        const MmioWriteResult debug_result = debug_.write32(address, value);
        return {.fault = debug_result.ok() ? BusFault::None : bus_fault(debug_result.fault)};
    }
    return {.fault = BusFault::Unmapped};
}

}  // namespace mini32
