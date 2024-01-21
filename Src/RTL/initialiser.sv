`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 12/05/2023 05:07:53 PM
// Design Name: 
// Module Name: initialiser
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
parameter NUM_PARTICLES_X = 128;
parameter NUM_PARTICLES_Y = 128;
parameter STEP_X = (2**PWIDTH) / NUM_PARTICLES_X;
parameter STEP_Y = (2**PWIDTH) / NUM_PARTICLES_Y;
import defs::*; 

module initialiser(
    input logic clk,
    input logic rst,
    output logic tlast_out,
    output particle_t particle_out
    );

    logic [PWIDTH-1:0] y, x;
    logic [$clog2(NUM_PARTICLES_X)-1:0] x_count;
    logic [$clog2(NUM_PARTICLES_Y)-1:0] y_count;
    
    assign particle_out = {y, x, 14'b00100000000000};
    always_ff @(posedge clk) begin
        if (rst) begin
            y <= '0;
            x <= '0;
            x_count <= '0;
            y_count <= '0;
            tlast_out <= 1'b0;
        end else begin
            if (x_count == NUM_PARTICLES_X - 1) begin
                if (y_count == NUM_PARTICLES_Y - 1) begin
                    tlast_out <= 1'b1;
                    y <= '0;
                    x <= '0;
                    x_count <= '0;
                    y_count <= '0;
                end else begin
                    x_count <= '0;
                    y_count <= y_count + 1;
                    y <= y + STEP_Y;
                    x <= '0;
                    tlast_out <= 1'b0;
                end
            end else begin
                x <= x + STEP_X;
                x_count <= x_count + 1;
                tlast_out <= 1'b0;
            end
        end
    end

endmodule
