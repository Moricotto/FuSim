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

module grid_mem
    #(parameter WIDTH = 36, parameter UWIDTH = 0, parameter SWAP_RIN = 1, parameter SWAP_WIN = 1, parameter SWAP_UIN = 1, parameter SWAP_UOUT = 1, parameter NO_RST = 0) (
    input logic clk,
    input logic rst,
    input logic swap_rout,
    input logic [3:0] wea,
    input logic [3:0] web,
    input logic [GRID_ADDRWIDTH-1:0] addra,
    input logic [GRID_ADDRWIDTH-1:0] addrb,
    input logic [3:0] [WIDTH-1:0] dina,
    input logic [3:0] [WIDTH-1:0] dinb,
    input logic [3:0] [UWIDTH-1:0] uina,
    input logic [3:0] [UWIDTH-1:0] uinb,
    output logic [3:0] [WIDTH-1:0] douta,
    output logic [3:0] [WIDTH-1:0] doutb,
    output logic [3:0] [UWIDTH-1:0] uouta,
    output logic [3:0] [UWIDTH-1:0] uoutb
    );

    //corresponds to PHYSICAL brams, that is, after all remappings have been applied
    logic [3:0] [NUM_CELLS/4-1:0] reset_bank;

    logic [3:0] [GRID_ADDRWIDTH-3:0] true_addra;
    logic [3:0] [GRID_ADDRWIDTH-3:0] true_addrb;
    logic [3:0] [1:0] sela;
    logic [3:0] [1:0] selb;
    logic [3:0] [1:0] sela_ff [1:0];
    logic [3:0] [1:0] selb_ff [1:0];
    logic [3:0] do_reseta;
    logic [3:0] do_resetb;
    logic [3:0] [WIDTH-1:0] swapped_dina;
    logic [3:0] [WIDTH-1:0] swapped_dinb;
    logic [3:0] [UWIDTH-1:0] swapped_uina;
    logic [3:0] [UWIDTH-1:0] swapped_uinb;
    logic [3:0] wea_ff;
    logic [3:0] web_ff;
    logic [3:0] [UWIDTH-1:0] swapped_uina_ff;
    logic [3:0] [UWIDTH-1:0] swapped_uinb_ff;
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
                    .addra(true_addra[n]),  // input wire [11 : 0] addra
                    .douta(swapped_douta[n]),  // output wire [13 : 0] douta
                    .clkb(clk),    // input wire clkb
                    .addrb(true_addrb[n]),  // input wire [11 : 0] addrb
                    .doutb(swapped_doutb[n])  // output wire [13 : 0] doutb
                    );
                end
                default: begin 
                    assign swapped_douta[n] = 24'hdead;
                    assign swapped_doutb[n] = 24'hdead;
                end
            endcase
        end
    endgenerate

    function logic [GRID_ADDRWIDTH-3:0] getTrueAddr(input logic [GRID_ADDRWIDTH-1:0] addr);
        return {addr[GRID_ADDRWIDTH-1:GRID_ADDRWIDTH-PINT+1], addr[PINT-1:1]};
    endfunction

    always_comb begin
        for (int i = 0; i < 4; i++) begin
            sela[i] = {i[1] ^ addra[PINT], i[0] ^ addra[0]};
            selb[i] = {i[1] ^ addrb[PINT], i[0] ^ addrb[0]};
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
                swapped_uina[i] <= '0;
                swapped_uinb[i] <= '0;
                wea_ff[i] <= 1'b0;
                web_ff[i] <= 1'b0;
                sela_ff[0][i] <= '0;
                selb_ff[0][i] <= '0;
                sela_ff[1][i] <= '0;
                selb_ff[1][i] <= '0;
                swapped_uina_ff[i] <= '0;
                swapped_uinb_ff[i] <= '0;
                do_reseta[i] <= '0;
                do_resetb[i] <= '0;
                douta[i] <= '0;
                doutb[i] <= '0;
                uouta[i] <= '0;
                uoutb[i] <= '0;
            end
        end else begin
            for (int i = 0; i < 4; i++) begin
                //stage 1
                if (wea[i]) begin
                    if (SWAP_WIN) begin
                        true_addra[sela[i]] <= getTrueAddr(addra + i[0] + (i[1] << PINT)); //{addra[GRID_ADDRWIDTH-:PINT+1] + i[1], addra[PINT-1:1] + i[0]};
                        swapped_dina[sela[i]] <= dina[i];
                        wea_ff[sela[i]] <= 1'b1;
                    end else begin
                        true_addra[i] <= getTrueAddr(addra + i[0] + (i[1] << PINT));
                        swapped_dina[i] <= dina[i];
                        wea_ff[i] <= 1'b1;
                    end
                end else begin
                    if (SWAP_WIN) begin
                        wea_ff[sela[i]] <= 1'b0;
                    end else begin
                        wea_ff[i] <= 1'b0;
                    end
                    if (SWAP_RIN) begin
                        true_addra[sela[i]] <= getTrueAddr(addra + i[0] + (i[1] << PINT));
                    end else begin
                        true_addra[i] <= getTrueAddr(addra + i[0] + (i[1] << PINT));
                    end
                end

                if (web[i]) begin
                    if (SWAP_WIN) begin
                        true_addrb[selb[i]] <= getTrueAddr(addrb + i[0] + (i[1] << PINT));
                        swapped_dinb[selb[i]] <= dinb[i];
                        web_ff[selb[i]] <= 1'b1;
                    end else begin
                        true_addrb[i] <= getTrueAddr(addrb + i[0] + (i[1] << PINT));
                        swapped_dinb[i] <= dinb[i];
                        web_ff[i] <= 1'b1;
                    end
                end else begin
                    if (SWAP_WIN) begin
                        web_ff[selb[i]] <= 1'b0;
                    end else begin
                        web_ff[i] <= 1'b0;
                    end
                    if (SWAP_RIN) begin
                        true_addrb[selb[i]] <= getTrueAddr(addrb + i[0] + (i[1] << PINT));
                    end else begin
                        true_addrb[i] <= getTrueAddr(addrb + i[0] + (i[1] << PINT));
                    end
                end

                if (SWAP_UIN) begin    
                    swapped_uina[sela[i]] <= uina[i];
                    swapped_uinb[selb[i]] <= uinb[i];
                end else begin
                    swapped_uina[i] <= uina[i];
                    swapped_uinb[i] <= uinb[i];
                end

                sela_ff[0][i] <= sela[i];
                selb_ff[0][i] <= selb[i];

               //stage 2
               //while r/w is occuring, check reset logic
                if (wea_ff[i]) begin
                    reset_bank[i][true_addra[i]] <= '0;
                    do_reseta[i] <='0;
                end else begin
                    do_reseta[i] <= reset_bank[i][true_addra[i]];
                end

                if (web_ff[i]) begin
                    reset_bank[i][true_addrb[i]] <= '0;
                    do_resetb[i] <= '0;   
                end else begin
                    do_resetb[i] <= reset_bank[i][true_addrb[i]];
                end
                swapped_uina_ff[i] <= swapped_uina[i];
                swapped_uinb_ff[i] <= swapped_uinb[i];
                sela_ff[1][i] <= sela_ff[0][i];
                selb_ff[1][i] <= selb_ff[0][i];

                //stage 3
                //reroute read data to correct outputs, check reset logic
                if (swap_rout) begin
                    douta[i] <= do_reseta[sela_ff[1][i]] ? '0 : swapped_douta[sela_ff[1][i]];
                    doutb[i] <= do_resetb[selb_ff[1][i]] ? '0 : swapped_doutb[selb_ff[1][i]];
                end else begin
                    douta[i] <= do_reseta[i] ? '0 : swapped_douta[i];
                    doutb[i] <= do_resetb[i] ? '0 : swapped_doutb[i];
                end

                if (SWAP_UOUT) begin
                    uouta[i] <= swapped_uina_ff[selb_ff[1][i]];
                    uoutb[i] <= swapped_uinb_ff[sela_ff[1][i]];
                end else begin
                    uouta[i] <= swapped_uina_ff[i];
                    uoutb[i] <= swapped_uinb_ff[i];
                end
            end
        end
    end
endmodule
