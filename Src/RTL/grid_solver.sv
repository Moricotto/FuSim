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


const const_t KI = 24'b010000000000000000000000;
const const_t KE = 24'b010000000000000000000000;
const const_t DIAG_CONST = 24'b011100000000000000000000;
const const_t INV_DIAG = 24'b000000100100100100100100;
const logic [NUM_DELTA-1:0] [23:0] VWEIGHTS = {24'b010000000000000000000000, 24'b100000000000000000000000, 24'b010000000000000000000000};


module grid_solver (
    input logic clk,
    input logic rst,

    //to/from full_solver
    input logic valid,
    input addr_t grid_addr,
    output addr_t gyro_addr,
    input pos_t [NUM_DELTA-1:0] gyroradius,
    output addr_t [NUM_DELTA-1:0] [7:0] [3:0] raddr_out,
    input phi_t [NUM_DELTA-1:0] [7:0] [3:0] prev_in,
    output addr_t waddr_out,
    output phi_t phi_out

    //to/from scatterer, to get charge
    output logic valid_req,
    output addr_t charge_addr,
    input charge_t charge_in,
    );
    
    addr_t addr [22:0];
    pos_t [NUM_DELTA-1:0] gyroradius_ff;

    pos_t [NUM_DELTA-1:0] [3:0] four_point_positions;
    pos_t [NUM_DELTA-1:0] [3:0] two_point_positions;

    logic signed [NUM_DELTA-1:0] [3:0] [PHIWIDTH+PFRAC*2-1:0] four_point_interpolated_data;
    logic signed [NUM_DELTA-1:0] [3:0] [PHIWIDTH+PFRAC*2-1:0] two_point_interpolated_data;
    logic addr_t post_gyrocenter;
    logic signed [NUM_DELTA-1:0] [3:0] [PHIWIDTH+PFRAC*2-1:0] four_point_interpolated_data_ff;
    logic signed [NUM_DELTA-1:0] [3:0] [PHIWIDTH+PFRAC*2-1:0] two_point_interpolated_data_ff;
    logic signed [NUM_DELTA-1:0] [1:0] [PHIWIDTH+PFRAC*2:0] four_point_half_sums_ff;
    logic signed [NUM_DELTA-1:0] [1:0] [PHIWIDTH+PFRAC*2:0] two_point_half_sums_ff;
    logic signed [NUM_DELTA-1:0] [PHIWIDTH+PFRAC*2+1:0] four_point_sum_ff;
    logic signed [NUM_DELTA-1:0] [PHIWIDTH+PFRAC*2+1:0] two_point_sum_ff;
    logic signed [NUM_DELTA-1:0] [PHIWIDTH+PFRAC*2-1:0] total_phi_ff;
    logic signed [NUM_DELTA-1:0] [PHIWIDTH+PFRAC*2+24-1:0] weighted_phi;
    phi_t [NUM_DELTA-1:0] weighted_phi_ff;
    logic singed [CINT+PHIFRAC:0] sum;
    logic signed [CINT+PHIFRAC:0] true_phi_ff; //we add one bit because unlike charge, phi is signed
    logic signed [CINT+PHIFRAC:0] charge_ff;
    logic signed [CINT+PHIFRAC:0] diff_ff;
    logic signed [CINT+PHIFRAC+24:0] new_phi;



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
    logic valid_mult [4:0];


    generate
        for (genvar v = 0; v < NUM_DELTA; v++) begin
            for (genvar i = 0; i < 4; i++) begin
                if (v == 0 && i == 0) begin
                    interpolator #(.DWIDTH(PHIWIDTH), .UWIDTH(GRID_ADDRWIDTH), .STAGES(4)) four_point_interpolator (
                        .clk(clk),
                        .rst(rst),
                        .valid(valid_positions),
                        .pos({four_point_gyropoints_y[v][i], four_point_gyropoints_x[v][i]}),
                        .user_in(addr[3]),
                        .valid_out(valid_interpol),
                        .interpolated_data_out(four_point_interpolated_data[v][i]),
                        .user_out(post_gyrocenter),
                        .data_in(prev_in[v][i]),
                        .raddr_out(raddr_out[v][i]), 
                    ); 
                end
                else begin
                    interpolator #(.DWIDTH(PHIWIDTH), .STAGES(4)) four_point_interpolator (
                        .clk(clk),
                        .rst(rst),
                        .valid(valid_positions),
                        .pos({four_point_gyropoints_y[v][i], four_point_gyropoints_x[v][i]}),
                        .user_in(),
                        .valid_out(),
                        .interpolated_data_out(four_point_interpolated_data[v][i]),
                        .user_out(),
                        .data_in(prev_in[v][i]),
                        .raddr_out(raddr_out[v][i]), 
                    ); 
                end
                
            end
            for (genvar j = 0; j < 4; j++) begin
                interpolator #(.DWIDTH(PHIWIDTH), .STAGES(4)) two_point_interpolator (
                        .clk(clk),
                        .rst(rst),
                        .valid(valid_positions),
                        .pos({two_point_gyropoints_y[v][j], two_point_gyropoints_x[v][j]}),
                        .user_in(),
                        .valid_out(),
                        .interpolated_data_out(two_point_interpolated_data[v][i]),
                        .user_out(),
                        .data_in(prev_in[v][j+4]),
                        .raddr_out(raddr_out[v][j+4]), 
                ); 
            end
        end
    endgenerate

    logic [NUM_DELTA-1:0] [23:0] local_vweights;
    assign local_vweights = VWEIGHTS;

    const_t local_diag_const;
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

    assign sum = weighted_phi_ff[0] + weighted_phi_ff[1] + weighted_phi_ff[2];

    diag_divide new_phi_mult (
        .CLK(clk),
        .A(diff_ff),
        .B(local_diag_const),
        .P(new_phi)
    );

    always_ff @(posedge clk) begin
        if (rst) begin
            addr <= '{default: '0};
            gyroradius_ff <= '0;
            four_point_positions <= '0;
            two_point_positions <= '0;
            four_point_interpolated_data_ff <= '0;
            two_point_interpolated_data_ff <= '0;
            four_point_half_sums_ff <= '0;
            two_point_half_sums_ff <= '0;
            four_point_sum_ff <= '0;
            two_point_sum_ff <= '0;
            total_phi_ff <= '0;
            weighted_phi_ff <= '0;
            true_phi_ff <= '0;
            charge_ff <= '0;
            diff_ff <= '0;
            new_phi <= '0;

            //valids
            valid_addr <= 1'b0;
            valid_bram <= 1'b0;
            valid_gyroradius <= 1'b0;
            valid_positions <= 1'b0;
            valid_interpol <= 1'b0;
            valid_reduced <= 1'b0;
            valid_halfsum <= 1'b0;
            valid_sum <= 1'b0;
            valid_total <= 1'b0;
            valid_vmult <= '{default: 1'b0};
            valid_weighted_phi <= 1'b0;
            valid_true_phi <= 1'b0;
            valid_diff <= 1'b0;
            valid_mult <= '{default: 1'b0};
        end else begin
            if (valid) begin
                gyro_addr <= grid_addr;
                addr[0] <= grid_addr;
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
                valid_gyroradius <= 1'b1;
            end else begin
                valid_gyroradius <= 1'b0;
            end

            if (valid_gyroradius) begin
                for (int v = 0; v < NUM_DELTA; v++) begin
                    for (int i = 0; i < 4; i++) begin
                        //y and x components are treated seperately in order to enable proper wrapping behaviour
                        four_point_gyropoints_y[v][i] = addr[2].y + (i[1] ? gyroradius_ff[v] : -gyroradius_ff[v]);
                        four_point_gyropoints_x[v][i] = addr[2].x + (i[0] ? gyroradius_ff[v] : -gyroradius_ff[v]);
                        two_point_gyropoints_y[v][i] = addr[2].y + (i[1] ? (i[0] ? gyroradius_ff[v] << 1 : -gyroradius_ff[v] << 1) : 1'b0);
                        two_point_gyropoints_x[v][i] = addr[2].x + (i[1] ? 1'b0 : (i[0] ? gyroradius_ff[v] << 1 : -gyroradius_ff[v] << 1));
                    end
                end
                addr[3] <= addr[2];
                valid_positions <= 1'b1;
            end else begin
                valid_positions <= 1'b0;
            end 



            if (valid_interpol) begin
                four_point_interpolated_data_ff <= four_point_interpolated_data;
                two_point_interpolated_data_ff <= two_point_interpolated_data;
                addr[4] <= post_gyrocenter;
                valid_reduced <= 1'b1;
            end else begin
                valid_reduced <= 1'b0;
            end

            if (valid_reduced) begin
                for (int v = 0; v < NUM_DELTA; v++) begin
                    for (int i = 0; i < 2; i++) begin
                        four_point_half_sums_ff[v][i] <= four_point_interpolated_data_ff[v][i] + four_point_interpolated_data_ff[v][i+2];
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
                    total_phi_ff[v] <= (four_point_sum_ff[v] >>> 3) + (two_point_sum_ff[v] >>> 4);
                end
                charge_addr <= addr[6];
                addr[7] <= addr[6];
                valid_total <= 1'b1;
            end else begin
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
                    weighted_phi_ff[v] <= weighted_phi[v][PHIWIDTH+PFRAC*2+24-1-:PHIWIDTH];
                end
                addr[14] <= addr[13];
                valid_weighted_phi <= 1'b1;
            end else begin
                valid_weighted_phi <= 1'b0;
            end

            //TODO: add proper multiplication by -ki, for now we simply shift left by 2 and flip sign bit
            if (valid_weighted_phi) begin
                true_phi_ff <= (sum ^ 40'h8000000000) <<< 2;
                charge_ff <= $signed({1'b0, charge_in << (PHIFRAC - CFRAC)});
                addr[15] <= addr[14];
                valid_true_phi <= 1'b1;
            end else begin
                valid_true_phi <= 1'b0;
            end

            if (valid_true_phi) begin
                diff_ff <= charge_ff - true_phi_ff;
                addr[16] <= addr[15];
                valid_diff <= 1'b1;
            end else begin
                valid_diff <= 1'b0;
            end

            //wait 5 cycles for multiplication to be performed
            if (valid_diff) begin
                valid_mult[0]  <= 1'b1;
                addr[17] <= addr[16];
            end else begin
                valid_mult[0]  <= 1'b0;
            end

            for (int i = 1; i < 5; i++) begin
                if (valid_mult[i-1]) begin
                    valid_mult[i] <= 1'b1; 
                    addr[17+i] <= addr[16+i];
                end else begin
                    valid_mult[i] <= 1'b0;
                end
            end

            if (valid_mult[4]) begin
                phi_out <= {new_phi[CINT+PHIFRAC+24-:PHIINT], new_phi[46-:PHIFRAC]};
                waddr_out <= addr[21];
                valid_out <= 1'b1;
            end else begin
                valid_out <= 1'b0;
            end
        end
    end
endmodule