//#include "global.hpp"
#ifndef FIXED_H
#define FIXED_H

#include "log.hpp"
#include <cstdint>

//#define DEBUG

#define USE_FP
//#define USE_FLOAT

constexpr size_t roundToNeareastIntSize(size_t size) {
    return size <= 32 ? 32 : size <= 64 ? 64 : size <= 128 ? 128 : 0;
}

template <size_t N>
struct type_from_size {
    typedef void utype;
    typedef void stype;
};
template <>
struct type_from_size<0> {
    typedef void utype;
    typedef void stype;
};

template <>
struct type_from_size<8> {
    typedef uint8_t utype;
    typedef int8_t stype;
};

template <>
struct type_from_size<16> {
    typedef uint16_t utype;
    typedef int16_t stype;
};

template <>
struct type_from_size<32> {
    typedef uint32_t utype;
    typedef int32_t stype;
};

template <>
struct type_from_size<64> {
    typedef uint64_t utype;
    typedef int64_t stype;
};

template <>
struct type_from_size<128> {
    typedef __uint128_t utype;
    typedef __int128_t stype;
};

template <size_t I, size_t F>
class Signed;

template <size_t I, size_t F>
class Unsigned {
public:
    //constructors
    Unsigned() = default;
    Unsigned(const Unsigned&) = default;
    Unsigned& operator=(const Unsigned&) = default;
    //Unsigned(Unsigned&&) = default;
    Unsigned& operator=(Unsigned&&) = default;
    #ifdef USE_FP
    using value_type = typename type_from_size<roundToNeareastIntSize(I + F)>::utype;
    using frac_type = typename type_from_size<roundToNeareastIntSize(F)>::utype;
    Unsigned(value_type value) : value(value) {
        #ifdef DEBUG
        if (this->value < value) warning("truncation during creation of unsigned fp removing nonzero bits from %d", value);
        #endif //DEBUG
        this->check();
    }

    Unsigned(float value) {
        this->value = static_cast<value_type>(value * (static_cast<frac_type>(1) << F));
        this->check();
    }

    Unsigned(double value) {
        this->value = static_cast<value_type>(value * (static_cast<frac_type>(1) << F));
        this->check();
    }
    #else
    #ifdef USE_FLOAT
    using value_type = float;
    Unsigned(float value) : value(value) {}
    #else
    using value_type = double;
    Unsigned(double value) : value(value) {}
    #endif
    #endif

    //utilities
    typename type_from_size<roundToNeareastIntSize(I + F)>::utype const getInt() {
        #ifdef USE_FP
        return this->value >> F;
        #else
        return static_cast<typename type_from_size<roundToNeareastIntSize(I + F)>::utype>(this->value);
        #endif
    }

    Unsigned<0, F> const getFrac() {
        #ifdef USE_FP
        return Unsigned<0, F>{this->value & ((static_cast<frac_type>(1) << F) - 1)};
        #else
        return Unsigned<0, F>{this->value - this->getInt()};
        #endif
    }

    Unsigned<I, F> operator>>(unsigned int power) {
        #ifdef USE_FP
        return Unsigned<I, F>{this->value >> power};
        #else
        return Unsigned<I, F>{this->value / (float)(1 << power)};
        #endif
    }

    Unsigned<I, F> operator<<(unsigned int power) {
        #ifdef USE_FP
        return Unsigned<I, F>{this->value << power};
        #else
        return Unsigned<I, F>{this->value * (float)(1 << power)};
        #endif
    }

    void check() {
        #ifdef DEBUG
        #ifdef USE_FP
        using size = typename type_from_size<roundToNeareastIntSize(I + F)>::utype;
        if (this->value & static_cast<size>(~((static_cast<size>(1) << (I + F)) - 1))) 
            error("unsigned overflow: %u", this->value);
        #else //USE_FP
        if (this->value < 0 || this->value >= (float)(1 << (I + F))) error("unsigned overflow: %u", this->value);
        #endif //USE_FP
        #endif //DEBUG

    }

    Unsigned<I + 1, F> operator+(const Unsigned<I, F>& rhs) const {
        #ifdef USE_FP
        using next_size = typename type_from_size<roundToNeareastIntSize(I + F + 1)>::utype;
        return Unsigned<I + 1, F>{static_cast<next_size>(this->value) + static_cast<next_size>(rhs.value)};
        #else
        return Unsigned<I + 1, F>{this->value + rhs.value};
        #endif
    }

