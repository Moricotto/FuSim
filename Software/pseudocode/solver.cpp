solve(gyroradii, rho) {
    phi = 0;
    for (int it = 0; it < NUM_IT; it++) {
        for (int y = 0; y < GRIDY; y++) {
            for (int x = 0; x < GRIDX; x++) {
                total_phi = 0;
                for (int v = 0; v < NUM_VPERP; v++) {
                    gyroradius = gyroradii[v](y, x);
                    double_gyroradius = 2 * gyroradius;
                    for (int i = 0; i < 4; i++) {
                        total_phi += weights[v] * phi.gather(
                            (i == 0 || i == 1) ? y - gyroradius : y + gyroradius, 
                            (i == 0 || i == 2) ? x - gyroradius : x + gyroradius) / 8;
                        total_phi += weights[v] * phi.gather(
                            (i == 0 || i == 1) ? y : (i == 2 ? y - double_gyroradius : y + double_gyroradius), 
                            (i == 2 || i == 3) ? x : (i == 0 ? x - double_gyroradius : x + double_gyroradius)) / 16;
                    }
                }
                new_phi(y, x) = (rho(y, x) - total_phi) / diag_const;
            }
        }
        phi = new_phi;
    };
    return phi;
}