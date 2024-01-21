`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 09/22/2023 07:27:27 PM
// Design Name: 
// Module Name: plasma_sim_main
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


import defs::*;

module pusher (
    input logic clk, 
    input logic rst,
    input logic valid,
    input logic noop,
    input logic tlast_in, 
    input particle_t particle_in,
    input logic signed [3:0] [3:0] [3:0] [PHIWIDTH-1:0] phi_in,
    input logic [3:0] [3:0] [3:0] [BWIDTH-1:0] bmag_in,
    output logic valid_req,
    output logic [3:0] [3:0] [GRID_ADDRWIDTH-1:0] raddr,
    output logic valid_out,
    output logic tlast_out,
    output particle_t particle_out
    );

    //signal declarations
    particle_t particle [21:0];
    logic tlast [21:0];
    pos_t pos;
    logic [GRID_ADDRWIDTH-1:0] grid_addr;
    logic [3:0] [BWIDTH-1:0] bmag_out;
    logic [PSIZE:0] interpolated_user_out;
    logic [BWIDTH+PFRAC*2+1:0] total_short_bmag;
    logic [BWIDTH-1:0] bmag_ff;
    logic [25:0] gyroradius;
    logic [50:0] postdiv_info;
    logic [PWIDTH-1:0] gyroradius_ff;
    logic [3:0] [PWIDTH-1:0] gyropoints_y;
    logic [3:0] [PWIDTH-1:0] gyropoints_x;
    dist_t [3:0] dist_ff;
    dist_t [3:0] inv_dist_ff;
    logic signed [3:0] [3:0] [3:0] [PHIWIDTH-1:0] phi_in_ff;
    logic [3:0] [3:0] [3:0] [BWIDTH-1:0] bmag_in_ff;
    logic [3:0] [3:0] [PFRAC*2-1:0] coeff;
    logic [3:0] [3:0] [PFRAC*2-1:0] coeff_ff [1:0];
    logic signed [3:0] [3:0] [EWIDTH-1:0] efield_y;
    logic signed [3:0] [3:0] [EWIDTH-1:0] efield_x;
    logic signed [3:0] [3:0] [BWIDTH:0] gradb_y;
    logic signed [3:0] [3:0] [BWIDTH:0] gradb_x;
    logic [3:0] [3:0] [BWIDTH-1:0] bmag; 
    logic signed [3:0] [3:0] [EWIDTH+PFRAC*2-1:0] interpolated_efield_y;
    logic signed [3:0] [3:0] [EWIDTH+PFRAC*2-1:0] interpolated_efield_x;
    logic signed [3:0] [3:0] [BWIDTH+PFRAC*2:0] interpolated_gradb_y;
    logic signed [3:0] [3:0] [BWIDTH+PFRAC*2:0] interpolated_gradb_x;
    logic [3:0] [3:0] [BWIDTH+PFRAC*2-1:0] interpolated_bmag;
    logic signed [3:0] [3:0] [EWIDTH+PFRAC*2-1:0] interpolated_efield_y_ff;
    logic signed [3:0] [3:0] [EWIDTH+PFRAC*2-1:0] interpolated_efield_x_ff;
    logic signed [3:0] [3:0] [BWIDTH+PFRAC*2:0] interpolated_gradb_y_ff [1:0];
    logic signed [3:0] [3:0] [BWIDTH+PFRAC*2:0] interpolated_gradb_x_ff [1:0];
    logic [3:0] [3:0] [BWIDTH+PFRAC*2-1:0] interpolated_bmag_ff [1:0];
    logic signed [3:0] [1:0] [EWIDTH+PFRAC*2:0] total_efield_y_stage1;
    logic signed [3:0] [1:0] [EWIDTH+PFRAC*2:0] total_efield_x_stage1;
    logic signed [3:0] [1:0] [BWIDTH+PFRAC*2+1:0] total_gradb_y_stage1;
    logic signed [3:0] [1:0] [BWIDTH+PFRAC*2+1:0] total_gradb_x_stage1;
    logic [3:0] [1:0] [BWIDTH+PFRAC*2:0] total_bmag_stage1;
    logic signed [3:0] [EWIDTH+PFRAC*2+1:0] total_efield_y_stage2;
    logic signed [3:0] [EWIDTH+PFRAC*2+1:0] total_efield_x_stage2;
    logic signed [3:0] [BWIDTH+PFRAC*2+2:0] total_gradb_y_stage2;
    logic signed [3:0] [BWIDTH+PFRAC*2+2:0] total_gradb_x_stage2;
    logic [3:0] [BWIDTH+PFRAC*2+1:0] total_bmag_stage2;
    logic signed [1:0] [EWIDTH+PFRAC*2+2:0] total_efield_y_stage3;
    logic signed [1:0] [EWIDTH+PFRAC*2+2:0] total_efield_x_stage3;
    logic signed [1:0] [BWIDTH+PFRAC*2+3:0] total_gradb_y_stage3;
    logic signed [1:0] [BWIDTH+PFRAC*2+3:0] total_gradb_x_stage3;
    logic [1:0] [BWIDTH+PFRAC*2+2:0] total_bmag_stage3;
    logic signed [EWIDTH+PFRAC*2+3:0] total_efield_y;
    logic signed [EWIDTH+PFRAC*2+3:0] total_efield_x;
    logic signed [BWIDTH+PFRAC*2+4:0] total_gradb_y;
    logic signed [BWIDTH+PFRAC*2+4:0] total_gradb_x;
    logic [BWIDTH+PFRAC*2+3:0] total_bmag;
    logic [VPERPWIDTH*2-1:0] vperp_squared;
    logic [VPERPWIDTH*2-1:0] vperp_squared_ff;
    //only +1 because of division by 4
    logic signed [EWIDTH+PFRAC*2+1:0] scaled_total_efield_y;
    logic signed [EWIDTH+PFRAC*2+1:0] scaled_total_efield_x;
    logic signed [BWIDTH+PFRAC*2+2:0] scaled_total_gradb_y;
    logic signed [BWIDTH+PFRAC*2+2:0] scaled_total_gradb_x;
    logic [BWIDTH+PFRAC*2+1:0] scaled_total_bmag;
    logic signed [EWIDTH-1:0] true_efield_y;
    logic signed [EWIDTH-1:0] true_efield_x;
    logic signed [BWIDTH:0] true_gradb_y;
    logic signed [BWIDTH:0] true_gradb_x;
    logic [BWIDTH-1:0] true_bmag;

    logic [PSIZE:0] postexb_div_info;
    logic signed [EWIDTH+BWIDTH:0] exb_y;
    logic signed [EWIDTH+BWIDTH:0] exb_x;
    logic signed [PWIDTH:0] exb_y_ff;
    logic signed [PWIDTH:0] exb_x_ff;
    logic signed [BWIDTH*2+1:0] drift_y;
    logic signed [BWIDTH*2+1:0] drift_x;
    logic signed [PWIDTH:0] drift_y_ff [8:0];
    logic signed [PWIDTH:0] drift_x_ff [8:0];
    logic [33:0] mu;
    logic [MUWIDTH-1:0] mu_ff;
    logic signed [MUWIDTH+PWIDTH:0] gradb_vel_y;
    logic signed [MUWIDTH+PWIDTH:0] gradb_vel_x;

    //valids
    logic valid_interpolated;
    logic valid_bmag;
    logic valid_div;
    logic valid_gyroradius;
    logic valid_gyropoints;
    logic valid_raddr;
    logic valid_bram [2:0];
    logic valid_phi_in;
    logic valid_efield;
    logic valid_interpol [3:0];
    logic valid_interpolated_field;
    logic valid_stage1;
    logic valid_stage2;
    logic valid_stage3;
    logic valid_total;
    logic valid_true;
    logic valid_wait [9:0];
    logic valid_exb_div;
    logic valid_exb_pos;
    logic valid_drift_div;
    logic valid_drift_vel;
    logic valid_mu;
    logic valid_exb_vel;
    logic valid_last;

    function logic signed [PHIWIDTH:0] signExt(logic signed [PHIWIDTH-1:0] in);
        return {in[PHIWIDTH-1], in};
    endfunction

    function logic signed [BWIDTH+1:0] doubleExt(logic [BWIDTH-1:0] in);
        return $signed({2'b0, in});
    endfunction


    //module instantiations
    assign pos = {particle_in.y, particle_in.x};
    interpolator #(.DWIDTH(BWIDTH), .UWIDTH(PSIZE + 1)) bmag_interpolate (
        .clk(clk),
        .rst(rst),
        .valid(valid),
        .zero(1'b0),
        .pos(pos),
        .data_in(bmag_out),
        .user_in({tlast_in, particle_in}),
        .raddr_out(grid_addr),
        .valid_out(valid_interpolated),
        .interpolated_data_out(total_short_bmag),
        .user_out(interpolated_user_out)
    );

    grid_mem #(.WIDTH(BWIDTH), .NO_RST(1)) bmag_grid (
        .clk(clk),
        .rst(rst),
        .wea(4'b0),
        .web(4'b0),
        .addra(grid_addr),
        .addrb('0),
        .dina('0),
        .dinb('0),
        .uina('0),
        .uinb('0),
        .douta(bmag_out),
        .doutb(),
        .uouta(),
        .uoutb()
    );

    gyroradius_div gyro_div (
        .aclk(clk),                                      // input wire aclk
        .s_axis_divisor_tvalid(valid_bmag),    // input wire s_axis_divisor_tvalid
        .s_axis_divisor_tuser(tlast[0]),
        .s_axis_divisor_tdata(bmag_ff),      // input wire [15 : 0] s_axis_divisor_tdata
        .s_axis_dividend_tvalid(valid_bmag),  // input wire s_axis_dividend_tvalid
        .s_axis_dividend_tuser(particle[0]),    // input wire [35 : 0] s_axis_dividend_tuser
        .s_axis_dividend_tdata(particle[0].vperp),    // input wire [15 : 0] s_axis_dividend_tdata
        .m_axis_dout_tvalid(valid_div),          // output wire m_axis_dout_tvalid
        .m_axis_dout_tuser(postdiv_info),            // output wire [35 : 0] m_axis_dout_tuser
        .m_axis_dout_tdata(gyroradius)            // output wire [31 : 0] m_axis_dout_tdata
    );


    generate
        for (genvar i = 0; i < 4; i++) begin
             dist_mult mult00 (
                .CLK(clk),
                .A(inv_dist_ff[i].y_frac),
                .B(inv_dist_ff[i].x_frac),
                .P(coeff[i][0])
            );

            dist_mult mult01 (
                .CLK(clk),
                .A(inv_dist_ff[i].y_frac),
                .B(dist_ff[i].x_frac),
                .P(coeff[i][1])
            );

            dist_mult mult10 (
                .CLK(clk),
                .A(dist_ff[i].y_frac),
                .B(inv_dist_ff[i].x_frac),
                .P(coeff[i][2])
            );

            dist_mult mult11 (
                .CLK(clk),
                .A(dist_ff[i].y_frac),
                .B(dist_ff[i].x_frac),
                .P(coeff[i][3])
            );
        end
    endgenerate

    generate 
        for (genvar i = 0; i < 4; i++) begin
            for (genvar j = 0; j < 4; j++) begin
                efield_mult mult_efield_y (
                    .CLK(clk),
                    .A(efield_y[i][j]),
                    .B(coeff_ff[1][i][j]),
                    .P(interpolated_efield_y[i][j])
                );

                efield_mult mult_efield_x (
                    .CLK(clk),
                    .A(efield_x[i][j]),
                    .B(coeff_ff[1][i][j]),
                    .P(interpolated_efield_x[i][j])
                );

                gradb_mult mult_gradb_y (
                    .CLK(clk),
                    .A(gradb_y[i][j]),
                    .B(coeff_ff[1][i][j]),
                    .P(interpolated_gradb_y[i][j])
                );

                gradb_mult mult_gradb_x (
                    .CLK(clk),
                    .A(gradb_x[i][j]),
                    .B(coeff_ff[1][i][j]),
                    .P(interpolated_gradb_x[i][j])
                );

                bmag_mult mult_bmag (
                    .CLK(clk),
                    .A(coeff_ff[1][i][j]),
                    .B(bmag[i][j]),
                    .P(interpolated_bmag[i][j])
                );
            end
        end
    endgenerate

    vperp_squarer squarer (
        .CLK(clk),
        .A(particle[13].vperp),
        .B(particle[13].vperp),
        .P(vperp_squared)
    );
    
    assign scaled_total_efield_y = total_efield_y / 4;
    assign scaled_total_efield_x = total_efield_x / 4;
    assign scaled_total_gradb_y = total_gradb_y / 4;
    assign scaled_total_gradb_x = total_gradb_x / 4;
    assign scaled_total_bmag = total_bmag / 4;

    //here we implicitly perform the cross product by swapping x and y and negating y
    exb_div exb_div_y (
        .aclk(clk),                                      // input wire aclk
        .s_axis_divisor_tvalid(valid_true),    // input wire s_axis_divisor_tvalid
        .s_axis_divisor_tuser(tlast[18]),
        .s_axis_divisor_tdata($signed({1'b0, true_bmag})),      // input wire [15 : 0] s_axis_divisor_tdata
        .s_axis_dividend_tvalid(valid_total),  // input wire s_axis_dividend_tvalid
        .s_axis_dividend_tuser(particle[18]),
        .s_axis_dividend_tdata(true_efield_x),    // input wire [39 : 0] s_axis_dividend_tdata
        .m_axis_dout_tvalid(valid_exb_div),          // output wire m_axis_dout_tvalid
        .m_axis_dout_tuser(postexb_div_info),
        .m_axis_dout_tdata(exb_y)            // output wire [55 : 0] m_axis_dout_tdata
    );

    exb_div exb_div_x (
        .aclk(clk),                                      // input wire aclk
        .s_axis_divisor_tvalid(valid_true),    // input wire s_axis_divisor_tvalid
        .s_axis_divisor_tuser(1'b0),
        .s_axis_divisor_tdata($signed({1'b0, true_bmag})),      // input wire [15 : 0] s_axis_divisor_tdata
        .s_axis_dividend_tvalid(valid_total),  // input wire s_axis_dividend_tvalid
        .s_axis_dividend_tuser('0),
        .s_axis_dividend_tdata(-true_efield_y),    // input wire [39 : 0] s_axis_dividend_tdata
        .m_axis_dout_tvalid(),          // output wire m_axis_dout_tvalid
        .m_axis_dout_tuser(),
        .m_axis_dout_tdata(exb_x)            // output wire [55 : 0] m_axis_dout_tdata
    );

    drift_div drift_div_y (
        .aclk(clk),                                      // input wire aclk
        .s_axis_divisor_tvalid(valid_true),    // input wire s_axis_divisor_tvalid
        .s_axis_divisor_tdata($signed({1'b0, true_bmag})),      // input wire [15 : 0] s_axis_divisor_tdata
        .s_axis_dividend_tvalid(valid_total),  // input wire s_axis_dividend_tvalid
        .s_axis_dividend_tdata(true_gradb_x),    // input wire [15 : 0] s_axis_dividend_tdata
        .m_axis_dout_tvalid(valid_drift_div),          // output wire m_axis_dout_tvalid
        .m_axis_dout_tdata(drift_y)            // output wire [31 : 0] m_axis_dout_tdata
    );

    drift_div drift_div_x (
        .aclk(clk),                                      // input wire aclk
        .s_axis_divisor_tvalid(valid_true),    // input wire s_axis_divisor_tvalid
        .s_axis_divisor_tdata($signed({1'b0, true_bmag})),      // input wire [15 : 0] s_axis_divisor_tdata
        .s_axis_dividend_tvalid(valid_total),  // input wire s_axis_dividend_tvalid
        .s_axis_dividend_tdata(-true_gradb_y),    // input wire [15 : 0] s_axis_dividend_tdata
        .m_axis_dout_tvalid(),          // output wire m_axis_dout_tvalid
        .m_axis_dout_tdata(drift_x)            // output wire [31 : 0] m_axis_dout_tdata
    );

    mu_div mu_maker (
        .aclk(clk),                                      // input wire aclk
        .s_axis_divisor_tvalid(valid_true),    // input wire s_axis_divisor_tvalid
        .s_axis_divisor_tdata(true_bmag),      // input wire [15 : 0] s_axis_divisor_tdata
        .s_axis_dividend_tvalid(valid_total),  // input wire s_axis_dividend_tvalid
        .s_axis_dividend_tdata(vperp_squared_ff),    // input wire [31 : 0] s_axis_dividend_tdata
        .m_axis_dout_tvalid(valid_mu),          // output wire m_axis_dout_tvalid
        .m_axis_dout_tdata(mu)            // output wire [47 : 0] m_axis_dout_tdata
    );

    mu_mult gradb_mult_y (
        .CLK(clk),
        .A(drift_y_ff[8]),
        .B(mu_ff),
        .P(gradb_vel_y)
    );

    mu_mult gradb_mult_x (
        .CLK(clk),
        .A(drift_x_ff[8]),
        .B(mu_ff),
        .P(gradb_vel_x)
    );

    
    always @(posedge clk) begin
        if (rst) begin
            bmag_ff <= '0;
            gyroradius_ff <= '0;
            for (int i = 0; i < 4; i++) begin
                gyropoints_y[i] <= '0;
                gyropoints_x[i] <= '0;
                dist_ff[i] <= '0;
                inv_dist_ff[i] <= '0;
            end
            raddr <= '0;
            phi_in_ff <= '0;
            bmag_in_ff <= '0;
            coeff_ff[0] <= '0;
            coeff_ff[1] <= '0;
            for (int i = 0; i < 4; i++) begin
                efield_y[i] <= '0;
                efield_x[i] <= '0;
                gradb_y[i] <= '0;
                gradb_x[i] <= '0;
                bmag[i] <= '0;
                interpolated_efield_y_ff[i] <= '0;
                interpolated_efield_x_ff[i] <= '0;
                interpolated_gradb_y_ff[0][i] <= '0;
                interpolated_gradb_x_ff[0][i] <= '0;
                interpolated_gradb_y_ff[1][i] <= '0;
                interpolated_gradb_x_ff[1][i] <= '0;
                interpolated_bmag_ff[0][i] <= '0;
                interpolated_bmag_ff[1][i] <= '0;
                total_efield_y_stage1[i] <= '0;
                total_efield_x_stage1[i] <= '0;
                total_gradb_y_stage1[i] <= '0;
                total_gradb_x_stage1[i] <= '0;
                total_bmag_stage1[i] <= '0;
                total_efield_y_stage2[i] <= '0;
                total_efield_x_stage2[i] <= '0;
                total_gradb_y_stage2[i] <= '0;
                total_gradb_x_stage2[i] <= '0;
                total_bmag_stage2[i] <= '0;
            end
            for (int i = 0; i < 2; i++) begin
                total_efield_y_stage3[i] <= '0;
                total_efield_x_stage3[i] <= '0;
                total_gradb_y_stage3[i] <= '0;
                total_gradb_x_stage3[i] <= '0;
                total_bmag_stage3[i] <= '0;
            end
            total_efield_y <= '0;
            total_efield_x <= '0;
            total_gradb_y <= '0;
            total_gradb_x <= '0;
            total_bmag <= '0;
            vperp_squared_ff <= '0;
            exb_y_ff <= '0;
            exb_x_ff <= '0;
            for (int i = 0; i <= 8; i++) begin
                drift_y_ff[i] <= '0;
                drift_x_ff[i] <= '0;
            end
            mu_ff <= '0;
            for (int i = 0; i <= 21; i++) begin
                particle[i] <= '0;
                tlast[i] <= '0;
            end
            particle_out <= '0;
            valid_bmag <= 1'b0;
            valid_gyroradius <= 1'b0;
            valid_gyropoints <= 1'b0;
            valid_raddr <= 1'b0;
            valid_req <= 1'b0;
            for (int i = 0; i < 3; i++) begin
                valid_bram[i] <= 1'b0;
            end
            valid_phi_in <= 1'b0;
            valid_efield <= 1'b0;
            for (int i = 0; i < 4; i++) begin
                valid_interpol[i] <= 1'b0;
            end
            valid_interpolated_field <= 1'b0;
            valid_stage1 <= 1'b0;
            valid_stage2 <= 1'b0;
            valid_stage3 <= 1'b0;
            valid_total <= 1'b0;
            for (int i = 0; i <= 9; i++) begin
                valid_wait[i] <= 1'b0;
            end
            valid_exb_vel <= 1'b0;
            valid_exb_pos <= 1'b0;
            valid_last <= 1'b0;
            valid_out <= 1'b0;
            tlast_out <= 1'b0;
        end else begin
            //first we need to get the value of bmag at the particle
            if (valid_interpolated) begin
                    bmag_ff <= total_short_bmag[BWIDTH+PFRAC*2-1-:BWIDTH];  //+ BMIN;
                    particle[0] <= interpolated_user_out[PSIZE-1:0];
                    tlast[0] <= interpolated_user_out[PSIZE];
                    valid_bmag <= 1'b1;
            end else begin
                valid_bmag <= 1'b0;
            end

            if (valid_div) begin
                gyroradius_ff <= gyroradius[PWIDTH-1:0]; //{3'b0, gyroradius[VPERPWIDTH+BWIDTH-1-:PWIDTH-3]};
                particle[1] <= postdiv_info[PSIZE:1];
                tlast[1] <= postdiv_info[0];
                valid_gyroradius <= 1'b1;
            end else begin
                valid_gyroradius <= 1'b0;
            end

            //calculate the four gyropoints
            if (valid_gyroradius) begin
                for (int i = 0; i < 4; i++) begin
                    gyropoints_y[i] <= particle[2].y + (i[1] ? (i[0] ? gyroradius_ff : -gyroradius_ff) : 1'b0);
                    gyropoints_x[i] <= particle[2].x + (i[1] ? 1'b0 : (i[0] ? gyroradius_ff : -gyroradius_ff));
                end
                particle[2] <= particle[1];
                tlast[2] <= tlast[1];
                valid_gyropoints <= 1'b1;
            end else begin
                valid_gyropoints <= 1'b0;
            end

            if (valid_gyropoints) begin
            //calculate the 16 adresses we need to read phi and bmag from, and calculate the coefficients
                for (int i = 0; i < 4; i++) begin
                    raddr[i][0] <= {gyropoints_y[i][PWIDTH-1-:PINT] - 1, gyropoints_x[i][PWIDTH-1-:PINT] - 1};
                    raddr[i][1] <= {gyropoints_y[i][PWIDTH-1-:PINT] - 1, gyropoints_x[i][PWIDTH-1-:PINT]};
                    raddr[i][2] <= {gyropoints_y[i][PWIDTH-1-:PINT], gyropoints_x[i][PWIDTH-1-:PINT] - 1};
                    raddr[i][3] <= {gyropoints_y[i][PWIDTH-1-:PINT], gyropoints_x[i][PWIDTH-1-:PINT]};
                    dist_ff[i] <= {gyropoints_y[i][PFRAC-1:0], gyropoints_x[i][PFRAC-1:0]};
                    inv_dist_ff[i] <= {(12'b1 << PFRAC) - gyropoints_y[i][PFRAC-1:0], (12'b1 << PFRAC) - gyropoints_x[i][PFRAC-1:0]};
                end
                particle[3] <= particle[2];
                tlast[3] <= tlast[2];
                valid_req <= 1'b1;
                valid_raddr <= 1'b1;
            end else begin
                valid_req <= 1'b0;
                valid_raddr <= 1'b0;
            end
            
            //wait three clocks for phi bram to be read and for dist mult to be performed            
            if (valid_raddr) begin
                valid_bram[0] <= 1'b1;
                particle[4] <= particle[3];
                tlast[4] <= tlast[3];
            end else begin
                valid_bram[0] <= 1'b1;
            end

            for (int i = 1; i < 3; i++) begin
                if (valid_bram[i-1]) begin
                    valid_bram[i] <= 1'b1;
                    particle[i+4] <= particle[i+3];
                    tlast[i+4] <= tlast[i+3];
                end else begin
                    valid_bram[i] <= 1'b0;
                end
            end

            if (valid_bram[2]) begin
                phi_in_ff <= phi_in;
                bmag_in_ff <= bmag_in;
                coeff_ff[0] <= coeff;
                particle[7] <= particle[6];
                tlast[7] <= tlast[6];
                valid_phi_in <= 1'b1;
            end else begin
                valid_phi_in <= 1'b0;
            end

            //calculate the e-field at the gyropoints
            if (valid_phi_in) begin
                for (int i = 0; i < 4; i++) begin
                    efield_y[i][0] <= (signExt(phi_in_ff[i][2][1]) - signExt(phi_in_ff[i][0][1])) / 2;
                    efield_x[i][0] <= (signExt(phi_in_ff[i][1][2]) - signExt(phi_in_ff[i][0][2])) / 2;
                    efield_y[i][1] <= (signExt(phi_in_ff[i][3][0]) - signExt(phi_in_ff[i][1][0])) / 2;
                    efield_x[i][1] <= (signExt(phi_in_ff[i][1][3]) - signExt(phi_in_ff[i][0][3])) / 2;
                    efield_y[i][2] <= (signExt(phi_in_ff[i][2][3]) - signExt(phi_in_ff[i][0][3])) / 2;
                    efield_x[i][2] <= (signExt(phi_in_ff[i][3][0]) - signExt(phi_in_ff[i][2][0])) / 2;
                    efield_y[i][3] <= (signExt(phi_in_ff[i][3][2]) - signExt(phi_in_ff[i][1][2])) / 2;
                    efield_x[i][3] <= (signExt(phi_in_ff[i][3][1]) - signExt(phi_in_ff[i][2][1])) / 2;
                    gradb_y[i][0] <= (doubleExt(bmag_in_ff[i][2][1]) - doubleExt(bmag_in_ff[i][0][1])) / 2;
                    gradb_x[i][0] <= (doubleExt(bmag_in_ff[i][1][2]) - doubleExt(bmag_in_ff[i][0][2])) / 2;
                    gradb_y[i][1] <= (doubleExt(bmag_in_ff[i][3][0]) - doubleExt(bmag_in_ff[i][1][0])) / 2;
                    gradb_x[i][1] <= (doubleExt(bmag_in_ff[i][1][3]) - doubleExt(bmag_in_ff[i][0][3])) / 2;
                    gradb_y[i][2] <= (doubleExt(bmag_in_ff[i][2][3]) - doubleExt(bmag_in_ff[i][0][3])) / 2;
                    gradb_x[i][2] <= (doubleExt(bmag_in_ff[i][3][0]) - doubleExt(bmag_in_ff[i][2][0])) / 2;
                    gradb_y[i][3] <= (doubleExt(bmag_in_ff[i][3][2]) - doubleExt(bmag_in_ff[i][1][2])) / 2;
                    gradb_x[i][3] <= (doubleExt(bmag_in_ff[i][3][1]) - doubleExt(bmag_in_ff[i][2][1])) / 2;
                    bmag[i][0] <= bmag_in_ff[0][3];
                    bmag[i][1] <= bmag_in_ff[1][2];
                    bmag[i][2] <= bmag_in_ff[2][1];
                    bmag[i][3] <= bmag_in_ff[3][0];
                end
                coeff_ff[1] <= coeff_ff[0];
                particle[8] <= particle[7];
                tlast[8] <= tlast[7];
                valid_efield <= 1'b1;
            end else begin
                valid_efield <= 1'b0;
            end

            //wait four clocks for the e-fields to be interpolated, and 3 clocks for gradB and bmag to be interpolated
            if (valid_efield) begin
                valid_interpol[0] <= 1'b1;  
                particle[9] <= particle[8];
                tlast[9] <= tlast[8];
            end else begin 
                valid_interpol[0] <= 1'b0;
            end

            if (valid_interpol[0]) begin
                particle[10] <= particle[9];
                tlast[10] <= tlast[9];
                valid_interpol[1] <= 1'b1;
            end else begin
                valid_interpol[1] <= 1'b0;
            end

            if (valid_interpol[1]) begin
                particle[11] <= particle[10];
                tlast[11] <= tlast[10];
                valid_interpol[2] <= 1'b1;
            end else begin
                valid_interpol[2] <= 1'b0;
            end

            if (valid_interpol[2]) begin
                interpolated_gradb_x_ff[0] <= interpolated_gradb_x;
                interpolated_gradb_y_ff[0] <= interpolated_gradb_y;
                interpolated_bmag_ff[0] <= interpolated_bmag;
                particle[12] <= particle[11];
                tlast[12] <= tlast[11];
                valid_interpol[3] <= 1'b1;
            end else begin
                valid_interpol[3] <= 1'b0;
            end

            if (valid_interpol[3]) begin
                interpolated_efield_x_ff <= interpolated_efield_x;
                interpolated_efield_y_ff <= interpolated_efield_y;
                interpolated_gradb_y_ff[1] <= interpolated_gradb_y_ff[0];
                interpolated_gradb_x_ff[1] <= interpolated_gradb_x_ff[0];
                interpolated_bmag_ff[1] <= interpolated_bmag_ff[0];
                particle[13] <= particle[12];
                tlast[13] <= tlast[12];
                valid_interpolated_field <= 1'b1;
            end else begin
                valid_interpolated_field <= 1'b0;
            end

            //use a binary adder tree to add all of the e-fields, gradB and bmags together
            if (valid_interpolated_field) begin
                for (int i = 0; i < 4; i++) begin
                    for (int j = 0; j < 2; j++) begin
                        total_efield_y_stage1[i][j] <= interpolated_efield_y_ff[i][j] + interpolated_efield_y_ff[i][j+2];
                        total_efield_x_stage1[i][j] <= interpolated_efield_x_ff[i][j] + interpolated_efield_x_ff[i][j+2];
                        total_gradb_y_stage1[i][j] <= interpolated_gradb_y_ff[1][i][j] + interpolated_gradb_y_ff[1][i][j+2];
                        total_gradb_x_stage1[i][j] <= interpolated_gradb_x_ff[1][i][j] + interpolated_gradb_x_ff[1][i][j+2];
                        total_bmag_stage1[i][j] <= interpolated_bmag_ff[1][i][j] + interpolated_bmag_ff[1][i][j+2];
                    end
                end
                particle[14] <= particle[13];
                tlast[14] <= tlast[13];
                valid_stage1 <= 1'b1;
            end else begin
                valid_stage1 <= 1'b0;
            end

            if (valid_stage1) begin
                for (int i = 0; i < 4; i++) begin
                    total_efield_y_stage2[i] <= total_efield_y_stage1[i][0] + total_efield_y_stage1[i][1];
                    total_efield_x_stage2[i] <= total_efield_x_stage1[i][0] + total_efield_x_stage1[i][1];
                    total_gradb_y_stage2[i] <= total_gradb_y_stage1[i][0] + total_gradb_y_stage1[i][1];
                    total_gradb_x_stage2[i] <= total_gradb_x_stage1[i][0] + total_gradb_x_stage1[i][1];
                    total_bmag_stage2[i] <= total_bmag_stage1[i][0] + total_bmag_stage1[i][1];
                end
                particle[15] <= particle[14];
                tlast[15] <= tlast[14];
                valid_stage2 <= 1'b1;
            end else begin
                valid_stage2 <= 1'b0;
            end

            if (valid_stage2) begin
                for (int i = 0; i < 2; i++) begin
                    total_efield_y_stage3[i] <= total_efield_y_stage2[i] + total_efield_y_stage2[i+2];
                    total_efield_x_stage3[i] <= total_efield_x_stage2[i] + total_efield_x_stage2[i+2];
                    total_gradb_y_stage3[i] <= total_gradb_y_stage2[i] + total_gradb_y_stage2[i+2];
                    total_gradb_x_stage3[i] <= total_gradb_x_stage2[i] + total_gradb_x_stage2[i+2];
                    total_bmag_stage3[i] <= total_bmag_stage2[i] + total_bmag_stage2[i+2];
                end
                particle[16] <= particle[15];
                tlast[16] <= tlast[15];
                valid_stage3 <= 1'b1;
            end else begin
                valid_stage3 <= 1'b0;
            end

            if (valid_stage3) begin
                total_efield_y <= total_efield_y_stage3[0] + total_efield_y_stage3[1];
                total_efield_x <= total_efield_x_stage3[0] + total_efield_x_stage3[1];
                total_gradb_y <= total_gradb_y_stage3[0] + total_gradb_y_stage3[1];
                total_gradb_x <= total_gradb_x_stage3[0] + total_gradb_x_stage3[1];
                total_bmag <= total_bmag_stage3[0] + total_bmag_stage3[1];
                vperp_squared_ff <= vperp_squared;
                particle[17] <= particle[16];
                tlast[17] <= tlast[16];
                valid_total <= 1'b1;
            end else begin
                valid_total <= 1'b0;
            end

            if (valid_total) begin
                true_efield_y <= {scaled_total_efield_y[EWIDTH+PFRAC*2+1], scaled_total_efield_y[EWIDTH+PFRAC*2-1-:EWIDTH-1]};
                true_efield_x <= {scaled_total_efield_x[EWIDTH+PFRAC*2+1], scaled_total_efield_x[EWIDTH+PFRAC*2-1-:EWIDTH-1]};
                true_gradb_y <= {scaled_total_gradb_y[BWIDTH+PFRAC*2+2], scaled_total_gradb_y[BWIDTH+PFRAC*2-1-:BWIDTH]};
                true_gradb_x <= {scaled_total_gradb_x[BWIDTH+PFRAC*2+2], scaled_total_gradb_x[BWIDTH+PFRAC*2-1-:BWIDTH]};
                true_bmag = scaled_total_bmag[BWIDTH+PFRAC*2-1-:BWIDTH];
                particle[18] <= particle[17];
                tlast[18] <= tlast[17];
                valid_true <= 1'b1;
            end else begin
                valid_true <= 1'b0;
            end

            
            if (valid_drift_div) begin
                drift_y_ff[0] <= {drift_y[BWIDTH*2+1], drift_y[PWIDTH-1:0]};
                drift_x_ff[0] <= {drift_x[BWIDTH*2+1], drift_x[PWIDTH-1:0]};
                valid_drift_vel <= 1'b1;
            end else begin
                valid_drift_vel <= 1'b0;
            end

            //wait 6 clocks for mu to be calculated
            if (valid_drift_vel) begin
                drift_y_ff[1] <= drift_y_ff[0];
                drift_x_ff[1] <= drift_x_ff[0];
                valid_wait[0] <= 1'b1;
            end else begin
                valid_wait[0] <= 1'b0;
            end

            for (int i = 1; i < 7; i++) begin
                if (valid_wait[i-1]) begin
                    valid_wait[i] <= 1'b1;
                    drift_y_ff[i+1] <= drift_y_ff[i];
                    drift_x_ff[i+1] <= drift_x_ff[i];
                end else begin
                    valid_wait[i] <= 1'b0;
                end
            end

            if (valid_wait[6]) begin
                mu_ff <= mu[MUWIDTH-1:0];
                drift_y_ff[8] <= drift_y_ff[7];
            end

            //wait three clocks to multiply drift velocity by mu
            
            //first clock, nothing happens

            //second clock
            if (valid_exb_div) begin
                exb_y_ff <= {exb_y[EWIDTH+BWIDTH], exb_y[38-:PWIDTH]};
                exb_x_ff <= {exb_x[EWIDTH+BWIDTH], exb_x[38-:PWIDTH]};
                particle[19] <= postexb_div_info[PSIZE:1];
                tlast[19] <= postexb_div_info[0];
                valid_exb_vel <= 1'b1;
            end else begin
                valid_exb_vel <= 1'b0;
            end

            //third clock
            if (valid_exb_vel) begin
                particle[20].y <= noop ? particle[19].y : (particle[19].y + exb_y_ff);
                particle[20].x <= noop ? particle[19].x : (particle[19].x + exb_x_ff);
                particle[20].vperp <= particle[19].vperp;
                tlast[20] <= tlast[19];
                valid_exb_pos <= 1'b1;
            end else begin
                valid_exb_pos <= 1'b0;
            end

            //fourth clock
            if (valid_exb_pos) begin
                particle[21] <= particle[20];
                tlast[21] <= tlast[20];
                valid_last <= 1'b1;
            end else begin
                valid_last <= 1'b0;
            end

            if (valid_last) begin
                particle_out.y <= noop ? particle[21].y : (particle[21].y + {gradb_vel_y[MUWIDTH+PWIDTH], gradb_vel_y[MUWIDTH+PWIDTH-5-:PWIDTH]});
                particle_out.x <= noop ? particle[21].x : (particle[21].x + {gradb_vel_x[MUWIDTH+PWIDTH], gradb_vel_x[MUWIDTH+PWIDTH-5-:PWIDTH]});
                particle_out.vperp <= particle[21].vperp;
                tlast_out <= tlast[21];
                valid_out <= 1'b1;
            end else begin
                valid_out <= 1'b0;
            end
        end
    end
endmodule

/* efield_y[i][0] <= (signExt(phi_in_ff[i][2][1]) - signExt(phi_in_ff[i][0][1])) / 2;
efield_x[i][0] <= (signExt(phi_in_ff[i][1][2]) - signExt(phi_in_ff[i][0][2])) / 2;
efield_y[i][1] <= (signExt(phi_in_ff[i][3][0]) - signExt(phi_in_ff[i][1][0])) / 2;
efield_x[i][1] <= (signExt(phi_in_ff[i][1][3]) - signExt(phi_in_ff[i][0][3])) / 2;
efield_y[i][2] <= (signExt(phi_in_ff[i][2][3]) - signExt(phi_in_ff[i][0][3])) / 2;
efield_x[i][2] <= (signExt(phi_in_ff[i][3][0]) - signExt(phi_in_ff[i][2][0])) / 2;
efield_y[i][3] <= (signExt(phi_in_ff[i][3][2]) - signExt(phi_in_ff[i][1][2])) / 2;
efield_x[i][3] <= (signExt(phi_in_ff[i][3][1]) - signExt(phi_in_ff[i][2][1])) / 2; */