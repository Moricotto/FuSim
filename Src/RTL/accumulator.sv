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
    input posvec_t gyropoint,
    input charge_t [3:0] charge_in,
    input addr_t [3:0] swapped_addr_in,
    output addr_t [3:0] raddr_out, //address to read old charge from 
    output addr_t [3:0] waddr_out,
    output charge_t [3:0] charge_out
    );
    
    //flip-flops & corresponding valids
    dist_t dist_ff [3:0];
    dist_t inv_dist_ff [3:0];
    logic valid_raddr;
    logic valid_mult0;
    logic valid_mult1;
    logic valid_mult2;
    coeff_t [3:0] charge_coeff;
    coeff_t [3:0] charge_coeff_ff;
    logic valid_coeffs;
    charge_t [3:0] stored_charge_ff;
    logic valid_stored_charge;
    logic [3:0] [2:0] addend_sel;
    charge_t [3:0] new_charge_ff;
    logic valid_new_charge;
    charge_t [3:0] post_charge_ff;
    logic valid_post_charge;
    charge_t [3:0] post_post_charge_ff;
    logic valid_post_post_charge;
    charge_t [3:0] post_post_post_charge_ff;
    logic valid_post_post_post_charge;
    charge_t [3:0] post_post_post_post_charge_ff;
    addr_t [3:0] addr [4:0];

    dist_mult mult00 (
        .CLK(clk),
        .A(inv_dist_ff[0].y_frac),
        .B(inv_dist_ff[0].x_frac),
        .P(charge_coeff[0])
    );

    dist_mult mult01 (
        .CLK(clk),
        .A(inv_dist_ff[0].y_frac),
        .B(dist_ff[0].x_frac),
        .P(charge_coeff[1])
    );

    dist_mult mult10 (
        .CLK(clk),
        .A(dist_ff[0].y_frac),
        .B(inv_dist_ff[0].x_frac),
        .P(charge_coeff[2])
    );

    dist_mult mult11 (
        .CLK(clk),
        .A(dist_ff[0].y_frac),
        .B(dist_ff[0].x_frac),
        .P(charge_coeff[3])
    );

    assign raddr_out = addr[0];
    assign waddr_out = addr[1];
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
                post_post_post_post_charge_ff[i] <= '0;
            end
            dist_ff <= '{default:'0};
            inv_dist_ff <= '{default:'0};
            for (int i = 0; i < 6; i++) begin
                for (int j = 0; j < 4; j++) begin
                    if (i != 5) begin
                        addr[i][j] <= '0;
                    end
                end
            end
            valid_raddr <= 1'b0;
            valid_mult0 <= 1'b0;
            valid_mult1 <= 1'b0;
            valid_mult2 <= 1'b0;
            valid_stored_charge <= 1'b0;
            valid_new_charge <= 1'b0;
            valid_post_charge <= 1'b0;
            valid_post_post_charge <= 1'b0;
            valid_post_post_post_charge <= 1'b0;
        end else begin
            //stage 1
            if (valid_in) begin
                dist_ff[0].y_frac <= gyropoint.y.fraction;
                dist_ff[0].x_frac <= gyropoint.x.fraction;
                inv_dist_ff[0].y_frac <= 12'hfff - gyropoint.y.fraction + 1'b1;
                inv_dist_ff[0].x_frac <= 12'hfff - gyropoint.x.fraction + 1'b1;
                for (int i = 0; i < 4; i++) begin
                    addr[0][i] <= {gyropoint.y.whole + i[1], gyropoint.x.whole + i[0]};
                end
                valid_raddr <= 1;
            end else begin
                valid_raddr <= 0;
            end

            //wait three clocks for the multiply and four for the read
            if (valid_raddr) begin
                dist_ff[1] <= dist_ff[0];
                inv_dist_ff[1] <= inv_dist_ff[0];
                valid_mult0 <= 1'b1;
            end else begin
                valid_mult0 <= 1'b0;
            end

            if (valid_mult0) begin
                dist_ff[2] <= dist_ff[1];
                inv_dist_ff[2] <= inv_dist_ff[1];
                valid_mult1 <= 1'b1;
            end else begin
                valid_mult1 <= 1'b0;
            end

            if (valid_mult1) begin
                dist_ff[3] <= dist_ff[2];
                inv_dist_ff[3] <= inv_dist_ff[2];
                valid_mult2 <= 1'b1;
            end else begin
                valid_mult2 <= 1'b0;
            end
            if (valid_mult2) begin
                if (dist_ff[3].y_frac == '0 && dist_ff[3].x_frac == '0) begin
                    charge_coeff_ff[0] <= 24'h400000;
                end else if (dist_ff[3].y_frac == '0) begin
                    charge_coeff_ff[0] <= inv_dist_ff[3].x_frac << 12;
                    charge_coeff_ff[1] <= dist_ff[3].x_frac << 12;
                    charge_coeff_ff[2] <= '0;
                    charge_coeff_ff[3] <= '0;
                end else if (dist_ff[3].x_frac == '0) begin
                    charge_coeff_ff[0] <= inv_dist_ff[3].y_frac << 12;
                    charge_coeff_ff[1] <= '0;
                    charge_coeff_ff[2] <= dist_ff[3].y_frac << 12;
                    charge_coeff_ff[3] <= '0;
                end else begin
                    for (int i = 0; i < 4; i++) begin
                        charge_coeff_ff[i] <= charge_coeff[i];
                    end
                end
                valid_coeffs <= 1'b1;
            end else begin
                valid_coeffs <= 1'b0;
            end
            
            if (valid_coeffs) begin
                for (int i = 0; i < 4; i++) begin
                    stored_charge_ff[i] <= charge_in[i];
                    addr[0][i] <= swapped_addr_in[i];
                    charge_coeff_ff[1][i] <= charge_coeff_ff[0][i];
                    addend_sel[i] <= 
                        (addr[0][i] == swapped_addr_in[i]) ? 3'b000 :
                        (addr[1][i] == swapped_addr_in[i]) ? 3'b001 :
                        (addr[2][i] == swapped_addr_in[i]) ? 3'b010 :
                        (addr[3][i] == swapped_addr_in[i]) ? 3'b011 : 
                        (addr[4][i] == swapped_addr_in[i]) ? 3'b100 : 3'b101;
                end
                valid_stored_charge <= 1'b1;
            end else begin
                valid_stored_charge <= 1'b0;
            end

            if (valid_stored_charge) begin
                for (int i = 0; i < 4; i++) begin
                    unique case (addend_sel)
                            3'b000: new_charge_ff[i] <= new_charge_ff[i] + charge_coeff_ff[i];
                            3'b001: new_charge_ff[i] <= post_charge_ff[i] + charge_coeff_ff[i];
                            3'b010: new_charge_ff[i] <= post_post_charge_ff[i] + charge_coeff_ff[i];
                            3'b011: new_charge_ff[i] <= post_post_post_charge_ff[i] + charge_coeff_ff[i];
                            3'b100: new_charge_ff[i] <= post_post_post_post_charge_ff[i] + charge_coeff_ff[i];
                            3'b101: new_charge_ff[i] <= stored_charge_ff[i] + charge_coeff_ff[i];
                    endcase
                    addr[1][i] <= addr[0][i];
                end
                valid_new_charge <= 1'b1;
            end else begin
                valid_new_charge <= 1'b0;
            end

            if (valid_new_charge) begin
                for (int i = 0; i < 4; i++) begin
                    post_charge_ff[i] <= new_charge_ff[i];
                    addr[2][i] <= addr[1][i];
                end
                valid_post_charge <= 1'b1;
            end else begin
                valid_post_charge <= 1'b0;
            end

            if (valid_post_charge) begin
                for (int i = 0; i < 4; i++) begin
                    post_post_charge_ff[i] <= post_charge_ff[i];
                    addr[3][i] <= addr[2][i];
                end
                valid_post_post_charge <= 1'b1;
            end else begin
                valid_post_post_charge <= 1'b0;
            end

            if (valid_post_post_charge) begin
                for (int i = 0; i < 4; i++) begin
                    post_post_post_charge_ff[i] <= post_post_charge_ff[i];
                    addr[4][i] <= addr[3][i];
                end
                valid_post_post_post_charge <= 1'b1;
            end else begin
                valid_post_post_post_charge <= 1'b0;
            end

            if (valid_post_post_post_charge) begin
                for (int i = 0; i < 4; i++) begin
                    post_post_post_post_charge_ff[i] <= post_post_post_charge_ff[i];
                end
            end


        end
    end
endmodule