#pragma once

#include <cstdlib>
#include <iostream>

inline void check(const bool condition, const char* expression, const char* file, const int line) {
    if (!condition) {
        std::cerr << file << ':' << line << ": check failed: " << expression << '\n';
        std::exit(EXIT_FAILURE);
    }
}

#define CHECK(expression) check((expression), #expression, __FILE__, __LINE__)
