#include <cstdint>

#include "mini32/gpio.hpp"
#include "test_support.hpp"

int main() {
    mini32::Gpio gpio;
    CHECK(gpio.output() == 0U);
    CHECK(gpio.direction() == 0U);
    gpio.set_input(0xA5A55A5AU);
    CHECK(gpio.input() == 0xA5A55A5AU);
    CHECK(gpio.read32(mini32::Gpio::kBaseAddress).data == 0xA5A55A5AU);
    CHECK(gpio.write32(mini32::Gpio::kBaseAddress, 0xFFFFFFFFU).ok());
    CHECK(gpio.input() == 0xA5A55A5AU);
    CHECK(gpio.write32(mini32::Gpio::kBaseAddress + 4U, 0x00000001U).ok());
    CHECK(gpio.output() == 0x00000001U);
    CHECK(gpio.write32(mini32::Gpio::kBaseAddress + 4U, 0xA5A55A5AU).ok());
    CHECK(gpio.read32(mini32::Gpio::kBaseAddress + 4U).data == 0xA5A55A5AU);
    CHECK(gpio.write32(mini32::Gpio::kBaseAddress + 8U, 0x0000000FU).ok());
    CHECK(gpio.write32(mini32::Gpio::kBaseAddress + 8U, 0xFFFFFFFFU).ok());
    CHECK(gpio.direction() == 0xFFFFFFFFU);
    CHECK(gpio.read32(mini32::Gpio::kBaseAddress + 12U).data == 0U);
    CHECK(gpio.write32(mini32::Gpio::kBaseAddress + 12U, 0xFFFFFFFFU).ok());
    CHECK(gpio.output() == 0xA5A55A5AU && gpio.direction() == 0xFFFFFFFFU);
    CHECK(gpio.read32(mini32::Gpio::kBaseAddress + 2U).fault == mini32::MmioFault::Misaligned);
    CHECK(gpio.read32(mini32::Gpio::kBaseAddress + 16U).fault == mini32::MmioFault::OutOfRange);
    gpio.reset();
    CHECK(gpio.output() == 0U && gpio.direction() == 0U && gpio.input() == 0xA5A55A5AU);
}