    Unsigned<I, F> wrapping_add(const Unsigned<I, F>& rhs) const {
        #ifdef USE_FP
        using next_size = typename type_from_size<roundToNeareastIntSize(I + F + 1)>::utype;
        next_size sum = this->value + rhs.value;
        return Unsigned<I, F>{sum & ((static_cast<next_size>(1) << (I + F)) - 1)};
        #else
        float sum = this->value + rhs.value;
        if (sum > (float)(1 << (I + F))) sum -= (float)(1 << (I + F));
        #endif
    }

    void operator+=(const Unsigned<I, F>& rhs) {
        #ifdef USE_FP
        #ifdef DEBUG
        if (this->value + rhs.value < this->value) warning("addition overflow: %d + %d", this->value, rhs.value);
        #endif //DEBUG
        this->value += rhs.value;
        #ifdef DEBUG
        this->check();
        #endif //DEBUG
        #else
        this->value += rhs.value;
        #endif
    }

    Unsigned<I, F> operator-(const Unsigned<I, F>& rhs) const {
        #ifdef DEBUG
        if (this->value < rhs.value) 
            warning("subtraction underflow: %d - %d", this->value, rhs.value);
        #endif //DEBUG
        #ifdef USE_FP
        //cast is technically not needed, since rhs is always smaller than this
        using next_size = typename type_from_size<roundToNeareastIntSize(I + F)>::utype;
        return Unsigned<I, F>{static_cast<next_size>(this->value) - static_cast<next_size>(rhs.value)};
        #else
        return Unsigned<I, F>{this->value - rhs.value};
        #endif
    }

    Unsigned<I, F> wrapping_minus(const Unsigned<I, F>& rhs) const {
        #ifdef USE_FP
        using next_size = typename type_from_size<roundToNeareastIntSize(I + F)>::utype;
        if (this->value < rhs.value) {
            next_size diff = rhs.value - this->value;
            return Unsigned<I, F>{(static_cast<next_size>(1) << (I + F)) - diff};
        } else {
            return Unsigned<I, F>{static_cast<next_size>(this->value) - static_cast<next_size>(rhs.value)};
        }
        #else
        float diff = this->value - rhs.value;
        if (diff < 0) diff += (float)(1 << (I + F));
        return Unsigned<I, F>{diff};
        #endif
    }

    Unsigned<0, F> const inv() {
        #ifdef USE_FP
        using frac_type = typename type_from_size<roundToNeareastIntSize(F)>::utype;
        Unsigned<0, F> frac = this->getFrac();
        return (frac == Unsigned<0, F>{0.f}) ? Unsigned<0, F>{0.f} : Unsigned<0, F>{(static_cast<frac_type>(1) << F) - this->getFrac().value};
        #else
        return Unsigned<0, F>{1.f  - this->getFrac().value};
        #endif
    }

    template <size_t I1, size_t F1>
    Unsigned<I + I1, F + F1> operator*(const Unsigned<I1, F1>& rhs) {
        #ifdef USE_FP
        using next_size = typename type_from_size<roundToNeareastIntSize(I + I1 + F + F1)>::utype;
        return Unsigned<I + I1, F + F1>{static_cast<next_size>(this->value) * static_cast<next_size>(rhs.value)};
        #else
        return Unsigned<I + I1, F + F1>{this->value * rhs.value};
        #endif
    }

    template <size_t I1, size_t F1>
    Signed<I + I1, F + F1> operator*(const Signed<I1, F1>& rhs) {
        #ifdef USE_FP
        using next_size = typename type_from_size<roundToNeareastIntSize(I + I1 + F + F1 + 1)>::stype;
        return Signed<I + I1, F + F1>{static_cast<next_size>(this->value) * static_cast<next_size>(rhs.value)};
        #else
        return Signed<I + I1, F + F1>{this->value * rhs.value};
        #endif
    }

    template <size_t FQ, size_t ID, size_t FD>
    Unsigned<I + FD, FQ> div(const Unsigned<ID, FD>& rhs) const {
        #ifdef USE_FP
        //the number of fractional bits in the quotient is FQ
        //F - FD is the number of fractional bits left after the divsision
        //FQ - (F - FD) is the number of fractional bits that must be added to the quotient
        //FQ - (F - FD) = FQ + FD - F
        using next_size = typename type_from_size<roundToNeareastIntSize(I + FQ + FD)>::utype;
        return Unsigned<I + FD, FQ>{(static_cast<next_size>(this->value) << (FQ + FD - F)) / static_cast<next_size>(rhs.value)};
        #else
        return Unsigned<I + FD, FQ>{this->value / rhs.value};
        #endif
    }

