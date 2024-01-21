`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10/13/2023 06:53:01 PM
// Design Name: 
// Module Name: lfsr
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


module lfsr #(parameter WIDTH = 16, parameter DEPTH = 16, parameter TAPS = 16'h002d, parameter INIT = 16'hace1) (
    input logic clk,
    input logic rst,
    output logic [WIDTH-1:0] data
    );

    logic [DEPTH-1:0] state [WIDTH-1:0];
    logic [DEPTH-1:0] init;

    always @(posedge clk) begin 
        if (rst) begin
            init = INIT;
            for (int i = 0; i < WIDTH; i++) begin
                state[i] <= init;
                data[i] <= init[0];
                init += 567;
            end
        end else begin
            for (int i = 0; i < WIDTH; i++) begin
                data[i] <= state[i][0];
                state[i] <= {^(state[i] & TAPS), state[i][DEPTH-1:1]};
            end
        end
    end
endmodule
