`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10/01/2023 01:40:34 PM
// Design Name: 
// Module Name: accumulator
// Project Name: plasma_sim
// Target Devices: Kintex-7 FPGA KC705 Evaluation Kit
// Tool Versions: Vivado 2023
// Description: 
// Controls the read-accum-write process of the charge scatter
// Takes as input the adress of the gyropoint that the charge is being scattered to
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

import defs::*;

module accumulator (
    input logic clk,
    input logic rst,
    input logic valid_in,
    input logic [PWIDTH-1:0] gyropoint_y, 
    input logic [PWIDTH-1:0] gyropoint_x,
    input logic [3:0] [CWIDTH-1:0] charge_in,
    input logic [3:0] [GRID_ADDRWIDTH-1:0] uin,
    output logic [GRID_ADDRWIDTH-1:0] waddr_out,
    output logic [3:0] [CWIDTH-1:0] charge_out,
    output logic [GRID_ADDRWIDTH-1:0] raddr_out,
    output logic [3:0] [GRID_ADDRWIDTH-1:0] uout
    );
    
    //flip-flops & corresponding valids
    dist_t dist_ff;
    dist_t inv_dist_ff;
    logic valid_raddr;
    logic valid_mult0;
    logic valid_mult1;
    logic valid_mult2;
    logic [3:0] [PFRAC*2-1:0] charge_coeff;
    logic [3:0] [PFRAC*2-1:0] charge_coeff_ff;
    logic [3:0] [CWIDTH-1:0] stored_charge_ff;
    logic valid_stored_charge;
    logic [3:0] [2:0] addend_sel;
    logic [3:0] [CWIDTH-1:0] new_charge_ff;
    logic valid_new_charge;
    logic [3:0] [CWIDTH-1:0] post_charge_ff;
    logic valid_post_charge;
    logic [3:0] [CWIDTH-1:0] post_post_charge_ff;
    logic valid_post_post_charge;
    logic [3:0] [CWIDTH-1:0] post_post_post_charge_ff;
    logic [3:0] [GRID_ADDRWIDTH-1:0] addr [4:0];
    logic [GRID_ADDRWIDTH-1:0] waddr [5:0];

    dist_mult mult00 (
        .CLK(clk),
        .A(inv_dist_ff.y_frac),
        .B(inv_dist_ff.x_frac),
        .P(charge_coeff[0])
    );

    dist_mult mult01 (
        .CLK(clk),
        .A(inv_dist_ff.y_frac),
        .B(dist_ff.x_frac),
        .P(charge_coeff[1])
    );

    dist_mult mult10 (
        .CLK(clk),
        .A(dist_ff.y_frac),
        .B(inv_dist_ff.x_frac),
        .P(charge_coeff[2])
    );

    dist_mult mult11 (
        .CLK(clk),
        .A(dist_ff.y_frac),
        .B(dist_ff.x_frac),
        .P(charge_coeff[3])
    );

    assign raddr_out = addr[0][0];
    assign waddr_out = waddr[5];
    assign uout = addr[0];
    assign charge_out = new_charge_ff;
    

    always_ff @(posedge clk) begin
        if (rst) begin
            for (int i = 0; i < 4; i++) begin
                charge_coeff_ff[i] <= '0;
                stored_charge_ff[i] <= '0;
                new_charge_ff[i] <= '0;
                post_charge_ff[i] <= '0;
                post_post_charge_ff[i] <= '0;
                post_post_post_charge_ff[i] <= '0;
            end
            dist_ff <= '0;
            inv_dist_ff <= '0;
            for (int i = 0; i < 6; i++) begin
                for (int j = 0; j < 4; j++) begin
                    if (i != 5) begin
                        addr[i][j] <= '0;
                    end
                end
                waddr[i] <= '0;
            end
            valid_raddr <= 1'b0;
            valid_mult0 <= 1'b0;
            valid_mult1 <= 1'b0;
            valid_mult2 <= 1'b0;
            valid_stored_charge <= 1'b0;
            valid_new_charge <= 1'b0;
            valid_post_charge <= 1'b0;
            valid_post_post_charge <= 1'b0;
            
        end else begin
            //stage 1
            if (valid_in) begin
                dist_ff <= {gyropoint_y[PFRAC-1:0], gyropoint_x[PFRAC-1:0]};
                inv_dist_ff <= {(12'b1 << PFRAC) - gyropoint_y[PFRAC-1:0], (12'b1 << PFRAC) - gyropoint_x[PFRAC-1:0]};
                for (int i = 0; i < 4; i++) begin
                    addr[0][i] <= {gyropoint_y[PWIDTH-1:PFRAC] + i[1], gyropoint_x[PWIDTH-1:PFRAC] + i[0]};
                end
                waddr[0] <= {gyropoint_y[PWIDTH-1:PFRAC], gyropoint_x[PWIDTH-1:PFRAC]};
                valid_raddr <= 1;
            end else begin
                valid_raddr <= 0;
            end

            //wait three clocks for the read and the multiplies
            if (valid_raddr) begin
                valid_mult0 <= 1'b1;
                waddr[1] <= waddr[0];
            end else begin
                valid_mult0 <= 1'b0;
            end

            if (valid_mult0) begin
                valid_mult1 <= 1'b1;
                waddr[2] <= waddr[1];
            end else begin
                valid_mult1 <= 1'b0;
            end

            if (valid_mult1) begin
                valid_mult2 <= 1'b1;
                waddr[3] <= waddr[2];
            end else begin
                valid_mult2 <= 1'b0;
            end

            if (valid_mult2) begin
                for (int i = 0; i < 4; i++) begin
                    //divide by 4 because each gyropoint carries only a quarter of the particle's charge
                    charge_coeff_ff[i] <= charge_coeff[i] >> 2;
                    stored_charge_ff[i] <= charge_in[i];
                    addr[1][i] <= uin[i];
                    addend_sel[i] <= 
                        (addr[1][i] == uin[i]) ? 3'b00 :
                        (addr[2][i] == uin[i]) ? 3'b01 :
                        (addr[3][i] == uin[i]) ? 3'b10 :
                        (addr[4][i] == uin[i]) ? 3'b11 : 3'b100;

                end
                waddr[4] <= waddr[3];
                valid_stored_charge <= 1'b1;
            end else begin
                valid_stored_charge <= 1'b0;
            end

            if (valid_stored_charge) begin
                for (int i = 0; i < 4; i++) begin
                    if (addend_sel[i][2]) begin
                        new_charge_ff[i] <= stored_charge_ff[i] + charge_coeff_ff[i];
                    end else begin
                        unique case (addend_sel[1:0])
                            2'b00: new_charge_ff[i] <= new_charge_ff[i] + charge_coeff_ff[i];
                            2'b01: new_charge_ff[i] <= post_charge_ff[i] + charge_coeff_ff[i];
                            2'b10: new_charge_ff[i] <= post_post_charge_ff[i] + charge_coeff_ff[i];
                            2'b11: new_charge_ff[i] <= post_post_post_charge_ff[i] + charge_coeff_ff[i];
                        endcase
                    end
                    addr[2][i] <= addr[1][i];
                end
                waddr[5] <= waddr[4];
                valid_new_charge <= 1'b1;
            end else begin
                valid_new_charge <= 1'b0;
            end

            if (valid_new_charge) begin
                for (int i = 0; i < 4; i++) begin
                    post_charge_ff[i] <= new_charge_ff[i];
                    addr[3][i] <= addr[2][i];
                end
                valid_post_charge <= 1'b1;
            end else begin
                valid_post_charge <= 1'b0;
            end

            if (valid_post_charge) begin
                for (int i = 0; i < 4; i++) begin
                    post_post_charge_ff[i] <= post_charge_ff[i];
                    addr[4][i] <= addr[3][i];
                end
                valid_post_post_charge <= 1'b1;
            end else begin
                valid_post_post_charge <= 1'b0;
            end

            if (valid_post_post_charge) begin
                for (int i = 0; i < 4; i++) begin
                    post_post_post_charge_ff[i] <= post_post_charge_ff[i];
                end
            end
        end
    end
endmodule