    bool operator==(const Unsigned<I, F>& rhs) const {
        return this->value == rhs.value;
    }

    bool operator<(const Unsigned<I, F>& rhs) const {
        return this->value < rhs.value;
    }

    bool operator>(const Unsigned<I, F>& rhs) const {
        return this->value > rhs.value;
    }

    bool operator>= (const Unsigned<I, F>& rhs) const {
        return this->value >= rhs.value;
    }

    template <size_t I1, size_t F1>
    explicit operator Unsigned<I1, F1>() const {
        #ifdef USE_FP
        using new_size = typename type_from_size<roundToNeareastIntSize(I1 + F1)>::utype;
        #ifdef DEBUG
        using check_size = typename type_from_size<roundToNeareastIntSize(I1 + F)>::utype;
        check_size mask = static_cast<check_size>(~((static_cast<check_size>(1) << (I1 + F)) - 1));
        if (I1 < I && (this->value & mask) != 0) 
            error("cast removing nonzero integer bits from %d", this->value);
        #endif //DEBUG
        return Unsigned<I1, F1>{(F1 > F) ? static_cast<new_size>(this->value) << (F1 - F) : static_cast<new_size>(this->value >> (F - F1))};
        #else
        return Unsigned<I1, F1>{this->value};
        #endif
    }

    explicit operator Signed<I, F>() const {
        #ifdef USE_FP
        using stype = typename type_from_size<roundToNeareastIntSize(I + F + 1)>::stype;
        return Signed<I, F>{static_cast<stype>(this->value)};
        #else
        return Signed<I, F>{this->value};
        #endif
    }

    template <size_t I1, size_t F1>
    explicit operator Signed<I1, F1>() const {
        return static_cast<Signed<I1, F1>>(static_cast<Signed<I, F>>(*this));
    }

    explicit operator float() const {
        #ifdef USE_FP
        return static_cast<float>(this->value) / (static_cast<frac_type>(1) << F);
        #else
        return this->value;
        #endif
    }


    static constexpr size_t integer = I;
    static constexpr size_t fraction = F;
    static constexpr size_t bits = I + F;
    #ifdef USE_FP
    //using value_type = typename type_from_size<roundToNeareastIntSize(I + F)>::utype;
    value_type value;
    #else
    #ifdef USE_FLOAT
    float value;
    #else
    double value;
    #endif
    #endif
};

// I does not include the sign bit
template <size_t I, size_t F>
class Signed {
public:
    Signed() = default;
    Signed(const Signed&) = default;
    Signed& operator=(const Signed&) = default;
    //Signed(Signed&&) = default;
    Signed& operator=(Signed&&) = default;
    #ifdef USE_FP
    using value_type = typename type_from_size<roundToNeareastIntSize(I + F + 1)>::stype;
    using frac_type = typename type_from_size<roundToNeareastIntSize(F)>::utype;
    Signed(value_type value) : value(value) {
        #ifdef DEBUG
        if (this->value != value) warning("truncation during creation of signed fp removing relevant bits from %d", value);
        #endif //DEBUG
        this->check();
    }

    Signed(float value) {
        this->value = static_cast<value_type>(value * (static_cast<frac_type>(1) << F));
        this->check();
    }

    Signed(double value) {
        this->value = static_cast<value_type>(value * (static_cast<frac_type>(1) << F));
        this->check();
    }
    #else
    #ifdef USE_FLOAT
    using value_type = float;
    Signed(float value) : value(value) {}
    #else
    using value_type = double;
    Signed(double value) : value(value) {}
    #endif
    #endif

    //utilities
    value_type getInt() const {
        #ifdef USE_FP
        return this->value >> F;
        #else
        return static_cast<typename type_from_size<roundToNeareastIntSize(I + F)>::stype>(this->value);
        #endif
    }
    //unsure of this implementation

    Unsigned<0, F> getFrac() const {
        warning("getFrac not implemented");
        #ifdef USE_FP
        return Unsigned<0, F>{this->value & ((static_cast<frac_type>(1) << F) - 1)};
        #else
        return Unsigned<0, F>{this->value - this->getInt()};
        #endif
    }

