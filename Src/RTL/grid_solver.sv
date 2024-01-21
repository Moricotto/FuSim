`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11/09/2023 10:13:18 PM
// Design Name: 
// Module Name: grid_solver
// Project Name: plasma sim
// Target Devices: 
// Tool Versions: Vivado 2023
// Description: Performs a single jacobi iteration on a single gridpoint (vector element)
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////
import defs::*;

module grid_solver(
    input logic clk,
    input logic rst,
    input logic valid,
    input logic [PINT-1:0] grid_y,
    input logic [PINT-1:0] grid_x,
    input logic first_it,
    input logic signed [NUM_DELTA-1:0] [7:0] [3:0] [PHIWIDTH-1:0] prev_in,
    input logic [CWIDTH-1:0] charge_in,
    output logic valid_out,
    output logic valid_req,
    output logic [GRID_ADDRWIDTH-1:0] charge_addr,
    output logic [NUM_DELTA-1:0] [7:0] [GRID_ADDRWIDTH-1:0] raddr_out,
    output logic [GRID_ADDRWIDTH-1:0] waddr_out,
    output logic signed [PHIWIDTH-1:0] phi_out
    );
    //TODO: add weight to jacobi iteration, speeding up convergence

    logic [GRID_ADDRWIDTH-1:0] addr [22:0];
    logic first_it_ff [2:0];
    logic [NUM_DELTA-1:0] [PWIDTH-1:0] gyroradius;
    logic [NUM_DELTA-1:0] [PWIDTH-1:0] gyroradius_ff;

    pos_t [NUM_DELTA-1:0] [3:0] four_point_positions;
    pos_t [NUM_DELTA-1:0] [3:0] two_point_positions;

    logic signed [NUM_DELTA-1:0] [3:0] [PHIWIDTH+PFRAC*2+1:0] four_point_interpolated_data;
    logic signed [NUM_DELTA-1:0] [3:0] [PHIWIDTH+PFRAC*2+1:0] two_point_interpolated_data;
    logic [GRID_ADDRWIDTH-1:0] post_gyrocenter;
    logic signed [NUM_DELTA-1:0] [3:0] [PHIWIDTH+PFRAC*2+1:0] four_point_interpolated_data_ff;
    logic signed [NUM_DELTA-1:0] [3:0] [PHIWIDTH+PFRAC*2+1:0] two_point_interpolated_data_ff;
    logic signed [NUM_DELTA-1:0] [1:0] [PHIWIDTH+PFRAC*2+3:0] four_point_half_sums_ff;
    logic signed [NUM_DELTA-1:0] [1:0] [PHIWIDTH+PFRAC*2+2:0] two_point_half_sums_ff;
    logic signed [NUM_DELTA-1:0] [PHIWIDTH+PFRAC*2+4:0] four_point_sum_ff;
    logic signed [NUM_DELTA-1:0] [PHIWIDTH+PFRAC*2+3:0] two_point_sum_ff;
    logic signed [NUM_DELTA-1:0] [PHIWIDTH+PFRAC*2+4:0] total_phi_ff;
    logic [CWIDTH-1:0] charge_ff;
    logic signed [NUM_DELTA-1:0] [PHIWIDTH+PFRAC*2+28:0] weighted_phi;
    logic signed [NUM_DELTA-1:0] [PHIWIDTH-1:0] weighted_phi_ff;
    logic signed [PHIWIDTH+1:0] true_phi_ff;
    logic signed [CWIDTH+6:0] diff_ff;
    logic signed [CWIDTH+31:0] new_phi;



    //valids
    logic valid_addr;
    logic valid_bram;
    logic valid_gyroradius;
    logic valid_positions;
    logic valid_interpol;
    logic valid_reduced;
    logic valid_halfsum;
    logic valid_sum;
    logic valid_total;
    logic valid_vmult [5:0];
    logic valid_weighted_phi;
    logic valid_true_phi;
    logic valid_diff;
    logic valid_mult [5:0];

    generate
        for (genvar v = 0; v < NUM_DELTA; v++) begin
            bmag_gyroradius gyroradii (
                .clka(clk),    // input wire clka
                .ena(valid_addr),      // input wire ena
                .addra(addr[0]),  // input wire [11 : 0] addra
                .douta(gyroradius[v])  // output wire [17 : 0] douta
            );
        end
    endgenerate


    generate
        for (genvar v = 0; v < NUM_DELTA; v++) begin
            for (genvar i = 0; i < 4; i++) begin
                if (v == 0 && i == 0) begin
                    interpolator #(.DWIDTH(PHIWIDTH), .UWIDTH(GRID_ADDRWIDTH), .STAGES(4)) four_point_interpolator (
                        .clk(clk),
                        .rst(rst),
                        .valid(valid_positions),
                        .zero(first_it_ff[2]),
                        .pos(four_point_positions[v][i]),
                        .data_in(prev_in[v][i]),
                        .user_in(addr[3]),
                        .raddr_out(raddr_out[v][i]),
                        .valid_out(valid_interpol),
                        .interpolated_data_out(four_point_interpolated_data[v][i]),
                        .user_out(post_gyrocenter)
                    ); 
                end
                else begin
                    interpolator #(.DWIDTH(PHIWIDTH), .STAGES(4)) four_point_interpolator (
                        .clk(clk),
                        .rst(rst),
                        .valid(valid_positions),
                        .zero(first_it_ff[2]),
                        .pos(four_point_positions[v][i]),
                        .data_in(prev_in[v][i]),
                        .user_in(),
                        .raddr_out(raddr_out[v][i]),
                        .valid_out(),
                        .interpolated_data_out(four_point_interpolated_data[v][i]),
                        .user_out()
                    ); 
                end
                
            end
            for (genvar j = 0; j < 4; j++) begin
                interpolator #(.DWIDTH(PHIWIDTH), .STAGES(4)) two_point_interpolator (
                    .clk(clk),
                    .rst(rst),
                    .valid(valid_positions),
                    .zero(first_it_ff[2]),
                    .pos(two_point_positions[v][j]),
                    .data_in(prev_in[v][j+4]),
                    .user_in(),
                    .raddr_out(raddr_out[v][j+4]),
                    .valid_out(),
                    .interpolated_data_out(two_point_interpolated_data[v][j]),
                    .user_out()
                );
            end
        end
    endgenerate

    logic [NUM_DELTA-1:0] [23:0] local_vweights;
    assign local_vweights = VWEIGHTS;

    logic signed [24:0] local_diag_const;
    assign local_diag_const = DIAG_CONST;
    generate
        for (genvar v = 0; v < NUM_DELTA; v++) begin
            v_mult weight_delta (
                .CLK(clk),
                .A(total_phi_ff[v]),
                .B(local_vweights[v]),
                .P(weighted_phi[v])
            );
        end
    endgenerate

    diag_divide new_phi_mult (
        .CLK(clk),
        .A(diff_ff),
        .B(local_diag_const),
        .P(new_phi)
    );

    always_ff @(posedge clk) begin
        if (rst) begin
            for (int v = 0; v < NUM_DELTA; v++) begin
                gyroradius_ff[v] <= '0;
                for (int i = 0; i < 4; i++) begin
                    four_point_positions[v][i] <= '0;
                    two_point_positions[v][i] <= '0;
                    four_point_interpolated_data_ff[v][i] <= '0;
                    two_point_interpolated_data_ff[v][i] <= '0;
                end
                for (int j = 0; j < 2; j++) begin
                    four_point_half_sums_ff[v][j] <= '0;
                    two_point_half_sums_ff[v][j] <= '0;
                end
                four_point_sum_ff[v] <= '0;
                two_point_sum_ff[v] <= '0;
                total_phi_ff[v] <= '0;
                weighted_phi_ff[v] <= '0;
                for (int k = 0; k <= 22; k++) begin
                    addr[k] <= '0;
                end
                for (int k = 0; k <= 2; k++) begin
                    first_it_ff[k] <= 1'b0;
                end
                charge_ff <= '0;
            end
            true_phi_ff <= '0;
            diff_ff <= '0;
            // reset valids
            valid_addr <= 1'b0;
            valid_bram <= 1'b0;
            valid_gyroradius <= 1'b0;
            valid_positions <= 1'b0;
            valid_reduced <= 1'b0;
            valid_halfsum <= 1'b0;
            valid_sum <= 1'b0;
            valid_total <= 1'b0;
            for (int i = 0; i <= 5; i++) begin
                valid_vmult[i] <= 1'b0;
            end
            valid_weighted_phi <= 1'b0;
            valid_true_phi <= 1'b0;
            valid_diff <= 1'b0;
            for (int i = 0; i < 6; i++) begin
                valid_mult[i] <= 1'b0;
            end
            valid_out <= 1'b0;
            valid_req <= 1'b0;
            charge_addr <= '0;
            waddr_out <= '0;
            phi_out <= '0;
        end else begin
             
            if (valid) begin
                addr[0] <= {grid_y, grid_x};
                first_it_ff[0] <= first_it;
                valid_addr <= 1'b1;
            end else begin
                valid_addr <= 1'b0;
            end

            if (valid_addr) begin
                addr[1] <= addr[0];
                valid_bram <= 1'b1;
            end else begin
                valid_bram <= 1'b0;
            end

            if (valid_bram) begin
                for (int v = 0; v < NUM_DELTA; v++) begin
                    gyroradius_ff[v] <= gyroradius[v];
                end
                addr[2] <= addr[1];
                first_it_ff[1] <= first_it_ff[0];
                valid_gyroradius <= 1'b1;
            end else begin
                valid_gyroradius <= 1'b0;
            end

            if (valid_gyroradius) begin
                for (int v = 0; v < NUM_DELTA; v++) begin
                    for (int i = 0; i < 4; i++) begin 
                        four_point_positions[v][i] <= {(addr[2][GRID_ADDRWIDTH-1-:PINT] << PFRAC) + (i[1] ? gyroradius_ff[v] : -gyroradius_ff[v]), (addr[2][PINT-1:0] << PFRAC) + (i[0] ? gyroradius_ff[v] : -gyroradius_ff[v])};
                        two_point_positions[v][i] <= {(addr[2][GRID_ADDRWIDTH-1-:PINT] << PFRAC) + (i[1] ? (i[0] ? gyroradius_ff[v] << 1 : -gyroradius_ff[v] << 1) : 1'b0), (addr[2][PINT-1:0] << PFRAC) + (i[1] ? 1'b0 : (i[0] ? gyroradius_ff[v] << 1 : -gyroradius_ff[v] << 1))};
                    end
                end
                addr[3] <= addr[2];
                first_it_ff[2] <= first_it_ff[1];
                valid_positions <= 1'b1;
            end else begin
                valid_positions <= 1'b0;
            end 



            if (valid_interpol) begin
                for (int v = 0; v < NUM_DELTA; v++) begin
                    for (int i = 0; i < 4; i++) begin
                        four_point_interpolated_data_ff[v][i] <= four_point_interpolated_data[v][i];
                        two_point_interpolated_data_ff[v][i] <= two_point_interpolated_data[v][i];
                    end
                end
                addr[4] <= post_gyrocenter;
                valid_reduced <= 1'b1;
            end else begin
                valid_reduced <= 1'b0;
            end

            if (valid_reduced) begin
                for (int v = 0; v < NUM_DELTA; v++) begin
                    for (int i = 0; i < 2; i++) begin
                        four_point_half_sums_ff[v][i] <= (four_point_interpolated_data_ff[v][i] + four_point_interpolated_data_ff[v][i+2]) * 2;
                        two_point_half_sums_ff[i] <= two_point_interpolated_data_ff[v][i] + two_point_interpolated_data_ff[v][i+2];
                    end
                end
                addr[5] <= addr[4];
                valid_halfsum <= 1'b1;
            end else begin
                valid_halfsum <= 1'b0;
            end

            if (valid_halfsum) begin
                for (int v = 0; v < NUM_DELTA; v++) begin
                    four_point_sum_ff[v] <= four_point_half_sums_ff[v][0] + four_point_half_sums_ff[v][1];
                    two_point_sum_ff[v] <= two_point_half_sums_ff[v][0] + two_point_half_sums_ff[v][1];
                end
                addr[6] <= addr[5];
                valid_sum <= 1'b1;
            end else begin
                valid_sum <= 1'b0;
            end

            if (valid_sum) begin
                for (int v = 0; v < NUM_DELTA; v++) begin
                    total_phi_ff[v] <= four_point_sum_ff[v] + two_point_sum_ff[v];
                end
                charge_addr <= addr[6];
                addr[7] <= addr[6];
                valid_req <= 1'b1;
                valid_total <= 1'b1;
            end else begin
                valid_req <= 1'b0;
                valid_total <= 1'b0;
            end

            //perform multiplication by the weight of each delta function
            if (valid_total) begin
                valid_vmult[0] <= 1'b1;
                addr[8] <= addr[7];
            end else begin
                valid_vmult[0] <= 1'b0;
            end

            for (int i = 1; i < 6; i++) begin
                if (valid_vmult[i-1]) begin
                    valid_vmult[i] <= 1'b1;
                    addr[8+i] <= addr[7+i];
                end else begin
                    valid_vmult[i] <= 1'b0;
                end
            end

            if (valid_vmult[5]) begin
                for (int v = 0; v < NUM_DELTA; v++) begin
                    weighted_phi_ff[v] <= {weighted_phi[v][PHIWIDTH+PFRAC*2+28], weighted_phi[v][PHIWIDTH+PFRAC*2+22-:PHIWIDTH-1]};
                end
                addr[14] <= addr[13];
                valid_weighted_phi <= 1'b1;
            end else begin
                valid_weighted_phi <= 1'b0;
            end

            if (valid_weighted_phi) begin
                true_phi_ff <= weighted_phi_ff[0] + weighted_phi_ff[1] + weighted_phi_ff[2];
                addr[15] <= addr[14];
                charge_ff <= charge_in;
                valid_true_phi <= 1'b1;
            end else begin
                valid_true_phi <= 1'b0;
            end

            if (valid_true_phi) begin
                diff_ff <= $signed({1'b0, (charge_ff << 6)}) - true_phi_ff;
                addr[16] <= addr[15];
                valid_diff <= 1'b1;
            end else begin
                valid_diff <= 1'b0;
            end

            //wait 6 cycles for multiplication to be performed
            if (valid_diff) begin
                valid_mult[0]  <= 1'b1;
                addr[17] <= addr[16];
            end else begin
                valid_mult[0]  <= 1'b0;
            end

            for (int i = 1; i < 6; i++) begin
                if (valid_mult[i-1]) begin
                    valid_mult[i] <= 1'b1; 
                    addr[17+i] <= addr[16+i];
                end else begin
                    valid_mult[i] <= 1'b0;
                end
            end

            if (valid_mult[5]) begin
                phi_out <= {new_phi[CWIDTH+31], new_phi[CWIDTH+30-15-:PHIWIDTH-1]};
                waddr_out <= addr[22];
                valid_out <= 1'b1;
            end else begin
                valid_out <= 1'b0;
            end
        end
    end
endmodule































            /*if (valid_diff1) begin
                scaled_diag_ff <= scaled_diag[PHIWIDTH+25-1-:PHIWIDTH+6];
                weighted_prev_ff <= weighted_prev[PHIWIDTH+25-1-:PHIWIDTH+6];
                diff_ff2 <= diff_ff1;
                valid_scaled <= 1'b1;
            end else begin
                valid_scaled <= 1'b0;
            end

            if (valid_div) begin
                new_phi_ff <= {new_phi[77], new_phi[PHIWIDTH-2:0]};
                postdiv_addr[0] <= tuser_out[52-:GRID_ADDRWIDTH];
                postdiv_weighted_prev_ff[0] <= tuser_out[52-GRID_ADDRWIDTH:0];
                valid_new_phi <= 1'b1;
            end else begin
                valid_new_phi <= 1'b0;
            end

            if (valid_new_phi) begin
                postdiv_addr[1] <= postdiv_addr[0];
                postdiv_weighted_prev_ff[1] <= postdiv_weighted_prev_ff[0];
                valid_omega[0] <= 1'b1;
            end else begin
                valid_omega[0] <= 1'b0;
            end

            if (valid_omega[0]) begin
                postdiv_addr[2] <= postdiv_addr[1];
                postdiv_weighted_prev_ff[2] <= postdiv_weighted_prev_ff[1];
                valid_omega[1] <= 1'b1;
            end else begin
                valid_omega[1] <= 1'b0;
            end

            if (valid_omega[1]) begin
                postdiv_addr[3] <= postdiv_addr[2];
                postdiv_weighted_prev_ff[3] <= postdiv_weighted_prev_ff[2];
                valid_omega[2] <= 1'b1;
            end else begin
                valid_omega[2] <= 1'b0;
            end

            if (valid_omega[2]) begin
                postdiv_addr[4] <= postdiv_addr[3];
                postdiv_weighted_prev_ff[4] <= postdiv_weighted_prev_ff[3];
                valid_omega[3] <= 1'b1;
            end else begin
                valid_omega[3] <= 1'b0;
            end

            if (valid_omega[3]) begin
                weighted_new_phi_ff <= weighted_new_phi[PHIWIDTH+25-1-:PHIWIDTH];
                post_div_addr[5] <= postdiv_addr[4];
                postdiv_weighted_prev_ff[5] <= postdiv_weighted_prev_ff[4];
                valid_weighted_new_phi <= 1'b1;
            end else begin
                valid_weighted_new_phi <= 1'b0;
            end

            if (valid_weighted_new_phi) begin
                phi_out <= weighted_new_phi_ff + postdiv_weighted_prev_ff[5];
                waddr_out <= postdiv_addr[5];
                valid_out <= 1'b1;
            end else begin
                valid_out <= 1'b0;
            end*/