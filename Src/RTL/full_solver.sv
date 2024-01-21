`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11/29/2023 11:33:44 PM
// Design Name: 
// Module Name: full_solver
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: Combines two grid solvers together and connects them to the correct grid memories. 
// Also has logic that allows the pusher to fetch values phi 
// Dependencies: grid_solver, grid_mem
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

import defs::*;

module full_solver(
    input logic clk,
    input logic rst,
    input step_t step,
    input logic start,
    input logic [CWIDTH-1:0] charges,
    output logic [GRID_ADDRWIDTH-1:0] charge_raddr,
    output logic done,
    output logic valid_req_out,
    //for reading phi by pusher
    input logic valid_req,
    input logic [3:0] [3:0] [GRID_ADDRWIDTH-1:0] phi_raddr_in [1:0],
    output logic signed [3:0] [3:0] [3:0] [PHIWIDTH-1:0] phi_val [1:0]
    );

    logic [GRID_ADDRWIDTH-1:0] grid_addr;
    logic in_progress;
    logic first_it;
    logic [3:0] it_count;
    logic sel;
    //which of the BRAM banks contains the final phi values
    logic final_sel;
    logic signed [NUM_DELTA-1:0] [7:0] [3:0] [PHIWIDTH-1:0] phi_in [1:0];
    logic [NUM_DELTA-1:0] [7:0] [GRID_ADDRWIDTH-1:0] phi_raddr;
    logic [GRID_ADDRWIDTH-1:0] phi_waddr;
    logic signed [PHIWIDTH-1:0] phi_out;

    logic signed [3:0] [PHIWIDTH-1:0] din;

    assign first_it = it_count == '0;
    
    //module instantiation
     grid_solver solver0 (
        .clk(clk),
        .rst(rst),
        .valid(in_progress),
        .grid_y(grid_addr[GRID_ADDRWIDTH-1-:PINT]),
        .grid_x(grid_addr[PINT-1:0]),
        .first_it(first_it),
        .prev_in(phi_in[~sel]),
        .charge_in(charges),
        .valid_out(),
        .valid_req(valid_req_out),
        .charge_addr(charge_raddr),
        .raddr_out(phi_raddr),
        .waddr_out(phi_waddr),
        .phi_out(phi_out)
    );

    /*grid_solver solver1 (
        .clk(clk),
        .rst(rst),
        .valid(in_progress),
        .grid_y(grid_addr[1][GRID_ADDRWIDTH-1-:PINT]),
        .grid_x(grid_addr[1][PINT-1:0]),
        .first_it(first_it),
        .prev_in(phi_in[1][~sel]),
        .charge_in(charges[1]),
        .valid_out(),
        .charge_addr(charge_raddr[1]),
        .raddr_out(phi_raddr[1]),
        .waddr_out(phi_waddr[1]),
        .phi_out(phi_out[1])
    );*/

    assign din[0] = phi_out;
    assign din[1] = '0;
    assign din[2] = '0;
    assign din[3] = '0;

    //1 grid solver
    //each grid solver requires 2 groups of 4 * 3 grid memories, one to read to and on to write to
    //each grid memory requires 4 brams, for a total of 96 brams
    //to this, we add 2*4*4 = 32 brams for the pusher to read from
    generate;
        for (genvar v = 0; v < NUM_DELTA; v++) begin
            for (genvar j = 0; j < 4; j++) begin
                for (genvar k = 0; k < 2; k++) begin
                    if (v == 0 || v == 1) begin
                        grid_mem #(.WIDTH(PHIWIDTH), .NO_RST(1)) phi_mem_sp (
                            .clk(clk),
                            .rst(rst),
                            .swap_rout(1'b1),
                            .wea((sel == k && step == SOLVE) ? 4'b1 : 4'b0),
                            .web(4'b0),
                            .addra((step == SOLVE) ? ((sel == k) ? phi_waddr : phi_raddr[v][j]) : phi_raddr_in[v][j][0]),
                            .addrb((step == SOLVE) ? ((sel == k) ? phi_waddr : phi_raddr[v][j+4]) : phi_raddr_in[v][j][1]),
                            .dina(din),
                            .dinb('0),
                            .uina('0),
                            .uinb('0),
                            .douta(phi_in[k][v][j]),
                            .doutb(phi_in[k][v][j+4]),
                            .uouta(),
                            .uoutb()
                        );
                    end else begin
                        grid_mem #(.WIDTH(PHIWIDTH), .NO_RST(1)) phi_mem_s (
                            .clk(clk),
                            .rst(rst),
                            .swap_rout(1'b1),
                            .wea((sel == k && step == SOLVE) ? 4'b1 : 4'b0),
                            .web(4'b0),
                            .addra((sel == k) ? phi_waddr : phi_raddr[v][j]),
                            .addrb((sel == k) ? phi_waddr : phi_raddr[v][j+4]),
                            .dina(din),
                            .dinb('0),
                            .uina('0),
                            .uinb('0),
                            .douta(phi_in[k][v][j]),
                            .doutb(phi_in[k][v][j+4]),
                            .uouta(),
                            .uoutb()
                        );
                    end
                end
            end
        end
    endgenerate

    //extra brams for pusher
    generate
        for (genvar i = 0; i < 2; i++) begin
            for (genvar j = 0; j < 4; j++) begin
                grid_mem #(.WIDTH(PHIWIDTH), .NO_RST(1)) phi_mem_p (
                    .clk(clk),
                    .rst(rst),
                    .swap_rout(1'b1),
                    .wea((step == SOLVE) ? 4'b1 : 4'b0),
                    .web(4'b0),
                    .addra((step == SOLVE) ? phi_waddr : phi_raddr_in[i][j][2]),
                    .addrb(phi_raddr_in[i][j][3]),
                    .dina(din),
                    .dinb('0),
                    .uina('0),
                    .uinb('0),
                    .douta(phi_val[i][j][2]),
                    .doutb(phi_val[i][j][3]),
                    .uouta(),
                    .uoutb()
                );
            end
        end
    endgenerate

    //assign phi_val output
    always_comb begin
        for (int i = 0; i < 2; i++) begin
            for (int j = 0; j < 4; j++) begin
                phi_val[i][j][0] = phi_in[final_sel][i][j];
                phi_val[i][j][1] = phi_in[final_sel][i][j+4];
            end
        end
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            grid_addr <= 12'h0;
            it_count <= '0;
            sel <= 1'b0;
            final_sel <= 1'b0;
            in_progress <= 1'b0;
            done <= 1'b0;
        end else begin
            if (step == SOLVE) begin
                if (in_progress) begin
                    if (grid_addr == 12'h7ff) begin //also means that grid_addr[1] has finished sweep
                        if (it_count == NUM_IT - 1) begin
                            in_progress <= 1'b0;
                            done <= 1'b1;
                            final_sel <= sel;
                        end else begin
                            it_count <= it_count + 1'b1;
                            sel <= ~sel;
                            grid_addr <= 12'h0;
                        end
                    end else begin
                       grid_addr <= grid_addr + 1'b1;
                    end

                end else begin
                    if (start) begin
                        it_count <= '0;
                        sel <= 1'b0;
                        grid_addr <= 12'h0;
                        in_progress <= 1'b1;
                        done <= 1'b0;
                    end
                end
            /*end else if (step == PUSH) begin
                if (valid_req) begin
                   valid_addr <= 1'b1; 
                end else begin
                     valid_addr <= 1'b0; 
                 end

                if (valid_addr) begin
                    valid_bram <= 1'b1;
                end else begin
                    valid_bram <= 1'b0;
                end

                if (valid_bram) begin
                    valid_phi <= 1'b1;
                end else begin
                    valid_phi <= 1'b0;
                end*/
            end 
        end
    end
endmodule