    constexpr Signed<I, F> operator>>(unsigned int power) {
        #ifdef USE_FP
        return Signed<I, F>{this->value >> power};
        #else
        return Signed<I, F>{this->value / (float)(1 << power)};
        #endif
    }

    Signed<I, F> operator<<(unsigned int power) {
        #ifdef USE_FP
        return Signed<I, F>{this->value << power};
        #else
        return Signed<I, F>{this->value * (float)(1 << power)};
        #endif
    }

    Signed<I + 1, F> operator+(const Signed<I, F>& rhs) {
        #ifdef USE_FP
        using next_size = typename type_from_size<roundToNeareastIntSize(I + F + 2)>::stype;
        #ifdef DEBUG
        //check for overflow
        next_size sum = static_cast<next_size>(this->value) + static_cast<next_size>(rhs.value);
        if ((this->value < 0 && rhs.value < 0 && sum >= 0) || (this->value > 0 && rhs.value > 0 && sum <= 0)) warning("addition overflow: %d + %d", this->value, rhs.value);
        #endif //DEBUG
        return Signed<I + 1, F>{static_cast<next_size>(this->value) + static_cast<next_size>(rhs.value)};
        #else
        return Signed<I + 1, F>{this->value + rhs.value};
        #endif
    }

    Signed<I + 1, F> operator-(const Signed<I, F>& rhs) const {
        #ifdef USE_FP
        using next_size = typename type_from_size<roundToNeareastIntSize(I + F + 2)>::stype;
        #ifdef DEBUG
        // Check for overflow
        next_size diff = static_cast<next_size>(this->value) - static_cast<next_size>(rhs.value);
        if ((this->value < 0 && rhs.value > 0 && diff >= 0) || (this->value > 0 && rhs.value < 0 && diff <= 0))
            warning("subtraction overflow: %d - %d", this->value, rhs.value);
        #endif // DEBUG
        return Signed<I + 1, F>{static_cast<next_size>(this->value) - static_cast<next_size>(rhs.value)};
        #else
        return Signed<I + 1, F>{this->value - rhs.value};
        #endif
    }

    Signed<I, F> operator-() const {
        return Signed<I, F>{-this->value};
    }

    void check() {
        #ifdef DEBUG
        #ifdef USE_FP
        //check that all bits past last integer bit are the same as the sign bit
        using size = typename type_from_size<roundToNeareastIntSize(I + F + 1)>::utype;
        size mask = static_cast<size>(~((static_cast<size>(1) << I) - 1));
        bool sign = (static_cast<size>(this->value) >> (roundToNeareastIntSize(I + F) - 1)) & 1;
        if ((static_cast<size>(this->value >> F) & mask) != (sign ? mask : 0)) 
            error("signed overflow: %d", this->value); 
        #else //USE_FP
        if (this->value < -(1 << (I + F - 1)) || this->value >= (1 << (I + F - 1))) 
            error("signed overflow: %d", this->value);
        #endif //USE_FP
        #endif
    }

    void operator+=(const Signed<I, F>& rhs) {
        #ifdef USE_FP
        #ifdef DEBUG
        //check for overflow
        using value_type = typename type_from_size<roundToNeareastIntSize(I + F)>::stype;
        value_type sum = this->value + rhs.value;
        if ((this->value < 0 && rhs.value < 0 && sum >= 0) || (this->value > 0 && rhs.value > 0 && sum <= 0)) warning("addition overflow: %d + %d", this->value, rhs.value);
        #endif //DEBUG
        this->value += rhs.value;
        #ifdef DEBUG
        this->check();
        #endif //DEBUG
        #else
        this->value += rhs.value;
        #endif
    }

    template <size_t I1, size_t F1>
    Signed<I + I1, F + F1> operator*(const Signed<I1, F1>& rhs) {
        #ifdef USE_FP
        using next_size = typename type_from_size<roundToNeareastIntSize(I + I1 + F + F1 + 1)>::stype;
        return Signed<I + I1, F + F1>{static_cast<next_size>(this->value) * static_cast<next_size>(rhs.value)};
        #else
        return Signed<I + I1, F + F1>{this->value * rhs.value};
        #endif
    }

