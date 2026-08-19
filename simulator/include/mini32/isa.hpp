#pragma once

#include <cstdint>

namespace mini32 {

inline constexpr std::uint8_t kRegisterCount = 32;
inline constexpr std::uint8_t kRegisterIndexMask = 0x1FU;
inline constexpr std::uint32_t kInstructionAlignment = 4U;

enum class Opcode : std::uint8_t {
    Nop = 0x00,
    Add = 0x01,
    Sub = 0x02,
    And = 0x03,
    Or = 0x04,
    Xor = 0x05,
    Slt = 0x06,
    Shl = 0x07,
    Shr = 0x08,
    Addi = 0x09,
    Andi = 0x0A,
    Ori = 0x0B,
    Xori = 0x0C,
    Lui = 0x0D,
    Lw = 0x0E,
    Sw = 0x0F,
    Beq = 0x10,
    Bne = 0x11,
    Blt = 0x12,
    Bge = 0x13,
    J = 0x14,
    Jal = 0x15,
    Jr = 0x16,
    Halt = 0x17,
};

}  // namespace mini32
