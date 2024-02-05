`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 12/02/2023 10:56:39 PM
// Design Name: 
// Module Name: full_scatterer
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

//TODO: fix charge requisition
module full_scatterer(
    input logic clk,
    input logic rst,
    input logic valid_scatter,
    input particle_t particle_in [1:0],
    input logic valid_req,
    input addr_t grid_addr_in [1:0],
    output charge_t [3:0] charge_out [1:0]
    );
    
    charge_t [3:0] charge [1:0] [1:0];

    scatterer scatterer0 (
        .clk(clk),
        .rst(rst),
        .valid_scatter(valid_scatter),
        .particle_in(particle_in[0]),
        .valid_req(valid_req),
        .grid_addr_in(grid_addr_in),
        .charge_out(charge[0])
    );

    scatterer scatterer1 (
        .clk(clk),
        .rst(rst),
        .valid_scatter(valid_scatter),
        .particle_in(particle_in[1]),
        .valid_req(valid_req),
        .grid_addr_in(grid_addr_in),
        .charge_out(charge[1])
    );

    always_comb begin
        for (int i = 0; i < 2; i++) begin
            for (int j = 0; j < 4; j++) begin
                charge_out[i][j] = charge[0][i][j] + charge[1][i][j];
            end
        end
    end

endmodule
