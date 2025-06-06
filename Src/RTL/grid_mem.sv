`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11/01/2023 06:18:40 PM
// Design Name: 
// Module Name: grid_mem
// Project Name: Plasma Sim 
// Target Devices: KC705 Kintex-7 Evaluation Kit
// Tool Versions: 
// Description: An array of four BRAMS, each representing a quarter of the grid ending in the same bits in the x and y coordinates.
// Allows for simultaneous read and write, read and read or write and write to a group of four adjacent grid points.
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

import defs::*;

module grid_mem #(parameter WIDTH = 36, parameter NO_RST = 0) (
    input logic clk,
    input logic rst,
    input logic swap_rout,
    input logic [3:0] wea,
    input logic [3:0] web,
    input addr_t [3:0] addra,
    input addr_t [3:0] addrb,
    input logic [3:0] [WIDTH-1:0] dina,
    input logic [3:0] [WIDTH-1:0] dinb,
    output logic [3:0] [WIDTH-1:0] douta,
    output logic [3:0] [WIDTH-1:0] doutb,
    output addr_t [3:0] swapped_addra,
    output addr_t [3:0] swapped_addrb
    );

    //corresponds to PHYSICAL brams, that is, after all remappings have been applied
    logic [3:0] [NUM_CELLS/4-1:0] reset_bank;

    //signals
    logic [3:0] [GRID_ADDRWIDTH-3:0] true_addra;
    logic [3:0] [GRID_ADDRWIDTH-3:0] true_addrb;
    logic [3:0] [1:0] sela;
    logic [3:0] [1:0] selb;
    logic [3:0] [1:0] sela_ff [2:0];
    logic [3:0] [1:0] selb_ff [2:0];
    logic [3:0] do_reseta [1:0];
    logic [3:0] do_resetb [1:0];
    logic [3:0] [WIDTH-1:0] swapped_dina;
    logic [3:0] [WIDTH-1:0] swapped_dinb;
    logic [3:0] wea_ff;
    logic [3:0] web_ff;
    addr_t [3:0] swapped_addra_ff [2:0];
    addr_t [3:0] swapped_addrb_ff [2:0];
    logic [3:0] [WIDTH-1:0] swapped_douta_ff;
    logic [3:0] [WIDTH-1:0] swapped_doutb_ff;
    logic [3:0] [WIDTH-1:0] swapped_douta;
    logic [3:0] [WIDTH-1:0] swapped_doutb;

    genvar n;
    generate;
        for (n = 0; n < 4; n++) begin
            case (WIDTH)
                CWIDTH: begin 
                    charge_bram bram (
                    .clka(clk),    // input wire clka
                    .wea(wea_ff[n]),      // input wire [0 : 0] wea
                    .addra(true_addra[n]),  // input wire [9 : 0] addra
                    .dina(swapped_dina[n]),    // input wire [23 : 0] dina
                    .douta(swapped_douta[n]),
                    .clkb(clk),    // input wire clkb
                    .web(web_ff[n]),      // input wire [0 : 0] web
                    .addrb(true_addrb[n]),  // input wire [9 : 0] addrb
                    .dinb(swapped_dinb[n]),    // input wire [23 : 0] dinb
                    .doutb(swapped_doutb[n])  // output wire [23 : 0] doutb
                    );
                end
                PHIWIDTH: begin
                    phi_bram bram (
                    .clka(clk),    // input wire clka
                    .wea(wea_ff[n]),      // input wire [0 : 0] wea
                    .addra(true_addra[n]),  // input wire [9 : 0] addra
                    .dina(swapped_dina[n]),    // input wire [23 : 0] dina
                    .douta(swapped_douta[n]),
                    .clkb(clk),    // input wire clkb
                    .web(web_ff[n]),      // input wire [0 : 0] web
                    .addrb(true_addrb[n]),  // input wire [9 : 0] addrb
                    .dinb(swapped_dinb[n]),    // input wire [23 : 0] dinb
                    .doutb(swapped_doutb[n])  // output wire [23 : 0] doutb 
                    );
                end
                BWIDTH: begin
                    bmag_bram bram (
                    .clka(clk),    // input wire clka
                    .wea(wea_ff[n]),      // input wire [0 : 0] wea
                    .addra(true_addra[n]),  // input wire [9 : 0] addra
                    .dina(swapped_dina[n]),    // input wire [23 : 0] dina
                    .douta(swapped_douta[n]),
                    .clkb(clk),    // input wire clkb
                    .web(web_ff[n]),      // input wire [0 : 0] web
                    .addrb(true_addrb[n]),  // input wire [9 : 0] addrb
                    .dinb(swapped_dinb[n]),    // input wire [23 : 0] dinb
                    .doutb(swapped_doutb[n])  // output wire [23 : 0] doutb 
                    );
                end
                default: begin 
                    assign swapped_douta[n] = 24'hdead;
                    assign swapped_doutb[n] = 24'hdead;
                end
            endcase
        end
    endgenerate

    function logic [GRID_ADDRWIDTH-3:0] getTrueAddr(input addr_t addr);
        return {addr.y[PINT-1:1], addr.x[PINT-1:1]};
    endfunction

    always_comb begin
        for (int i = 0; i < 4; i++) begin
            sela[i] = {addra[i].y[0], addra[i].x[0]};
            selb[i] = {addrb[i].y[0], addrb[i].x[0]};
        end
    end

    always @(posedge clk) begin
        if (rst) begin
            for (int i = 0; i < 4; i++) begin
                for (int j = 0; j < NUM_CELLS/4; j++) begin
                    reset_bank[i][j] <= NO_RST ? 1'b0 : 1'b1;
                end
                true_addra[i] <= '0;
                true_addrb[i] <= '0;
                swapped_dina[i] <= '0;
                swapped_dinb[i] <= '0;
                wea_ff[i] <= 1'b0;
                web_ff[i] <= 1'b0;
                swapped_addra_ff <= '{default:'0};
                swapped_addrb_ff <= '{default:'0};
                sela_ff[0][i] <= '0;
                selb_ff[0][i] <= '0;
                sela_ff[1][i] <= '0;
                selb_ff[1][i] <= '0;
                do_reseta[0][i] <= '0;
                do_reseta[1][i] <= '0;
                do_resetb[0][i] <= '0;
                do_resetb[1][i] <= '0;
                douta[i] <= '0;
                doutb[i] <= '0;
            end
        end else begin
            for (int i = 0; i < 4; i++) begin
                //stage 1
                true_addra[sela[i]] <= getTrueAddr(addra[i]); //{addra[GRID_ADDRWIDTH-:PINT+1] + i[1], addra[PINT-1:1] + i[0]};
                swapped_addra_ff[0][sela[i]] <= addra[i];
                swapped_dina[sela[i]] <= dina[i];
                wea_ff[sela[i]] <= wea[i];
                true_addrb[selb[i]] <= getTrueAddr(addrb[i]);
                swapped_addrb_ff[0][selb[i]] <= addrb[i];
                swapped_dinb[selb[i]] <= dinb[i];
                web_ff[selb[i]] <= web[i];
                sela_ff[0][i] <= sela[i];
                selb_ff[0][i] <= selb[i];

               //stage 2
               //while r/w is occuring, check reset logic
                if (wea_ff[i]) begin
                    reset_bank[i][true_addra[i]] <= '0;
                    do_reseta[0][i] <='0;
                end else begin
                    do_reseta[0][i] <= reset_bank[i][true_addra[i]];
                end

                if (web_ff[i]) begin
                    reset_bank[i][true_addrb[i]] <= '0;
                    do_resetb[0][i] <= '0;
                end else begin
                    do_resetb[0][i] <= reset_bank[i][true_addrb[i]];
                end

                swapped_addra_ff[1][i] <= swapped_addra_ff[0][i];
                swapped_addrb_ff[1][i] <= swapped_addrb_ff[0][i];
                sela_ff[1][i] <= sela_ff[0][i];
                selb_ff[1][i] <= selb_ff[0][i];

                //stage 3
                //we have to clock the output of the brams immediately to avoid timing violations
                swapped_douta_ff[i] <= swapped_douta[i];
                swapped_doutb_ff[i] <= swapped_doutb[i];
                sela_ff[2][i] <= sela_ff[1][i];
                selb_ff[2][i] <= selb_ff[1][i];
                swapped_addra_ff[2][i] <= swapped_addra_ff[1][i];
                swapped_addrb_ff[2][i] <= swapped_addrb_ff[1][i];
                do_reseta[1][i] <= do_reseta[0][i];
                do_resetb[1][i] <= do_resetb[0][i];

                //stage 4
                //reroute read data to correct outputs, check reset logic
                if (swap_rout) begin
                    douta[i] <= do_reseta[1][sela_ff[2][i]] ? '0 : swapped_douta_ff[sela_ff[2][i]];
                    doutb[i] <= do_resetb[1][selb_ff[2][i]] ? '0 : swapped_doutb_ff[selb_ff[2][i]];
                end else begin
                    douta[i] <= do_reseta[i] ? '0 : swapped_douta_ff[i];
                    doutb[i] <= do_resetb[i] ? '0 : swapped_doutb_ff[i];
                end

                swapped_addra[i] <= swapped_addra_ff[2][i];
                swapped_addrb[i] <= swapped_addrb_ff[2][i];

            end
        end
    end
endmodule