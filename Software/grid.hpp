#ifndef GRID_HPP
#define GRID_HPP

#include "global.hpp"

template <typename T>
T div4(T value) {
    #ifdef USE_FP
    return value >> 2;
    #else
    return value / 4;
    #endif // USE_FP
}

template <typename T>
class UGrid {
public:
    UGrid(T min = T{0.f}) : min(min) {
        for (unsigned int i = 0; i < GRID_SIZE; i++) {
            data[i] = T{0.f};
        }
    }

    T& operator[](int i) {
        return data[i];
    }

    const T& operator[](int i) const {
        return data[i];
    }

    T& operator()(int y, int x) {
        if (y >= (signed)GRIDY) y -= GRIDY;
        if (y < 0) y += GRIDY;
        if (x >= (signed)GRIDX) x -= GRIDX;
        if (x < 0) x += GRIDX;
        return data[y * GRIDX + x];
    }

    const T& operator()(int y, int x) const {
        if (y >= (signed)GRIDY) y -= GRIDY;
        if (y < 0) y += GRIDY;
        if (x >= (signed)GRIDX) x -= GRIDX;
        if (x < 0) x += GRIDX;
        return data[y * GRIDX + x];
    }

    void setAll(T value) {
        for (unsigned int i = 0; i < GRID_SIZE; i++) {
            data[i] = value;
        }
    }
    
    //TODO: if T is Unsigned, return Unsigned, if T is signed return Signed
    Unsigned<T::integer, T::fraction + Pos::fraction * 2> gather(Pos& y, Pos& x) const {
        using ret_t = Unsigned<T::integer, T::fraction + Pos::fraction * 2>;
        using Dist = Unsigned<0, Pos::fraction>;
        using Weight = Unsigned<0, Pos::fraction * 2>;
        Dist y_frac = y.getFrac();
        Dist x_frac = x.getFrac();
        //if y_frac or x_frac is 0, then we don't need to calculate the inverse and we will special case the later calculation
        Dist inv_y_frac = y.inv();
        Dist inv_x_frac = x.inv();
        using int_size = typename type_from_size<roundToNeareastIntSize(Pos::integer)>::utype;
        int_size y_int = y.getInt();
        int_size x_int = x.getInt();
        
        //overflow is dealt with by applying periodic boundary conditions in the lookup function
        T v00 = (*this)(y_int, x_int);
        T v01 = (*this)(y_int, x_int + 1);
        T v10 = (*this)(y_int + 1, x_int);
        T v11 = (*this)(y_int + 1, x_int + 1);

        if (y_frac == Dist{0.f} && x_frac == Dist{0.f}) return static_cast<ret_t>(v00);
        else if (y_frac == Dist{0.f}) return static_cast<ret_t>(static_cast<Weight>(inv_x_frac) *  v00 + static_cast<Weight>(x_frac) * v01);
        else if (x_frac == Dist{0.f}) return static_cast<ret_t>(static_cast<Weight>(inv_y_frac) * v00 + static_cast<Weight>(y_frac) * v10);
        else {

            Weight w00 = inv_y_frac * inv_x_frac;
            Weight w01 = inv_y_frac * x_frac;
            Weight w10 = y_frac * inv_x_frac;
            Weight w11 = y_frac * x_frac; 
            return static_cast<ret_t>((w00 * v00 + w01 * v01) + (w10 * v10 + w11 * v11));
        }
    }

    void scatter_charge(Pos y, Pos x) {
        using Dist = Unsigned<0, Pos::fraction>;
        using Weight = Unsigned<0, Pos::fraction * 2>;
        Dist y_frac = y.getFrac();
        Dist x_frac = x.getFrac();
        //TODO: fix overflow if y_frac or x_frac is 0
        Dist inv_y_frac = y.inv();
        Dist inv_x_frac = x.inv();
        using int_size = typename type_from_size<roundToNeareastIntSize(Pos::integer)>::utype;
        int_size y_int = y.getInt();
        int_size x_int = x.getInt();

        Weight w00 = y_frac == Dist{0.f} ? (x_frac == Dist{0.f} ? Weight{0.f} : Weight{inv_x_frac}) : (x_frac == Dist{0.f} ? Weight{inv_y_frac} : inv_y_frac * inv_x_frac);
        Weight w01 = y_frac == Dist{0.f} ? Weight{x_frac} : inv_y_frac * x_frac;
        Weight w10 = x_frac == Dist{0.f} ? Weight{y_frac} : y_frac * inv_x_frac;
        Weight w11 = y_frac * x_frac;

        //since we normalise charge to 1 and charge is scattered to four gyro points, we divide by 4
        (*this)(y_int, x_int) += (y_frac == Dist{0.f} && x_frac == Dist{0.f}) ? T{1.f/4} : T{w00 >> 2};
        (*this)(y_int, x_int + 1) += T{w01 >> 2};
        (*this)(y_int + 1, x_int) += T{w10 >> 2};
        (*this)(y_int + 1, x_int + 1) += T{w11 >> 2};
    }
        
private:
    std::array<T, GRID_SIZE> data;
    T min;
};

