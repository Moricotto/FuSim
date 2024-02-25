#include "pusher.hpp"

const Unsigned<Pos::integer + 1, Pos::fraction> gridx = Unsigned<Pos::integer + 1, Pos::fraction>{(float)GRIDX};
const Unsigned<Pos::integer + 1, Pos::fraction> gridy = Unsigned<Pos::integer + 1, Pos::fraction>{(float)GRIDY};

void push(Particles& particles, const UGrid<Bmag>& bmag, const SGrid<Phi>& phi) {
    using InterpEfield = Signed<Efield::integer, Efield::fraction + Pos::fraction * 2>;
    using EVec = Pair<InterpEfield>;
    using InterpGradB = Signed<GradB::integer, GradB::fraction + Pos::fraction * 2>;
    using GradBVec = Pair<InterpGradB>;
    using InterpBmag = Unsigned<Bmag::integer, Bmag::fraction + Pos::fraction * 2>;
    using Disp = Signed<Pos::integer, Pos::fraction>;
    using GradBxB = Signed<2, 12>;

    for (Particle& particle : particles) {
        //first step is to interpolate the bmag to the particle position
        Bmag interpolated = Bmag{bmag.gather(particle.y, particle.x)}; 
        //next, we calculate the gyroradius
        Pos gyroradius = Pos{particle.vperp.div<12, Bmag::integer, Bmag::fraction>(interpolated)};
        //next, we get phi and bmag in a starburst pattern around the particle
        //four gyropoints, four corners per gyropoint, four points  per corner (of which only three are used)
        std::array<std::array<std::array<Phi, 4>, 4>, 4> phi_starburst = {0.f};
        std::array<std::array<std::array<Bmag, 4>, 4>, 4> bmag_starburst = {0.f};

        std::array<std::array<Pair<Efield>, 4>, 4> efield = {0.f, 0.f};
        std::array<std::array<Pair<GradB>, 4>, 4> grad_b = {0.f, 0.f};
        std::array<std::array<Bmag, 4>, 4> bmags = {0.f};

        std::array<Pair<InterpEfield>, 4> interpolated_efield = {0.f, 0.f};
        std::array<Pair<InterpGradB>, 4> interpolated_grad_b = {0.f, 0.f};
        std::array<InterpBmag, 4> interpolated_bmag = {0.f};

        for (int i = 0; i < 4; i++) {
            //calculate the four gyropoints
            PosPair gyropoint = {
                (i == 0 || i == 1) ? particle.y : (i == 2 ? particle.y.wrapping_minus(gyroradius) : particle.y.wrapping_add(gyroradius)),
                (i == 2 || i == 3) ? particle.x : (i == 0 ? particle.x.wrapping_minus(gyroradius) : particle.y.wrapping_add(gyroradius))
            };
            using Addr = std::pair<int8_t, int8_t>;
            Addr gyro_addr = std::make_pair(gyropoint.y.getInt(), gyropoint.x.getInt());

            //populate the arrays with the relevant phi and bmag values
            for (int j = 0; j < 4; j++) {
                //get bottom_right gridpoint of each square of the current gyropoint
                Addr base_addr = std::make_pair(gyro_addr.first + (j == 0 || j == 1 ? -1 : 0), gyro_addr.second + (j == 0 || j == 2 ? -1 : 0));
                for (int k = 0; k < 4; k++) {
                    //get the four gridpoints in each square
                    Addr addr = std::make_pair(base_addr.first + (k == 0 || k == 1 ? 0 : 1), base_addr.second + (k == 0 || k == 2 ? 0 : 1));
                    phi_starburst[i][j][k] = phi(addr.first, addr.second);
                    bmag_starburst[i][j][k] = bmag(addr.first, addr.second);
                }
            }

            efield[i][0] = Pair<Efield>{static_cast<Efield>((phi_starburst[i][2][1] - phi_starburst[i][0][1]) >> 1), static_cast<Efield>((phi_starburst[i][1][2] - phi_starburst[i][0][2]) >> 1)};
            efield[i][1] = Pair<Efield>{static_cast<Efield>((phi_starburst[i][3][0] - phi_starburst[i][1][0]) >> 1), static_cast<Efield>((phi_starburst[i][1][3] - phi_starburst[i][0][3]) >> 1)};
            efield[i][2] = Pair<Efield>{static_cast<Efield>((phi_starburst[i][2][3] - phi_starburst[i][0][3]) >> 1), static_cast<Efield>((phi_starburst[i][3][0] - phi_starburst[i][2][0]) >> 1)};
            efield[i][3] = Pair<Efield>{static_cast<Efield>((phi_starburst[i][3][2] - phi_starburst[i][1][2]) >> 1), static_cast<Efield>((phi_starburst[i][3][1] - phi_starburst[i][2][1]) >> 1)};
            grad_b[i][0] = Pair<GradB>{static_cast<GradB>((static_cast<GradB>(bmag_starburst[i][2][1]) - static_cast<GradB>(bmag_starburst[i][0][1])) >> 1), static_cast<GradB>((static_cast<GradB>(bmag_starburst[i][1][2]) - static_cast<GradB>(bmag_starburst[i][0][2])) >> 1)};
            grad_b[i][1] = Pair<GradB>{static_cast<GradB>((static_cast<GradB>(bmag_starburst[i][3][0]) - static_cast<GradB>(bmag_starburst[i][1][0])) >> 1), static_cast<GradB>((static_cast<GradB>(bmag_starburst[i][1][3]) - static_cast<GradB>(bmag_starburst[i][0][3])) >> 1)};
            grad_b[i][2] = Pair<GradB>{static_cast<GradB>((static_cast<GradB>(bmag_starburst[i][2][3]) - static_cast<GradB>(bmag_starburst[i][0][3])) >> 1), static_cast<GradB>((static_cast<GradB>(bmag_starburst[i][3][0]) - static_cast<GradB>(bmag_starburst[i][2][0])) >> 1)};
            grad_b[i][3] = Pair<GradB>{static_cast<GradB>((static_cast<GradB>(bmag_starburst[i][3][2]) - static_cast<GradB>(bmag_starburst[i][1][2])) >> 1), static_cast<GradB>((static_cast<GradB>(bmag_starburst[i][3][1]) - static_cast<GradB>(bmag_starburst[i][2][1])) >> 1)}; 
            bmags[i][0] = bmag_starburst[i][0][3];
            bmags[i][1] = bmag_starburst[i][1][2];
            bmags[i][2] = bmag_starburst[i][2][1];
            bmags[i][3] = bmag_starburst[i][3][0];

            //calculate interpolation coefficients
            using Dist = Unsigned<0, Pos::fraction>;
            using Weight = Unsigned<0, Pos::fraction * 2>;
            Dist y_frac = static_cast<Dist>(gyropoint.y.getFrac());
            Dist x_frac = static_cast<Dist>(gyropoint.x.getFrac());
            Dist inv_y_frac = static_cast<Dist>(gyropoint.y.inv());
            Dist inv_x_frac = static_cast<Dist>(gyropoint.x.inv());
            if (y_frac == Dist{0.f} && x_frac == Dist{0.f}) {
                interpolated_efield[i] = static_cast<EVec>(efield[i][0]);
                interpolated_grad_b[i] = static_cast<GradBVec>(grad_b[i][0]);
                interpolated_bmag[i] = static_cast<InterpBmag>(bmags[i][0]);
            } else if (y_frac == Dist{0.f}) { 
                interpolated_efield[i] = EVec{static_cast<InterpEfield>(static_cast<Weight>(inv_x_frac) * efield[i][0].y + static_cast<Weight>(x_frac) * efield[i][1].y), 
                                static_cast<InterpEfield>(static_cast<Weight>(inv_x_frac) * efield[i][0].x + static_cast<Weight>(x_frac) * efield[i][1].x)};
                interpolated_grad_b[i] = GradBVec{static_cast<InterpGradB>(static_cast<Weight>(inv_x_frac) * grad_b[i][0].y + static_cast<Weight>(x_frac) * grad_b[i][1].y), 
                                static_cast<InterpGradB>(static_cast<Weight>(inv_x_frac) * grad_b[i][0].x + static_cast<Weight>(x_frac) * grad_b[i][1].x)};
                interpolated_bmag[i] = static_cast<InterpBmag>(static_cast<Weight>(inv_x_frac) * bmags[i][0] + static_cast<Weight>(x_frac) * bmags[i][1]);
            } else if (x_frac == Dist{0.f}) {
                interpolated_efield[i] = EVec{static_cast<InterpEfield>(static_cast<Weight>(inv_y_frac) * efield[i][0].y + static_cast<Weight>(y_frac) * efield[i][2].y), 
                                static_cast<InterpEfield>(static_cast<Weight>(inv_y_frac) * efield[i][0].x + static_cast<Weight>(y_frac) * efield[i][2].x)};
                interpolated_grad_b[i] = GradBVec{static_cast<InterpGradB>(static_cast<Weight>(inv_y_frac) * grad_b[i][0].y + static_cast<Weight>(y_frac) * grad_b[i][2].y), 
                                static_cast<InterpGradB>(static_cast<Weight>(inv_y_frac) * grad_b[i][0].x + static_cast<Weight>(y_frac) * grad_b[i][2].x)};
                interpolated_bmag[i] = static_cast<InterpBmag>(static_cast<Weight>(inv_y_frac) * bmags[i][0] + static_cast<Weight>(y_frac) * bmags[i][2]);
            } else {
                Weight w00 = inv_y_frac * inv_x_frac;
                Weight w01 = inv_y_frac * x_frac;
                Weight w10 = y_frac * inv_x_frac;
                Weight w11 = y_frac * x_frac; 
                interpolated_efield[i] = EVec{static_cast<InterpEfield>((w00 * efield[i][0].y + w01 * efield[i][1].y) + (w10 * efield[i][2].y + w11 * efield[i][3].y)),
                                static_cast<InterpEfield>((w00 * efield[i][0].x + w01 * efield[i][1].x) + (w10 * efield[i][2].x + w11 * efield[i][3].x))};
                interpolated_grad_b[i] = GradBVec{static_cast<InterpGradB>((w00 * grad_b[i][0].y + w01 * grad_b[i][1].y) + (w10 * grad_b[i][2].y + w11 * grad_b[i][3].y)),
                                static_cast<InterpGradB>((w00 * grad_b[i][0].x + w01 * grad_b[i][1].x) + (w10 * grad_b[i][2].x + w11 * grad_b[i][3].x))};
                interpolated_bmag[i] = static_cast<InterpBmag>((w00 * bmags[i][0] + w01 * bmags[i][1]) + (w10 * bmags[i][2] + w11 * bmags[i][3]));
            }
        }

        EVec total_efield = {0.f, 0.f};
        GradBVec total_gradB = {0.f, 0.f};
        InterpBmag total_bmag = 0.f;
        for (int i = 0; i < 4; i++) {
            total_efield.y += interpolated_efield[i].y >> 2;
            total_efield.x += interpolated_efield[i].x >> 2;
            total_gradB.y += interpolated_grad_b[i].y >> 2;
            total_gradB.x += interpolated_grad_b[i].x >> 2;
            total_bmag += interpolated_bmag[i] >> 2;
        }
        Pair<Efield> true_efield = static_cast<Pair<Efield>>(total_efield);
        Pair<GradB> true_grad_b = static_cast<Pair<GradB>>(total_gradB);
        Bmag true_bmag = static_cast<Bmag>(total_bmag);
        Efield
        //now we divide the totalEfield by the totalBmag and implicitly take the cross product with the b unit vector to get the ExB drift velocity
        Pair<Disp> exb_disp = Pair<Disp>{static_cast<Disp>(true_efield.x.div<15 + SLOWDOWN, Bmag::integer, Bmag::fraction>(static_cast<Signed<Bmag::integer, Bmag::fraction>>(true_bmag)) >> SLOWDOWN), static_cast<Disp>((-true_efield.y).div<15 + SLOWDOWN, Bmag::integer, Bmag::fraction>(static_cast<Signed<Bmag::integer, Bmag::fraction>>(true_bmag))  >> SLOWDOWN)};
        //same for the gradB drift velocity
        Pair<GradBxB> gradb_drift = Pair<GradBxB>{static_cast<GradBxB>(true_grad_b.x.div<12 + SLOWDOWN, Bmag::integer, Bmag::fraction>(static_cast<Signed<Bmag::integer, Bmag::fraction>>(true_bmag)) >> SLOWDOWN), static_cast<GradBxB>((-true_grad_b.y).div<12 + SLOWDOWN, Bmag::integer, Bmag::fraction>(static_cast<Signed<Bmag::integer, Bmag::fraction>>(true_bmag)) >> SLOWDOWN)};
        //we need to multiply this velocity by mu
        Unsigned<Vel::integer * 2, Vel::fraction * 2> vperp_squared = particle.vperp * particle.vperp;
        //then we divide by the magnetic field
        Unsigned<Vel::integer * 2 + Bmag::fraction, Pos::fraction> mu = vperp_squared.div<Pos::fraction, Bmag::integer, Bmag::fraction>(true_bmag);
        Pair<Disp> gradb_disp = Pair<Disp>{static_cast<Disp>(mu * gradb_drift.x), static_cast<Disp>(mu * gradb_drift.y)};
        //now we add the drift velocities to the particle position
        Pair<Disp> drift_disp = Pair<Disp>{static_cast<Disp>(exb_disp.y + gradb_disp.y), static_cast<Disp>(exb_disp.x + gradb_disp.x)};
        Pair<Pos> abs_disp = Pair<Pos>{static_cast<Pos>(drift_disp.y), static_cast<Pos>(drift_disp.x)};
        //if the particle would leave the simulation domain, instead it wraps around
        particle.y = drift_disp.y < 0 ? particle.y.wrapping_add(abs_disp.y) : particle.y.wrapping_minus(abs_disp.y);
        particle.x = drift_disp.x < 0 ? particle.x.wrapping_add(abs_disp.x) : particle.x.wrapping_minus(abs_disp.x);
    }
}