    template <size_t FQ, size_t ID, size_t FD>
    Signed<I + FD, FQ> div(const Signed<ID, FD>& rhs) const {
        #ifdef USE_FP
        //the number of fractional bits in the quotient is FQ
        //F - FD is the number of fractional bits left after the divsision
        //FQ - (F - FD) is the number of fractional bits that must be added to the quotient
        //FQ - (F - FD) = FQ + FD - F
        using next_size = typename type_from_size<roundToNeareastIntSize(I + FQ + FD)>::stype;
        return Signed<I + FD, FQ>{(static_cast<next_size>(this->value) << (FQ + FD - F)) / static_cast<next_size>(rhs.value)};
        #else
        return Signed<I + FQ + FD - F, FQ>{this->value / rhs.value};
        #endif
    }

    template <size_t I1, size_t F1>
    Signed<I + I1, F + F1> operator*(const Unsigned<I1, F1>& rhs) {
        #ifdef USE_FP
        using next_size = typename type_from_size<roundToNeareastIntSize(I + I1 + F + F1 + 1)>::stype;
        return Signed<I + I1, F + F1>{static_cast<next_size>(this->value) * static_cast<next_size>(rhs.value)};
        #else
        return Signed<I + I1, F + F1>{this->value * rhs.value};
        #endif
    }

    bool operator==(const Signed<I, F>& rhs) const {
        return this->value == rhs.value;
    }

    bool operator<(const Signed<I, F>& rhs) const {
        return this->value < rhs.value;
    }

    bool operator>(const Signed<I, F>& rhs) const {
        return this->value > rhs.value;
    }

    template <size_t I1, size_t F1>
    explicit operator Signed<I1, F1>() const {
        //we need to check to ensure that no integer bits are truncated
        //and integer bit is meaningful if it is not equal to the sign bit
        #ifdef DEBUG
        if (I1 < I) {
            using utype = typename type_from_size<roundToNeareastIntSize(I + F + 1)>::utype;
            utype unsigned_value = static_cast<utype>(this->value);
            bool sign = (unsigned_value >> (roundToNeareastIntSize(I + F) - 1)) & 1;
            utype mask = static_cast<utype>(~((static_cast<utype>(1) << I) - 1)) & ((static_cast<utype>(1) << I1) - 1);
            utype extra_part = (unsigned_value >> F) & mask;
            if (extra_part != (sign ? mask : 0)) error("cast removing relevant integer bits from %d", this->value);
        }
        #endif //DEBUG
        #ifdef USE_FP
        using new_size = typename type_from_size<roundToNeareastIntSize(I1 + F1 + 1)>::stype;
        return Signed<I1, F1>{(F1 > F) ? (static_cast<new_size>(this->value << (F1 - F))) : (static_cast<new_size>(this->value >> (F - F1)))};
        #else
        return Signed<I1, F1>{this->value};
        #endif
    }

    explicit operator Unsigned<I, F>() const {
        #ifdef USE_FP
        using utype = typename type_from_size<roundToNeareastIntSize(I + F)>::utype;
        return Unsigned<I, F>{static_cast<utype>(this->value >= 0 ? this->value : -this->value)};
        #else
        return Unsigned<I, F>{abs(this->value)};
        #endif
    }

    template <size_t I1, size_t F1>
    explicit operator Unsigned<I1, F1>() const {
        return static_cast<Unsigned<I1, F1>>(static_cast<Unsigned<I, F>>(*this));
    }

    explicit operator float() const {
        #ifdef USE_FP
        using frac_type = typename type_from_size<roundToNeareastIntSize(F)>::stype;
        return static_cast<float>(this->value) / (static_cast<frac_type>(1) << F);
        #else
        return this->value;
        #endif
    }


    static constexpr size_t integer = I;
    static constexpr size_t fraction = F;
    static constexpr size_t bits = I + F;
    #ifdef USE_FP
    value_type value;
    #else
    #ifdef USE_FLOAT
    float value;
    #else
    double value;
    #endif
    #endif
};

template <size_t I, size_t F>
Unsigned<I, F> create(unsigned value) {
    if (value > ((1ULL << I) - 1)) error("attempted to create an unsigned with %d, which is too large to be contained by integer of size %d", value, I);
    return Unsigned<I, F>{value << F};
}

template <size_t I, size_t F>
Signed<I, F> create(int value) {
    if (value > ((1ULL << (I - 1)) - 1) || value < -(1ULL << (I - 1))) error("attempted to create a signed with %d, which is too large to be contained by integer of size %d", value, I);
    return Signed<I, F>{value << F};
}

#endif //FIXED_H