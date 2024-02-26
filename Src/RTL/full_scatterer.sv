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

module full_scatterer (
    input logic clk,
    input logic rst,
    input logic valid_scatter,
    input particle_t particle_in [1:0],
    output logic done,
    input logic valid_req,
    input addr_t [3:0] grid_addr_in [1:0],
    output charge_t [3:0] charge_out [1:0]

    //to/from UART
    input logic ui_valid,
    input logic wen,
    input addr_t addr_in,
    input bmag_t bmag_in
    );
    
    charge_t [3:0] charge [1:0] [1:0];

    addr_t [3:0] bmag_raddr [1:0];
    bmag_t [3:0] bmag_out [1:0];

    //ROMs containing bmag at every gridpoints
    grid_mem #(.WIDTH(BWIDTH), .NO_RST(1)) bmag_grid (
        .clk(clk),
        .rst(rst),
        .swap_rout(1'b1),
        .wea(ui_valid ? {0, 0, 0, wen} : 4'b0),
        .web(4'b0),
        .addra(ui_valid ? {'0, '0, '0, addr_in} : bmag_raddr[0]),
        .addrb(bmag_raddr[1]),
        .dina({'0, '0, '0, bmag_in}),
        .dinb('0),
        .douta(bmag_out[0]),
        .doutb(bmag_out[1]),
        .swapped_addra(),
        .swapped_addrb()
    );

    scatterer scatterer0 (
        .clk(clk),
        .rst(rst),
        .valid_scatter(valid_scatter),
        .particle_in(particle_in[0]),
        .bmag_in(bmag_out[0]),
        .bmag_raddr(bmag_raddr[0]),
        .done(done),
        .valid_req(valid_req),
        .grid_addr_in(grid_addr_in),
        .charge_out(charge[0])
    );

    scatterer scatterer1 (
        .clk(clk),
        .rst(rst),
        .valid_scatter(valid_scatter),
        .particle_in(particle_in[1]),
        .bmag_in(bmag_out[1]),
        .bmag_raddr(bmag_raddr[1]),
        .done(),
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
