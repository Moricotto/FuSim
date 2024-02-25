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
    input posvec_t pos,
    input logic [UWIDTH-1:0] user_in, 
    output logic valid_out,
    output logic  [DWIDTH+PFRAC*2-1:0] interpolated_data_out,
    output logic [UWIDTH-1:0] user_out,
    //bram communication
    input logic [3:0] [DWIDTH-1:0] data_in,
    output addr_t [3:0] raddr_out
    );

    //signals
    dist_t dist_ff [3:0];
    dist_t inv_dist_ff [3:0];
    logic [3:0] [DWIDTH-1:0] data_ff;
    logic [3:0] [PFRAC*2-1:0] coeff;
    logic [3:0] [PFRAC*2-1:0] coeff_ff [1:0];
    logic [DWIDTH-1:0] ll [STAGES:0];
    logic special [1+STAGES:0];
    logic [3:0] [DWIDTH+PFRAC*2-1:0] partial_interpolated_data;
    logic [3:0] [DWIDTH+PFRAC*2-1:0] partial_interpolated_data_ff;
    logic [DWIDTH+PFRAC*2-1:0] lower_half_partial_ff;
    logic [DWIDTH+PFRAC*2-1:0] upper_half_partial_ff;
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
        .A(inv_dist_ff[0].y_frac),
        .B(inv_dist_ff[0].x_frac),
        .P(coeff[0])
    );

    dist_mult mult01 (
        .CLK(clk),
        .A(inv_dist_ff[0].y_frac),
        .B(dist_ff[0].x_frac),
        .P(coeff[1])
    );

    dist_mult mult10 (
        .CLK(clk),
        .A(dist_ff[0].y_frac),
        .B(inv_dist_ff[0].x_frac),
        .P(coeff[2])
    );

    dist_mult mult11 (
        .CLK(clk),
        .A(dist_ff[0].y_frac),
        .B(dist_ff[0].x_frac),
        .P(coeff[3])
    );

    genvar n;
    generate;
        for (n = 0; n < 4; n++) begin
            case (DWIDTH)
                BWIDTH: begin
                    bmag_mult mult (
                        .CLK(clk),
                        .A(coeff_ff[1][n]),
                        .B(data_ff[n]),
                        .P(partial_interpolated_data[n])
                    );
                end 
                PHIWIDTH: begin
                    phi_mult mult (
                        .CLK(clk),
                        .A(coeff_ff[1][n]),
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
            dist_ff <= '{default:{'0, '0}};
            inv_dist_ff <= '{default: {'0, '0}};
            for (int i = 0; i < 4; i++) begin
                data_ff[i] <= '0;
                coeff_ff[i] <= '0;
                partial_interpolated_data_ff[i] <= '0;
            end
            lower_half_partial_ff <= '0;
            upper_half_partial_ff <= '0;
            for (int i = 0; i < 8+STAGES; i++) begin
                user_ff[i] <= '0;
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
                dist_ff[0] <= {pos.y.fraction, pos.x.fraction};
                inv_dist_ff[0] <={12'hfff - pos.y.fraction + 1, 12'hfff - pos.x.fraction + 1}; //note that if this is zero, dist must also be zero
                for (int i = 0; i < 4; i++) begin
                    raddr_out[i] <= {pos.y.whole + i[1], pos.x.whole + i[0]};
                end
                user_ff[0] <= user_in;
                valid_dist <= 1'b1;
            end else begin
                valid_dist <= 1'b0;
            end

            //wait three cycles for the dist to be calculated and four for the data to be read
            if (valid_dist) begin
                dist_ff[1] <= dist_ff[0];
                user_ff[1] <= user_ff[0];
                valid_mult0 <= 1'b1;
            end else begin
                valid_mult0 <= 1'b0;
            end

            if (valid_mult0) begin
                dist_ff[2] <= dist_ff[1];
                user_ff[2] <= user_ff[1];
                valid_mult1 <= 1'b1;
            end else begin
                valid_mult1 <= 1'b0;
            end

            if (valid_mult1) begin
                dist_ff[3] <= dist_ff[2];
                user_ff[3] <= user_ff[2];
                valid_mult2 <= 1'b1;
            end else begin
                valid_mult2 <= 1'b0;
            end


            if (valid_mult2) begin
                special[0] <= dist_ff[3].y_frac == '0 && dist_ff[3].x_frac == '0;
                if (dist_ff[3].y_frac == '0) begin
                    coeff_ff[0][0] <= inv_dist_ff[3].x_frac << 12;
                    coeff_ff[0][1] <= dist_ff[3].x_frac << 12;
                    coeff_ff[0][2] <= '0;
                    coeff_ff[0][3] <= '0;
                end else if (dist_ff[3].x_frac == '0) begin
                    coeff_ff[0][0] <= inv_dist_ff[3].y_frac << 12;
                    coeff_ff[0][1] <= '0;
                    coeff_ff[0][2] <= dist_ff[3].y_frac << 12;
                    coeff_ff[0][3] <= '0;
                end else begin
                    for (int i = 0; i < 4; i++) begin
                        coeff_ff[0][i] <= coeff[i];
                    end
                end
                user_ff[4] <= user_ff[3];
                valid_coeff <= 1'b1;
            end else begin
                valid_coeff <= 1'b0;
            end

            if (valid_coeff) begin
                special[1] <= special[0];
                for (int i = 0; i < 4; i++) begin
                    data_ff[i] <= data_in[i];
                    coeff_ff[1][i] <= coeff_ff[0][i];
                end
                user_ff[5] <= user_ff[4];
                valid_data <= 1'b1;
            end else begin
                valid_data <= 1'b0;
            end
            
            //begin the interpolation
            if (valid_data) begin
                ll[0] <= data_ff[0];
                special[2] <= special[1];
                user_ff[6] <= user_ff[5];
                valid_interpol[0] <= 1'b1;
            end else begin
                valid_interpol[0] <= 1'b0;
            end

            //wait STAGES cycles for the multiplication to be performed
            for (int i = 1; i < STAGES; i++) begin
                if (valid_interpol[i-1]) begin
                    ll[1+i] <= ll[i];
                    special[2+i] <= special[1+i];
                    user_ff[6+i] <= user_ff[5+i];
                    valid_interpol[i] <= 1'b1;
                end else begin
                    valid_interpol[i] <= 1'b0;
                end
            end
            
            if (valid_interpol[STAGES-1]) begin
                for (int i = 0; i < 4; i++) begin
                    partial_interpolated_data_ff[i] <= special[1+STAGES] ? ((i == 0) ? ll[STAGES] << 24 : '0) : partial_interpolated_data[i];
                end
                user_ff[6+STAGES] <= user_ff[5+STAGES];
                valid_partial <= 1'b1;
            end else begin
                valid_partial <= 1'b0;
            end

            if (valid_partial) begin
                lower_half_partial_ff <= partial_interpolated_data_ff[0] + partial_interpolated_data_ff[1];
                upper_half_partial_ff <= partial_interpolated_data_ff[2] + partial_interpolated_data_ff[3];
                user_ff[7+STAGES] <= user_ff[6+STAGES];
                valid_halfpartial <= 1'b1;
            end else begin
                valid_halfpartial <= 1'b0;
            end

            if (valid_halfpartial) begin
                interpolated_data_out <= lower_half_partial_ff + upper_half_partial_ff;
                user_out <= user_ff[7+STAGES];
                valid_out <= 1'b1;
            end else begin
                valid_out <= 1'b0;
            end
        end
    end
endmodule
