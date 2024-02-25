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
    //to/from full_pusher
    input logic valid,
    input logic noop,
    input particle_t particle_in,
    output logic valid_out,
    output particle_t particle_out,
    output logic done,
    //to/from solver and bmag grid_mem
    input phi_t [3:0] [2:0] [3:0] phi_in,
    input bmag_t [3:0] [2:0] [3:0] bmag_in,
    output logic valid_req,
    output addr_t [3:0] [2:0] [3:0] raddr
    );

    //signal declarations
    logic rst_ff;
    particle_t particle [21:0];
    posvec_t pos;
    addr_t [3:0] grid_addr;
    bmag_t [3:0] bmag_out;
    particle_t interpolator_particle_out;
    logic [BWIDTH+PFRAC*2-1:0] total_short_bmag;
    bmag_t bmag_ff;
    logic [31:0] divider_out;
    particle_t divider_particle_out;
    pos_t gyroradius_ff;
    pos_t [3:0] gyropoints_y;
    pos_t [3:0] gyropoints_x;
    dist_t [3:0] dist_ff [3:0];
    dist_t [3:0] inv_dist_ff [3:0];
    logic [3:0] special [6:0];
    coeff_t [3:0] [3:0] coeff;
    coeff_t [3:0] [3:0] coeff_ff [2:0];
    phi_t [3:0] [3:0] [3:0] phi_in_ff;
    bmag_t [3:0] [3:0] [3:0] bmag_in_ff;
    elect_t [3:0] [3:0] efield_y;
    elect_t [3:0] [3:0] efield_x;
    gradb_t [3:0] [3:0] gradb_y;
    gradb_t [3:0] [3:0] gradb_x;
    bmag_t [3:0] [3:0] bmag; 
    elect_t [3:0]  ll_efield_y [3:0];
    elect_t [3:0]  ll_efield_x [3:0];
    gradb_t [3:0]  ll_gradb_y [2:0];
    gradb_t [3:0]  ll_gradb_x [2:0];
    bmag_t [3:0]  ll_bmag [2:0]; 
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
    logic signed [3:0] [1:0] [EWIDTH+PFRAC*2-1:0] total_efield_y_stage1;
    logic signed [3:0] [1:0] [EWIDTH+PFRAC*2-1:0] total_efield_x_stage1;
    logic signed [3:0] [1:0] [BWIDTH+PFRAC*2-1:0] total_gradb_y_stage1;
    logic signed [3:0] [1:0] [BWIDTH+PFRAC*2-1:0] total_gradb_x_stage1;
    logic [3:0] [1:0] [BWIDTH+PFRAC*2-1:0] total_bmag_stage1;
    logic signed [3:0] [EWIDTH+PFRAC*2-1:0] total_efield_y_stage2;
    logic signed [3:0] [EWIDTH+PFRAC*2-1:0] total_efield_x_stage2;
    logic signed [3:0] [BWIDTH+PFRAC*2-1:0] total_gradb_y_stage2;
    logic signed [3:0] [BWIDTH+PFRAC*2-1:0] total_gradb_x_stage2;
    logic [3:0] [BWIDTH+PFRAC*2-1:0] total_bmag_stage2;
    logic signed [1:0] [EWIDTH+PFRAC*2:0] total_efield_y_stage3;
    logic signed [1:0] [EWIDTH+PFRAC*2:0] total_efield_x_stage3;
    logic signed [1:0] [BWIDTH+PFRAC*2:0] total_gradb_y_stage3;
    logic signed [1:0] [BWIDTH+PFRAC*2:0] total_gradb_x_stage3;
    logic [1:0] [BWIDTH+PFRAC*2:0] total_bmag_stage3;
    logic signed [EWIDTH+PFRAC*2+1:0] total_efield_y_ff;
    logic signed [EWIDTH+PFRAC*2+1:0] total_efield_x_ff;
    logic signed [BWIDTH+PFRAC*2+1:0] total_gradb_y_ff;
    logic signed [BWIDTH+PFRAC*2+1:0] total_gradb_x_ff;
    logic [BWIDTH+PFRAC*2+1:0] total_bmag_ff;
    logic [EWIDTH+PFRAC*2-1:0] total_efield_y;
    logic [EWIDTH+PFRAC*2-1:0] total_efield_x;
    logic [BWIDTH+PFRAC*2-1:0] total_gradb_y;
    logic [BWIDTH+PFRAC*2-1:0] total_gradb_x;
    logic [BWIDTH+PFRAC*2-1:0] total_bmag;
    logic [VPERPWIDTH*2-1:0] vperp_squared;
    logic [VPERPWIDTH*2-1:0] vperp_squared_ff;
    logic signed [EWIDTH-1:0] true_efield_y;
    logic signed [EWIDTH-1:0] true_efield_x;
    logic signed [BWIDTH-1:0] true_gradb_y;
    logic signed [BWIDTH-1:0] true_gradb_x;
    logic [BWIDTH-1:0] true_bmag;
    //we dont't subtract 1 because unlike bmag, the drift velocity is signed
    logic signed [BWIDTH+PFRAC+SLOWDOWN:0] drift_y;
    logic signed [BWIDTH+PFRAC+SLOWDOWN:0] drift_x;
    logic signed [BWIDTH:0] drift_y_ff;
    logic signed [BWIDTH:0] drift_x_ff;
    logic [43:0] mu;
    logic [MUWIDTH-1:0] mu_ff [6:0];
    logic signed [MUWIDTH+PWIDTH:0] gradb_vel_y;
    logic signed [MUWIDTH+PWIDTH:0] gradb_vel_x;
    logic signed [PWIDTH:0] drift_vel_y;
    logic signed [PWIDTH:0] drift_vel_x;
    logic signed [EWIDTH+SLOWDOWN-1:0] exb_y;
    logic signed [EWIDTH+SLOWDOWN-1:0] exb_x;
    logic signed [PWIDTH:0] exb_y_ff;
    logic signed [PWIDTH:0] exb_x_ff;
    particle_t exbdivider_particle_out;
    logic [13:0] cnt;
    //valids
    logic valid_interpolated;
    logic valid_bmag;
    logic valid_div;
    logic valid_gyroradius;
    logic valid_gyropoints;
    logic valid_raddr;
    logic valid_bram [3:0];
    logic valid_phi_in;
    logic valid_efield;
    logic valid_interpol [3:0];
    logic valid_interpolated_field;
    logic valid_stage1;
    logic valid_stage2;
    logic valid_stage3;
    logic valid_total;
    logic valid_true;
    logic valid_mu;
    logic valid_wait [5:0];
    logic valid_mu_mult [4:0];
    logic valid_gradb_vel [3:0];
    logic valid_exb;
    logic valid_new_particle;

    function logic signed [PHIWIDTH:0] signExtPhi(phi_t in);
        return {in[PHIWIDTH-1], in};
    endfunction

    function gradb_t makeSigned(bmag_t in);
        return $signed({1'b0, in});
    endfunction


    //module instantiations
    assign pos = {particle_in.pos.y, particle_in.pos.x};
    interpolator #(.DWIDTH(BWIDTH), .UWIDTH(PSIZE)) bmag_interpolate (
        .clk(clk),
        .rst(rst),
        .valid(valid),
        .pos(pos),
        .user_in(particle_in),
        .valid_out(valid_interpolated),
        .interpolated_data_out(total_short_bmag),
        .user_out(interpolator_particle_out),
        .data_in(bmag_out),
        .raddr_out(grid_addr)
        
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
        .douta(bmag_out),
        .doutb(),
        .swapped_addra(),
        .swapped_addrb()
    );

    gyroradius_div gyro_div (
        .aclk(clk),                                      // input wire aclk
        .s_axis_divisor_tvalid(valid_bmag),    // input wire s_axis_divisor_tvalid
        .s_axis_divisor_tdata(bmag_ff),      // input wire [15 : 0] s_axis_divisor_tdata
        .s_axis_dividend_tvalid(valid_bmag),  // input wire s_axis_dividend_tvalid
        .s_axis_dividend_tuser(particle[0]),    // input wire [35 : 0] s_axis_dividend_tuser
        .s_axis_dividend_tdata(particle[0].vperp),    // input wire [15 : 0] s_axis_dividend_tdata
        .m_axis_dout_tvalid(valid_div),          // output wire m_axis_dout_tvalid
        .m_axis_dout_tuser(divider_particle_out),            // output wire [35 : 0] m_axis_dout_tuser
        .m_axis_dout_tdata(divider_out)            // output wire [31 : 0] m_axis_dout_tdata
    );


    assign valid_req = valid_raddr;
    generate
        for (genvar i = 0; i < 4; i++) begin
            dist_mult mult00 (
                .CLK(clk),
                .A(inv_dist_ff[0][i].y_frac),
                .B(inv_dist_ff[0][i].x_frac),
                .P(coeff[i][0])
            );

            dist_mult mult01 (
                .CLK(clk),
                .A(inv_dist_ff[0][i].y_frac),
                .B(dist_ff[0][i].x_frac),
                .P(coeff[i][1])
            );

            dist_mult mult10 (
                .CLK(clk),
                .A(dist_ff[0][i].y_frac),
                .B(inv_dist_ff[0][i].x_frac),
                .P(coeff[i][2])
            );

            dist_mult mult11 (
                .CLK(clk),
                .A(dist_ff[0][i].y_frac),
                .B(dist_ff[0][i].x_frac),
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
                    .B(coeff_ff[2][i][j]),
                    .P(interpolated_efield_y[i][j])
                );

                efield_mult mult_efield_x (
                    .CLK(clk),
                    .A(efield_x[i][j]),
                    .B(coeff_ff[2][i][j]),
                    .P(interpolated_efield_x[i][j])
                );

                gradb_mult mult_gradb_y (
                    .CLK(clk),
                    .A(gradb_y[i][j]),
                    .B(coeff_ff[2][i][j]),
                    .P(interpolated_gradb_y[i][j])
                );

                gradb_mult mult_gradb_x (
                    .CLK(clk),
                    .A(gradb_x[i][j]),
                    .B(coeff_ff[2][i][j]),
                    .P(interpolated_gradb_x[i][j])
                );

                bmag_mult mult_bmag (
                    .CLK(clk),
                    .A(bmag[i][j]),
                    .B(coeff_ff[2][i][j]),
                    .P(interpolated_bmag[i][j])
                );
            end
        end
    endgenerate

    vperp_squarer squarer (
        .CLK(clk),
        .A(particle[14].vperp),
        .B(particle[14].vperp),
        .P(vperp_squared)
    );
    
    assign total_efield_y = total_efield_y_ff >>> 2;
    assign total_efield_x = total_efield_x_ff >>> 2;
    assign total_gradb_y = total_gradb_y_ff >>> 2;
    assign total_gradb_x = total_gradb_x_ff >>> 2;
    assign total_bmag = total_bmag_ff >>> 2;
    //here we implicitly perform the cross product by swapping x and y and negating y
    exb_div exb_div_y (
        .aclk(clk),                                      // input wire aclk
        .s_axis_divisor_tvalid(valid_true),    // input wire s_axis_divisor_tvalid
        .s_axis_divisor_tdata($signed({1'b0, true_bmag})),      // input wire [15 : 0] s_axis_divisor_tdata
        .s_axis_dividend_tvalid(valid_true),  // input wire s_axis_dividend_tvalid
        .s_axis_dividend_tuser(particle[19]),
        .s_axis_dividend_tdata(true_efield_x),    // input wire [39 : 0] s_axis_dividend_tdata
        .m_axis_dout_tvalid(),          // output wire m_axis_dout_tvalid
        .m_axis_dout_tuser(exbdivider_particle_out),            // output wire [35 : 0] m_axis_dout_tuser
        .m_axis_dout_tdata(exb_y)            // output wire [55 : 0] m_axis_dout_tdata
    );

    exb_div exb_div_x (
        .aclk(clk),                                      // input wire aclk
        .s_axis_divisor_tvalid(valid_true),    // input wire s_axis_divisor_tvalid
        .s_axis_divisor_tdata($signed({1'b0, true_bmag})),      // input wire [15 : 0] s_axis_divisor_tdata
        .s_axis_dividend_tvalid(valid_true),  // input wire s_axis_dividend_tvalid
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
        .s_axis_dividend_tvalid(valid_true),  // input wire s_axis_dividend_tvalid
        .s_axis_dividend_tdata(true_gradb_x),    // input wire [15 : 0] s_axis_dividend_tdata
        .m_axis_dout_tvalid(),          // output wire m_axis_dout_tvalid
        .m_axis_dout_tdata(drift_y)            // output wire [31 : 0] m_axis_dout_tdata
    );

    drift_div drift_div_x (
        .aclk(clk),                                      // input wire aclk
        .s_axis_divisor_tvalid(valid_true),    // input wire s_axis_divisor_tvalid
        .s_axis_divisor_tdata($signed({1'b0, true_bmag})),      // input wire [15 : 0] s_axis_divisor_tdata
        .s_axis_dividend_tvalid(valid_true),  // input wire s_axis_dividend_tvalid
        .s_axis_dividend_tdata(-true_gradb_y),    // input wire [15 : 0] s_axis_dividend_tdata
        .m_axis_dout_tvalid(),          // output wire m_axis_dout_tvalid
        .m_axis_dout_tdata(drift_x)            // output wire [31 : 0] m_axis_dout_tdata
    );

    mu_div mu_maker (
        .aclk(clk),                                      // input wire aclk
        .s_axis_divisor_tvalid(valid_true),    // input wire s_axis_divisor_tvalid
        .s_axis_divisor_tdata(true_bmag),      // input wire [15 : 0] s_axis_divisor_tdata
        .s_axis_dividend_tvalid(valid_true),  // input wire s_axis_dividend_tvalid
        .s_axis_dividend_tdata(vperp_squared_ff),    // input wire [31 : 0] s_axis_dividend_tdata
        .m_axis_dout_tvalid(valid_mu),          // output wire m_axis_dout_tvalid
        .m_axis_dout_tdata(mu)            // output wire [47 : 0] m_axis_dout_tdata
    );

    mu_mult gradb_mult_y (
        .CLK(clk),
        .A(drift_y_ff),
        .B(mu_ff[6]),
        .P(gradb_vel_y)
    );

    mu_mult gradb_mult_x (
        .CLK(clk),
        .A(drift_x_ff),
        .B(mu_ff[6]),
        .P(gradb_vel_x)
    );

    assign done = cnt == NUM_PARTICLES - 1;
    
    always @(posedge clk) begin
        rst_ff <= rst;
        if (rst_ff) begin
            particle <= '{default:'0};
            bmag_ff <= '0;
            gyroradius_ff <= '{default:'0};
            gyropoints_y <= '{default:'0};
            gyropoints_x <= '0;
            dist_ff <= '{default:'0};  
            inv_dist_ff <= '{default:'0};
            special <= '{default:'0};
            coeff_ff <= '{default:'0};
            phi_in_ff <= '0;
            bmag_in_ff <= '0;
            efield_y <= '0;
            efield_x <= '0;
            gradb_y <= '0;
            gradb_x <= '0;
            bmag <= '0;
            ll_efield_y <= '{default:'0};
            ll_efield_x <= '{default:'0};
            ll_gradb_y <= '{default:'0};
            ll_gradb_x <= '{default:'0};
            ll_bmag <= '{default:'0};
            interpolated_efield_y_ff <= '0;
            interpolated_efield_x_ff <= '0;
            interpolated_gradb_y_ff <= '{default:'0};
            interpolated_gradb_x_ff <= '{default:'0};
            interpolated_bmag_ff <= '{default:'0};
            total_efield_y_stage1 <= '0;
            total_efield_x_stage1 <= '0;
            total_gradb_y_stage1 <= '0;
            total_gradb_x_stage1 <= '0;
            total_bmag_stage1 <= '0;
            total_efield_y_stage2 <= '0;
            total_efield_x_stage2 <= '0;
            total_gradb_y_stage2 <= '0;
            total_gradb_x_stage2 <= '0;
            total_bmag_stage2 <= '0;
            total_efield_y_stage3 <= '0;
            total_efield_x_stage3 <= '0;
            total_gradb_y_stage3 <= '0;
            total_gradb_x_stage3 <= '0;
            total_bmag_stage3 <= '0;
            total_efield_y_ff <= '0;
            total_efield_x_ff <= '0;
            total_gradb_y_ff <= '0;
            total_gradb_x_ff <= '0;
            total_bmag_ff <= '0;
            vperp_squared_ff <= '0;
            true_efield_y <= '0;
            true_efield_x <= '0;
            true_gradb_y <= '0;
            true_gradb_x <= '0;
            true_bmag <= '0;
            drift_y_ff <= '0;
            drift_x_ff <= '0;
            mu_ff <= '{default:'0};
            drift_vel_y <= '0;
            drift_vel_x <= '0;
            exb_y_ff <= '0;
            exb_x_ff <= '0;
            cnt <= '0;

            valid_bmag <= 1'b0;
            valid_gyroradius <= 1'b0;
            valid_gyropoints <= 1'b0;
            valid_raddr <= 1'b0;
            valid_bram <= '{default:1'b0};
            valid_phi_in <= 1'b0;
            valid_efield <= 1'b0;
            valid_interpol <= '{default:1'b0};
            valid_interpolated_field <= 1'b0;
            valid_stage1 <= 1'b0;
            valid_stage2 <= 1'b0;
            valid_stage3 <= 1'b0;
            valid_total <= 1'b0;
            valid_true <= 1'b0;
            valid_wait <= '{default:1'b0};
            valid_mu_mult <= '{default:1'b0};
            valid_gradb_vel <= '{default:1'b0};
            valid_exb <= 1'b0;
            valid_new_particle <= 1'b0;
        end else begin
            //first we need to get the value of bmag at the particle
            if (valid_interpolated) begin
                bmag_ff <= total_short_bmag[BWIDTH+PFRAC*2-1-:BWIDTH];  //+ BMIN;
                particle[0] <= interpolator_particle_out;
                valid_bmag <= 1'b1;
            end else begin
                valid_bmag <= 1'b0;
            end

            if (valid_div) begin
                gyroradius_ff <= divider_out[PWIDTH-1:0]; //{3'b0, gyroradius[VPERPWIDTH+BWIDTH-1-:PWIDTH-3]};
                particle[1] <= divider_particle_out;
                valid_gyroradius <= 1'b1;
            end else begin
                valid_gyroradius <= 1'b0;
            end

            //calculate the four gyropoints
            if (valid_gyroradius) begin
                for (int i = 0; i < 4; i++) begin
                    gyropoints_y[i] <= particle[2].pos.y + (i[1] ? (i[0] ? gyroradius_ff : -gyroradius_ff) : 1'b0);
                    gyropoints_x[i] <= particle[2].pos.x + (i[1] ? 1'b0 : (i[0] ? gyroradius_ff : -gyroradius_ff));
                end
                particle[2] <= particle[1];
                valid_gyropoints <= 1'b1;
            end else begin
                valid_gyropoints <= 1'b0;
            end

            if (valid_gyropoints) begin
                //calculate the 48 adresses we need to read phi and bmag from, and calculate the coefficients
                for (int i = 0; i < 4; i++) begin
                    raddr[i][0][0] <= {gyropoints_y[i].whole, gyropoints_x[i].whole};
                    raddr[i][0][1] <= {gyropoints_y[i].whole, gyropoints_x[i].whole + 1'b1};
                    raddr[i][0][2] <= {gyropoints_y[i].whole + 1'b1, gyropoints_x[i].whole};
                    raddr[i][0][3] <= {gyropoints_y[i].whole + 1'b1, gyropoints_x[i].whole + 1'b1};
                    raddr[i][1][0] <= {gyropoints_y[i].whole, gyropoints_x[i].whole - 1'b1};
                    raddr[i][1][1] <= {gyropoints_y[i].whole, gyropoints_x[i].whole + 2'b10};
                    raddr[i][1][2] <= {gyropoints_y[i].whole + 1'b1, gyropoints_x[i].whole - 1'b1};
                    raddr[i][1][3] <= {gyropoints_y[i].whole + 1'b1, gyropoints_x[i].whole + 2'b10};
                    raddr[i][2][0] <= {gyropoints_y[i].whole - 1'b1, gyropoints_x[i].whole};
                    raddr[i][2][1] <= {gyropoints_y[i].whole - 1'b1, gyropoints_x[i].whole + 1'b1};
                    raddr[i][2][2] <= {gyropoints_y[i].whole + 2'b10, gyropoints_x[i].whole};
                    raddr[i][2][3] <= {gyropoints_y[i].whole + 2'b10, gyropoints_x[i].whole + 1'b1};
                    dist_ff[0][i] <= {gyropoints_y[i].fraction, gyropoints_x[i].fraction};
                    inv_dist_ff[0][i] <= {12'hfff - gyropoints_y[i].fraction + 1'b1, 12'hfff - gyropoints_x[i].fraction + 1'b1};
                end
                particle[3] <= particle[2];
                valid_raddr <= 1'b1;
            end else begin
                valid_raddr <= 1'b0;
            end
            
            //wait four clocks for phi bram to be read and three for dist mult to be performed            
            if (valid_raddr) begin
                dist_ff[1] <= dist_ff[0];
                inv_dist_ff[1] <= inv_dist_ff[0];
                particle[4] <= particle[3];
                valid_bram[0] <= 1'b1;
            end else begin
                valid_bram[0] <= 1'b1;
            end

            for (int i = 1; i < 4; i++) begin
                if (valid_bram[i-1]) begin
                    dist_ff[i+1] <= dist_ff[i];
                    inv_dist_ff[i+1] <= inv_dist_ff[i];
                    particle[i+4] <= particle[i+3];
                    if (i == 3) begin
                        for (int j = 0; j < 4; j++) begin
                            //multiplication is done
                            special[0][j] <= dist_ff[3][j].y_frac == '0 && dist_ff[3][j].x_frac == '0;
                            if (dist_ff[3][j].y_frac == '0) begin
                                coeff_ff[0][j][0] <= inv_dist_ff[3][j].x_frac << 12;
                                coeff_ff[0][j][1] <= dist_ff[3][j].x_frac << 12;
                                coeff_ff[0][j][2] <= '0;
                                coeff_ff[0][j][3] <= '0;
                            end else if (dist_ff[3][j].x_frac == '0) begin
                                coeff_ff[0][j][0] <= inv_dist_ff[3][j].y_frac << 12;
                                coeff_ff[0][j][1] <= '0;
                                coeff_ff[0][j][2] <= dist_ff[3][j].y_frac << 12;
                                coeff_ff[0][j][3] <= '0;
                            end else begin
                                coeff_ff[0][j] <= coeff[j];
                            end
                        end
                    end
                    valid_bram[i] <= 1'b1;
                end else begin
                    valid_bram[i] <= 1'b0;
                end
            end

            if (valid_bram[3]) begin
                phi_in_ff <= phi_in;
                bmag_in_ff <= bmag_in;
                special[1] <= special[0];
                coeff_ff[1] <= coeff_ff[0];
                particle[8] <= particle[7];
                valid_phi_in <= 1'b1;
            end else begin
                valid_phi_in <= 1'b0;
            end

            //calculate the e-field at the gyropoints
            if (valid_phi_in) begin
                for (int i = 0; i < 4; i++) begin
                    efield_y[i][0] <= (signExtPhi(phi_in_ff[i][0][2]) - signExtPhi(phi_in_ff[i][2][0])) >>> 1;
                    efield_x[i][0] <= (signExtPhi(phi_in_ff[i][0][1]) - signExtPhi(phi_in_ff[i][1][0])) >>> 1;
                    efield_y[i][1] <= (signExtPhi(phi_in_ff[i][0][3]) - signExtPhi(phi_in_ff[i][2][1])) >>> 1;
                    efield_x[i][1] <= (signExtPhi(phi_in_ff[i][1][1]) - signExtPhi(phi_in_ff[i][0][0])) >>> 1;
                    efield_y[i][2] <= (signExtPhi(phi_in_ff[i][2][2]) - signExtPhi(phi_in_ff[i][0][0])) >>> 1;
                    efield_x[i][2] <= (signExtPhi(phi_in_ff[i][0][3]) - signExtPhi(phi_in_ff[i][1][2])) >>> 1;
                    efield_y[i][3] <= (signExtPhi(phi_in_ff[i][2][3]) - signExtPhi(phi_in_ff[i][0][1])) >>> 1;
                    efield_x[i][3] <= (signExtPhi(phi_in_ff[i][1][3]) - signExtPhi(phi_in_ff[i][0][2])) >>> 1;                    
                    gradb_y[i][0] <= (makeSigned(bmag_in_ff[i][0][2]) - makeSigned(bmag_in_ff[i][2][0])) >>> 1;
                    gradb_x[i][0] <= (makeSigned(bmag_in_ff[i][0][1]) - makeSigned(bmag_in_ff[i][1][0])) >>> 1;
                    gradb_y[i][1] <= (makeSigned(bmag_in_ff[i][0][3]) - makeSigned(bmag_in_ff[i][2][1])) >>> 1;
                    gradb_x[i][1] <= (makeSigned(bmag_in_ff[i][1][1]) - makeSigned(bmag_in_ff[i][0][0])) >>> 1;
                    gradb_y[i][2] <= (makeSigned(bmag_in_ff[i][2][2]) - makeSigned(bmag_in_ff[i][0][0])) >>> 1;
                    gradb_x[i][2] <= (makeSigned(bmag_in_ff[i][0][3]) - makeSigned(bmag_in_ff[i][1][2])) >>> 1;
                    gradb_y[i][3] <= (makeSigned(bmag_in_ff[i][2][2]) - makeSigned(bmag_in_ff[i][0][1])) >>> 1;
                    gradb_x[i][3] <= (makeSigned(bmag_in_ff[i][1][3]) - makeSigned(bmag_in_ff[i][0][2])) >>> 1;
                    bmag[i] <= bmag_in_ff[i][0];
                end
                special[2] <= special[1];
                coeff_ff[2] <= coeff_ff[1];
                particle[9] <= particle[8];
                valid_efield <= 1'b1;
            end else begin
                valid_efield <= 1'b0;
            end

            //wait four clocks for the e-fields to be interpolated, and 3 clocks for gradB and bmag to be interpolated
            if (valid_efield) begin
                special[3] <= special[2];
                for (int i = 0; i < 4; i++) begin
                    //lower-left values for each quantity, in case y_frac and x_frac are both 0
                    ll_efield_y[0][i] <= efield_y[i][0][0];
                    ll_efield_x[0][i] <= efield_x[i][0][0];
                    ll_gradb_y[0][i] <= gradb_y[i][0][0];
                    ll_gradb_x[0][i] <= gradb_x[i][0][0];
                    ll_bmag[0][i] <= bmag[i][0][0];  
                end
                particle[10] <= particle[9];
                valid_interpol[0] <= 1'b1;
            end else begin 
                valid_interpol[0] <= 1'b0;
            end

            if (valid_interpol[0]) begin
                special[4] <= special[3];
                ll_efield_y[1] <= ll_efield_y[0];
                ll_efield_x[1] <= ll_efield_x[0];
                ll_gradb_y[1] <= ll_gradb_y[0];
                ll_gradb_x[1] <= ll_gradb_x[0];
                ll_bmag[1] <= ll_bmag[0];
                particle[11] <= particle[10];
                valid_interpol[1] <= 1'b1;
            end else begin
                valid_interpol[1] <= 1'b0;
            end

            if (valid_interpol[1]) begin
                special[5] <= special[4];
                ll_efield_y[2] <= ll_efield_y[1];
                ll_efield_x[2] <= ll_efield_x[1];
                ll_gradb_y[2] <= ll_gradb_y[1];
                ll_gradb_x[2] <= ll_gradb_x[1];
                ll_bmag[2] <= ll_bmag[1];
                particle[12] <= particle[11];
                valid_interpol[2] <= 1'b1;
            end else begin
                valid_interpol[2] <= 1'b0;
            end

            if (valid_interpol[2]) begin
                for (int i = 0; i < 4; i++) begin
                    for (int j = 0; j < 4; j++) begin
                        interpolated_gradb_y_ff[0][i][j] <= special[5][i] ? (j == 0 ? ll_gradb_y[2][i] <<< (PFRAC*2) : '0) : interpolated_gradb_y[i][j];
                        interpolated_gradb_x_ff[0][i][j] <= special[5][i] ? (j == 0 ? ll_gradb_x[2][i] <<< (PFRAC*2) : '0) : interpolated_gradb_x[i][j];
                        interpolated_bmag_ff[0][i][j] <= special[5][i] ? (j == 0 ? ll_bmag[2][i] << (PFRAC*2) : '0) : interpolated_bmag[i][j];
                    end
                end
                special[6] <= special[5];
                ll_efield_y[3] <= ll_efield_y[2];
                ll_efield_x[3] <= ll_efield_x[2];
                particle[13] <= particle[12];
                valid_interpol[3] <= 1'b1;
            end else begin
                valid_interpol[3] <= 1'b0;
            end

            if (valid_interpol[3]) begin
                for (int i = 0; i < 4; i++) begin
                    for (int j = 0; j < 4; j++) begin
                        interpolated_efield_y_ff[i][j] <= special[6][i] ? (j == 0 ? ll_efield_y[3][i] <<< (PFRAC*2) : '0) : interpolated_efield_y[i][j];
                        interpolated_efield_x_ff[i][j] <= special[6][i] ? (j == 0 ? ll_efield_x[3][i] <<< (PFRAC*2) : '0) : interpolated_efield_x[i][j];
                    end
                end
                interpolated_gradb_y_ff[1] <= interpolated_gradb_y_ff[0];
                interpolated_gradb_x_ff[1] <= interpolated_gradb_x_ff[0];
                interpolated_bmag_ff[1] <= interpolated_bmag_ff[0];
                particle[14] <= particle[13];
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
                particle[15] <= particle[14];
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
                particle[16] <= particle[15];
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
                particle[17] <= particle[16];
                valid_stage3 <= 1'b1;
            end else begin
                valid_stage3 <= 1'b0;
            end

            if (valid_stage3) begin
                total_efield_y_ff <= total_efield_y_stage3[0] + total_efield_y_stage3[1];
                total_efield_x_ff <= total_efield_x_stage3[0] + total_efield_x_stage3[1];
                total_gradb_y_ff <= total_gradb_y_stage3[0] + total_gradb_y_stage3[1];
                total_gradb_x_ff <= total_gradb_x_stage3[0] + total_gradb_x_stage3[1];
                total_bmag_ff <= total_bmag_stage3[0] + total_bmag_stage3[1];
                vperp_squared_ff <= vperp_squared;
                particle[18] <= particle[17];
                valid_total <= 1'b1;
            end else begin
                valid_total <= 1'b0;
            end

            if (valid_total) begin
                true_efield_y <= total_efield_y[EWIDTH+PFRAC*2-1-:EWIDTH];
                true_efield_x <= total_efield_x[EWIDTH+PFRAC*2-1-:EWIDTH];
                true_gradb_y <= total_gradb_y[BWIDTH+PFRAC*2-1-:BWIDTH];
                true_gradb_x <= total_gradb_x[BWIDTH+PFRAC*2-1-:BWIDTH];
                true_bmag = total_bmag[BWIDTH+PFRAC*2-1-:BWIDTH];
                particle[19] <= particle[18];
                valid_true <= 1'b1;
            end else begin
                valid_true <= 1'b0;
            end


            //after 30 clocks, mu has been calculated
            if (valid_mu) begin
                mu_ff[0] <= mu[43-:MUWIDTH];
                valid_wait[0] <= 1'b1;
            end else begin
                valid_wait[0] <= 1'b0;
            end
            
            //wait 5 cycles for drift_div to complete
            for (int i = 1; i < 6; i++) begin
                if (valid_wait[i-1]) begin
                    valid_wait[i] <= 1'b1;
                    mu_ff[i] <= mu_ff[i-1];
                end else begin
                    valid_wait[i] <= 1'b0;
                end
            end

            if (valid_wait[5]) begin
                drift_y_ff <= {drift_y[BWIDTH+BFRAC+SLOWDOWN], drift_y[BWIDTH+SLOWDOWN-1:0]} >>> SLOWDOWN;
                drift_x_ff <= {drift_x[BWIDTH+BFRAC+SLOWDOWN], drift_x[BWIDTH+SLOWDOWN-1:0]} >>> SLOWDOWN;
                mu_ff[6] <= mu_ff[5];
                valid_mu_mult[0] <= 1'b1;
            end else begin
                valid_mu_mult[0] <= 1'b0;
            end

            //wait 4 clocks for mu_mult to complete
            valid_mu_mult[1] <= valid_mu_mult[0];
            valid_mu_mult[2] <= valid_mu_mult[1];
            valid_mu_mult[3] <= valid_mu_mult[2];
            valid_mu_mult[4] <= valid_mu_mult[3];
            

            if (valid_mu_mult[4]) begin
                drift_vel_y[0] <= {gradb_vel_y[BFRAC+MUFRAC+BINT+MUINT], gradb_vel_y[BFRAC+MUFRAC+PINT-:PWIDTH]};
                drift_vel_x[0] <= {gradb_vel_x[BFRAC+MUFRAC+BINT+MUINT], gradb_vel_x[BFRAC+MUFRAC+PINT-:PWIDTH]};
                valid_gradb_vel[0] <= 1'b1;
            end else begin
                valid_gradb_vel[0] <= 1'b0;
            end

            //wait another 4 clocks for division of ExB to complete
            for (int i = 1; i < 5; i++) begin
                if (valid_gradb_vel[i-1]) begin
                    drift_vel_y[i] <= drift_vel_y[i-1];
                    drift_vel_x[i] <= drift_vel_x[i-1];
                    valid_gradb_vel[i] <= 1'b1;
                end else begin
                    valid_gradb_vel[i] <= 1'b0;
                end
            end 

            if (valid_gradb_vel[4]) begin
                //TODO: set exb flip-flops to output of divider with correct truncations
                exb_y_ff <= exb_y[EWIDTH+SLOWDOWN-1:0] >>> SLOWDOWN;
                exb_x_ff <= exb_y[EWIDTH+SLOWDOWN-1:0] >>> SLOWDOWN;
                drift_vel_y[5] <= drift_vel_y[4];
                drift_vel_x[5] <= drift_vel_x[4];
                particle[20] <= exbdivider_particle_out;
                valid_exb <= 1'b1;
            end else begin
                valid_exb <= 1'b0;
            end

            if (valid_exb) begin
                //this can and should overflow, creating a periodic boundary condition
                particle[21].pos.y = noop ? particle[20].pos.y : (particle[20].pos.y + drift_vel_y[5] + exb_y_ff);
                particle[21].pos.x = noop ? particle[20].pos.x : (particle[20].pos.x + drift_vel_x[5] + exb_x_ff);
                particle[21].vperp = particle[20].vperp;
                valid_new_particle <= 1'b1;
            end else begin
                valid_new_particle <= 1'b0;
            end

            if (valid_new_particle) begin
                cnt <= cnt + 1;
                particle_out <= particle[21];
                valid_out <= 1'b1;
            end else begin
                valid_out <= 1'b0;
            end
        end
    end
endmodule