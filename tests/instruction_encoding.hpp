#pragma once

#include <cstdint>

#include "mini32/isa.hpp"

namespace test_encoding {

constexpr std::uint32_t encode_r(const mini32::Opcode opcode, const std::uint8_t rd,
                                 const std::uint8_t rs1, const std::uint8_t rs2) {
    return (static_cast<std::uint32_t>(opcode) << 26U) |
           (static_cast<std::uint32_t>(rd) << 21U) |
           (static_cast<std::uint32_t>(rs1) << 16U) |
           (static_cast<std::uint32_t>(rs2) << 11U);
}

constexpr std::uint32_t encode_i(const mini32::Opcode opcode, const std::uint8_t rd,
                                 const std::uint8_t rs1, const std::uint16_t immediate) {
    return (static_cast<std::uint32_t>(opcode) << 26U) |
           (static_cast<std::uint32_t>(rd) << 21U) |
           (static_cast<std::uint32_t>(rs1) << 16U) | immediate;
}

constexpr std::uint32_t encode_s(const std::uint8_t rs2, const std::uint8_t rs1,
                                 const std::uint16_t immediate) {
    return (static_cast<std::uint32_t>(mini32::Opcode::Sw) << 26U) |
           (static_cast<std::uint32_t>(rs2) << 21U) |
           (static_cast<std::uint32_t>(rs1) << 16U) | immediate;
}

constexpr std::uint32_t encode_b(const mini32::Opcode opcode, const std::uint8_t rs1,
                                 const std::uint8_t rs2, const std::uint16_t immediate) {
    return (static_cast<std::uint32_t>(opcode) << 26U) |
           (static_cast<std::uint32_t>(rs1) << 21U) |
           (static_cast<std::uint32_t>(rs2) << 16U) | immediate;
}

constexpr std::uint32_t encode_j(const mini32::Opcode opcode, const std::uint32_t immediate) {
    return (static_cast<std::uint32_t>(opcode) << 26U) | (immediate & 0x03FFFFFFU);
}

constexpr std::uint32_t encode_jr(const std::uint8_t rs1) {
    return (static_cast<std::uint32_t>(mini32::Opcode::Jr) << 26U) |
           (static_cast<std::uint32_t>(rs1) << 21U);
}

}  // namespace test_encoding
