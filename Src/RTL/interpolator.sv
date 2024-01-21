`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11/09/2023 10:25:19 PM
// Design Name: 
// Module Name: interpolator
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

module interpolator #(parameter DWIDTH = 16, parameter STAGES = 3, parameter UWIDTH = 0) (
    input logic clk,
    input logic rst,
    input logic valid,
    input logic zero,
    input pos_t pos,
    input logic [3:0] [DWIDTH-1:0] data_in,
    input logic [UWIDTH-1:0] user_in,
    output logic [GRID_ADDRWIDTH-1:0] raddr_out,
    output logic valid_out,
    output logic  [DWIDTH+PFRAC*2+1:0] interpolated_data_out,
    output logic [UWIDTH-1:0] user_out
    );

    //signals
    logic zero_ff [3:0];
    dist_t dist_ff;
    dist_t inv_dist_ff;
    logic [3:0] [DWIDTH-1:0] data_ff;
    logic [3:0] [PFRAC*2-1:0] coeff;
    logic [3:0] [PFRAC*2-1:0] coeff_ff;
    logic [3:0] [DWIDTH+PFRAC*2-1:0] partial_interpolated_data;
    logic [3:0] [DWIDTH+PFRAC*2-1:0] partial_interpolated_data_ff;
    logic [DWIDTH+PFRAC*2:0] lower_half_partial_ff;
    logic [DWIDTH+PFRAC*2:0] upper_half_partial_ff;
    logic [UWIDTH-1:0] user_ff [6+STAGES:0]; 

    //valids
    logic valid_dist;
    logic valid_mult0;
    logic valid_mult1;
    logic valid_mult2;
    logic valid_coeff;
    logic valid_data;
    logic [STAGES-1:0] valid_interpol;
    logic valid_partial;
    logic valid_halfpartial;


    //mults for calculating interpolation coefficients
    dist_mult mult00 (
        .CLK(clk),
        .A(inv_dist_ff.y_frac),
        .B(inv_dist_ff.x_frac),
        .P(coeff[0])
    );

    dist_mult mult01 (
        .CLK(clk),
        .A(inv_dist_ff.y_frac),
        .B(dist_ff.x_frac),
        .P(coeff[1])
    );

    dist_mult mult10 (
        .CLK(clk),
        .A(dist_ff.y_frac),
        .B(inv_dist_ff.x_frac),
        .P(coeff[2])
    );

    dist_mult mult11 (
        .CLK(clk),
        .A(dist_ff.y_frac),
        .B(dist_ff.x_frac),
        .P(coeff[3])
    );

    genvar n;
    generate;
        for (n = 0; n < 4; n++) begin
            case (DWIDTH)
                BWIDTH: begin
                    bmag_mult mult (
                        .CLK(clk),
                        .A(coeff_ff[n]),
                        .B(data_ff[n]),
                        .P(partial_interpolated_data[n])
                    );
                end 
                PHIWIDTH: begin
                    phi_mult mult (
                        .CLK(clk),
                        .A(coeff_ff[n]),
                        .B(data_ff[n]),
                        .P(partial_interpolated_data[n])
                    );
                end
                default: assign partial_interpolated_data[n] = 'hdead;
            endcase
        end
    endgenerate;

    always_ff @(posedge clk) begin
        if (rst) begin
            dist_ff <= {'0, '0};
            inv_dist_ff <= {'0, '0};
            for (int i = 0; i < 4; i++) begin
                data_ff[i] <= '0;
                coeff_ff[i] <= '0;
                partial_interpolated_data_ff[i] <= '0;
            end
            lower_half_partial_ff <= '0;
            upper_half_partial_ff <= '0;
            for (int i = 0; i < 7+STAGES; i++) begin
                user_ff[i] <= '0;
            end
            for (int i = 0; i <= 3; i++) begin
                zero_ff[i] <= 1'b0;
            end
            raddr_out <= '0;
            interpolated_data_out <= '0;
            user_out <= '0;
            valid_dist <= 1'b0;
            valid_mult0 <= 1'b0;
            valid_mult1 <= 1'b0;
            valid_mult2 <= 1'b0;
            valid_coeff <= 1'b0;
            valid_data <= 1'b0;
            for (int i = 0; i < STAGES; i++) begin
                valid_interpol[i] <= 1'b0;
            end
            valid_partial <= 1'b0;
            valid_halfpartial <= 1'b0;
            valid_out <= 1'b0;
        end else begin
            if (valid) begin
                dist_ff <= {pos.y[PFRAC-1:0], pos.x[PFRAC-1:0]};
                inv_dist_ff <={(12'b1 << PFRAC) - pos.y[PFRAC-1:0], (12'b1 << PFRAC) - pos.x[PFRAC-1:0]};
                raddr_out <= {pos.y[PWIDTH-1:PFRAC], pos.x[PWIDTH-1:PFRAC]};
                user_ff[0] <= user_in;
                zero_ff[0] <= zero;
                valid_dist <= 1'b1;
            end else begin
                valid_dist <= 1'b0;
            end

            //wait three cycles for the dist to be calculated and for data to be read
            if (valid_dist) begin
                user_ff[1] <= user_ff[0];
                zero_ff[1] <= zero_ff[0];
                valid_mult0 <= 1'b1;
            end else begin
                valid_mult0 <= 1'b0;
            end

            if (valid_mult0) begin
                user_ff[2] <= user_ff[1];
                zero_ff[2] <= zero_ff[1];
                valid_mult1 <= 1'b1;
            end else begin
                valid_mult1 <= 1'b0;
            end

            if (valid_mult1) begin
                user_ff[3] <= user_ff[2];
                zero_ff[3] <= zero_ff[2];
                valid_mult2 <= 1'b1;
            end else begin
                valid_mult2 <= 1'b0;
            end


            if (valid_mult2) begin
                for (int i = 0; i < 4; i++) begin
                    data_ff[i] <= zero_ff[3] ? '0 : data_in[i];
                    coeff_ff[i] <= coeff[i];
                end
                user_ff[4] <= user_ff[3];
                valid_coeff <= 1'b1;
            end else begin
                valid_coeff <= 1'b0;
            end
            
            if (valid_coeff) begin
                user_ff[5] <= user_ff[4];
                valid_interpol[0] <= 1'b1;
            end else begin
                valid_interpol[0] <= 1'b0;
            end

            //wait STAGES cycles for the multiplication to be performed
            for (int i = 1; i < STAGES; i++) begin
                if (valid_interpol[i-1]) begin
                    user_ff[5+i] <= user_ff[4+i];
                    valid_interpol[i] <= 1'b1;
                end else begin
                    valid_interpol[i] <= 1'b0;
                end
            end
            
            if (valid_interpol[STAGES-1]) begin
                for (int i = 0; i < 4; i++) begin
                    partial_interpolated_data_ff[i] <= partial_interpolated_data[i];
                end
                user_ff[5+STAGES] <= user_ff[4+STAGES];
                valid_partial <= 1'b1;
            end else begin
                valid_partial <= 1'b0;
            end

            if (valid_partial) begin
                lower_half_partial_ff <= partial_interpolated_data_ff[0] + partial_interpolated_data_ff[1];
                upper_half_partial_ff <= partial_interpolated_data_ff[2] + partial_interpolated_data_ff[3];
                user_ff[6+STAGES] <= user_ff[5+STAGES];
                valid_halfpartial <= 1'b1;
            end else begin
                valid_halfpartial <= 1'b0;
            end

            if (valid_halfpartial) begin
                interpolated_data_out <= lower_half_partial_ff + upper_half_partial_ff;
                user_out <= user_ff[6+STAGES];
                valid_out <= 1'b1;
            end else begin
                valid_out <= 1'b0;
            end
        end
    end
endmodule
