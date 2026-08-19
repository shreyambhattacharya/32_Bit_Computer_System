#include <cstdint>
#include <stdexcept>

#include "mini32/register_file.hpp"
#include "test_support.hpp"

int main() {
    mini32::RegisterFile registers;
    CHECK(registers.read(0U) == 0U);
    CHECK(registers.read(31U) == 0U);

    registers.write(1U, 0x12345678U);
    registers.write(2U, 0xCAFEBABEU);
    CHECK(registers.read(1U) == 0x12345678U);
    CHECK(registers.read(2U) == 0xCAFEBABEU);
    registers.write(1U, 7U);
    CHECK(registers.read(1U) == 7U);
    CHECK(registers.read(2U) == 0xCAFEBABEU);

    registers.write(0U, 0xFFFFFFFFU);
    CHECK(registers.read(0U) == 0U);

    registers.reset();
    CHECK(registers.read(1U) == 0U);
    CHECK(registers.read(2U) == 0U);

    bool read_threw = false;
    try {
        static_cast<void>(registers.read(32U));
    } catch (const std::out_of_range&) {
        read_threw = true;
    }
    CHECK(read_threw);

    bool write_threw = false;
    try {
        registers.write(32U, 1U);
    } catch (const std::out_of_range&) {
        write_threw = true;
    }
    CHECK(write_threw);
}
