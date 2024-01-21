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


module full_scatterer(
    input logic clk,
    input logic rst,
    input step_t step,
    input logic valid_scatter,
    input logic tlast_in,
    input particle_t particle_in [1:0],
    output logic tlast_out,
    input logic valid_req,
    input logic [GRID_ADDRWIDTH-1:0] grid_addr_in [1:0],
    output logic [3:0] [CWIDTH-1:0] charge_out [1:0]
    );
    
    logic [3:0] [CWIDTH-1:0] charge [1:0] [1:0];

    scatterer scatterer0 (
        .clk(clk),
        .rst(rst),
        .step(step),
        .valid_scatter(valid_scatter),
        .tlast_in(tlast_in),
        .particle_in(particle_in[0]),
        .tlast_out(tlast_out),
        .valid_req(valid_req),
        .grid_addr_in(grid_addr_in),
        .charge_out(charge[0])
    );

    scatterer scatterer1 (
        .clk(clk),
        .rst(rst),
        .step(step),
        .valid_scatter(valid_scatter),
        .tlast_in(),
        .particle_in(particle_in[1]),
        .tlast_out(),
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