template <typename T>
class SGrid {
public:
    SGrid(T min = T{0.f}) : min(min) {
        for (unsigned int i = 0; i < GRID_SIZE; i++) {
            data[i] = T{0.f};
        }
    }

    T& operator[](int i) {
        return data[i];
    }

    const T& operator[](int i) const {
        return data[i];
    }

    T& operator()(int y, int x) {
        if (y >= (signed)GRIDY) y -= GRIDY;
        if (y < 0) y += GRIDY;
        if (x >= (signed)GRIDX) x -= GRIDX;
        if (x < 0) x += GRIDX;
        return data[y * GRIDX + x];
    }

    const T& operator()(int y, int x) const {
        if (y >= (signed)GRIDY) y -= GRIDY;
        if (y < 0) y += GRIDY;
        if (x >= (signed)GRIDX) x -= GRIDX;
        if (x < 0) x += GRIDX;
        return data[y * GRIDX + x];
    }

    void setAll(T value) {
        for (unsigned int i = 0; i < GRID_SIZE; i++) {
            data[i] = value;
        }
    }

    //TODO: if T is Unsigned, return Unsigned, if T is signed return Signed
    Signed<T::integer, T::fraction + Pos::fraction * 2> gather(Pos y, Pos x) const {
        using ret_t = Signed<T::integer, T::fraction + Pos::fraction * 2>;
        using Dist = Signed<0, Pos::fraction>;
        using Weight = Signed<0, Pos::fraction * 2>;
        Dist y_frac = static_cast<Signed<0, Pos::fraction>>(y.getFrac());
        Dist x_frac = static_cast<Signed<0, Pos::fraction>>(x.getFrac());
        //if y_frac or x_frac is 0, then we don't need to calculate the inverse and we will special case the later calculation
        Dist inv_y_frac = static_cast<Signed<0, Pos::fraction>>(y.inv());
        Dist inv_x_frac = static_cast<Signed<0, Pos::fraction>>(x.inv());
        using int_size = typename type_from_size<roundToNeareastIntSize(Pos::integer)>::utype;
        int_size y_int = y.getInt();
        int_size x_int = x.getInt();
        
        //overflow is dealt with by applying periodic boundary conditions in the lookup function
        T v00 = (*this)(y_int, x_int);
        T v01 = (*this)(y_int, x_int + 1);
        T v10 = (*this)(y_int + 1, x_int);
        T v11 = (*this)(y_int + 1, x_int + 1);

        if (y_frac == Dist{0.f} && x_frac == Dist{0.f}) return static_cast<ret_t>(v00);
        else if (y_frac == Dist{0.f}) return static_cast<ret_t>(static_cast<Weight>(inv_x_frac) *  (*this)(y_int, x_int) + static_cast<Weight>(x_frac) * v01);
        else if (x_frac == Dist{0.f}) return static_cast<ret_t>(static_cast<Weight>(inv_y_frac) * (*this)(y_int, x_int) + static_cast<Weight>(y_frac) * v10);
        else {

            Weight w00 = inv_y_frac * inv_x_frac;
            Weight w01 = inv_y_frac * x_frac;
            Weight w10 = y_frac * inv_x_frac;
            Weight w11 = y_frac * x_frac; 
            return static_cast<ret_t>((w00 * v00 + w01 * v01) + (w10 * v10 + w11 * v11));
        }
    }
        
private:
    std::array<T, GRID_SIZE> data;
    T min;
};

#endif // GRID_HPP