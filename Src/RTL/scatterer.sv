`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// Create Date: 09/30/2023 07:07:12 PM
// Design Name: 
// Module Name: scatterer
// Project Name: plasma_sim 
// Target Devices: Kintex-7 FPGA KC705 Evaluation Kit
// Tool Versions: 
// Description: Takes as input a particle and outputs the scatter vector for the four adjacent grid points
// it does one gyroaveraging point per clock cycle, for a total of four per particle
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

import defs::*;

module scatterer (
    input logic clk,
    input logic rst,
    input step_t step,
    //for use during scatter step
    input logic valid_scatter,
    input logic tlast_in,
    input particle_t particle_in,
    output logic tlast_out,
    //for use during solve step
    input logic valid_req,
    input logic [GRID_ADDRWIDTH-1:0] grid_addr_in [1:0],
    output logic [3:0] [CWIDTH-1:0] charge_out [1:0]
    );

    //signals for scatter step
    logic tlast [10:0];
    pos_t pos;
    logic [GRID_ADDRWIDTH-1:0] grid_addr;
    logic [3:0] [BWIDTH-1:0] dummy_wdata;
    logic [3:0] [BWIDTH-1:0] bmag_out;
    logic [PSIZE:0] user_out;
    particle_t gyroaverage_info_ff;
    logic [BWIDTH+PFRAC*2+1:0] total_bmag;
    logic [BWIDTH+1:0] bmag_ff;
    logic [31:0] divider_out;
    logic [PWIDTH-1:0] gyroradius_ff;
    logic [PSIZE:0] div_user_out;
    logic [PWIDTH*2-1:0] gyrocenter_ff;
    logic [3:0] [PWIDTH-1:0] gyropoints_y;
    logic [3:0] [PWIDTH-1:0] gyropoints_x;
    logic [3:0] [CWIDTH-1:0] stored_charge [3:0];
    logic [3:0] [GRID_ADDRWIDTH-1:0] swapped_addr [3:0];
    logic [GRID_ADDRWIDTH-1:0] waddr [3:0];
    logic [3:0] [CWIDTH-1:0] new_charge [3:0];
    logic [GRID_ADDRWIDTH-1:0] raddr [3:0];
    logic [3:0] [GRID_ADDRWIDTH-1:0] unswapped_addr [3:0];
    //signals for solve step
    logic [GRID_ADDRWIDTH-1:0] requested_addra;
    logic [GRID_ADDRWIDTH-1:0] requested_addrb;
    logic [3:0] [CWIDTH-1:0] charge_outa [3:0];
    logic [3:0] [CWIDTH-1:0] charge_outb [3:0];
    //overflow is possible here
    logic [3:0] [CWIDTH-1:0] half_chargea [1:0];
    logic [3:0] [CWIDTH-1:0] half_chargeb [1:0];
    
    //true signals being passed to ports
    logic [GRID_ADDRWIDTH-1:0] addra [3:0];
    logic [GRID_ADDRWIDTH-1:0] addrb [3:0];
    logic [3:0] [CWIDTH-1:0] douta [3:0];
    logic [3:0] [CWIDTH-1:0] doutb [3:0];

    //valids
    logic valid_interpolated;
    logic valid_partials;
    logic valid_halfpartials;
    logic valid_bmag;
    logic valid_div;
    logic valid_gyroradius;
    logic valid_gyropoint;
    
    logic valid_addrs;
    logic valid_mem [2:0];
    logic valid_charge_out;
    logic valid_halfcharges;
    logic valid_accum [7:0];


    assign pos = {particle_in.y, particle_in.x};
    interpolator #(.DWIDTH(BWIDTH), .UWIDTH(PSIZE + 1)) bmag_interpolate (
        .clk(clk),
        .rst(rst),
        .valid(valid_scatter),
        .zero(1'b0),
        .pos(pos),
        .data_in(bmag_out),
        .user_in({tlast_in, particle_in}),
        .raddr_out(grid_addr),
        .valid_out(valid_interpolated),
        .interpolated_data_out(total_bmag),
        .user_out(user_out)
    );
    
    //ROMs containing bmag at every gridpoints
    grid_mem #(.WIDTH(BWIDTH), .NO_RST(1)) bmag_grid (
        .clk(clk),
        .rst(rst),
        .wea(4'b0),
        .web(4'b0),
        .addra(grid_addr),
        .addrb('0),
        .dina('0),
        .dinb('0),
        .uina('0),
        .uinb('0),
        .douta(bmag_out),
        .doutb(),
        .uouta(),
        .uoutb()
    );
    
    gyroradius_div divider (
        .aclk(clk),                                      // input wire aclk
        .s_axis_divisor_tvalid(valid_bmag),    // input wire s_axis_divisor_tvalid
        .s_axis_divisor_tuser(tlast[0]),
        .s_axis_divisor_tdata(bmag_ff),      // input wire [15 : 0] s_axis_divisor_tdata
        .s_axis_dividend_tvalid(valid_bmag),  // input wire s_axis_dividend_tvalid
        .s_axis_dividend_tuser(gyroaverage_info_ff),    // input wire [11 : 0] s_axis_dividend_tuser
        .s_axis_dividend_tdata(gyroaverage_info_ff.vperp),    // input wire [15 : 0] s_axis_dividend_tdata
        .m_axis_dout_tvalid(valid_div),          // output wire m_axis_dout_tvalid
        .m_axis_dout_tuser(div_user_out),
        .m_axis_dout_tdata(divider_out)            // output wire [23 : 0] m_axis_dout_tdata
    );

    
    generate;
        for (genvar i = 0; i < 4; i++) begin
            assign addra[i] = (step == SOLVE) ? requested_addra : raddr[i];
            assign addrb[i] = (step == SOLVE) ? requested_addrb : waddr[i];
            assign stored_charge[i] = douta[i];
            accumulator accum (
                .clk(clk),
                .rst(rst),
                .valid_in(valid_gyropoint),
                .gyropoint_y(gyropoints_y[i]),
                .gyropoint_x(gyropoints_x[i]),
                .charge_in(stored_charge[i]),
                .uin(swapped_addr[i]),
                .waddr_out(waddr[i]),
                .charge_out(new_charge[i]),
                .raddr_out(raddr[i]),
                .uout(unswapped_addr[i])

            );

            //bram instantiation
            grid_mem #(.WIDTH(CWIDTH), .UWIDTH(GRID_ADDRWIDTH), .SWAP_WIN(0), .SWAP_UOUT(0)) charge_grid (
                .clk(clk),
                .rst(rst),
                .swap_rout(step == SOLVE),
                .wea(4'b0),
                .web((step == SCATTER) ? 4'hf : 4'h0),
                .addra(addra[i]),
                .addrb(addrb[i]),
                .dina('0),
                .dinb(new_charge[i]),
                .uina(unswapped_addr[i]),
                .uinb('0),
                .douta(douta[i]),
                .doutb(doutb[i]),
                .uouta(swapped_addr[i]),
                .uoutb()
            );
        end
    endgenerate;

    always_ff @(posedge clk) begin
        if (rst) begin
            for (int i = 0 ; i <= 10; i++) begin
                tlast[i] <= '0;
            end
            tlast_out <= '0;
            for (int i = 0; i < 4; i++) begin
                dummy_wdata[i] <= '0;
                gyropoints_y[i] <= '0;
                gyropoints_x[i] <= '0;
            end
            bmag_ff <= '0;
            gyroaverage_info_ff <= '0;
            gyroradius_ff <= '0;
            gyrocenter_ff <= '0;
            //reset valids
            valid_partials <= 1'b0;
            valid_halfpartials <= 1'b0;
            valid_bmag <= 1'b0;
            valid_gyroradius <= 1'b0;
            valid_gyropoint <= 1'b0;
            for (int i = 0; i < 8; i++) begin
                valid_accum[i] <= 1'b0;
            end
            //for solve step
            requested_addra <= '0;
            requested_addrb <= '0;
            for (int i = 0; i < 4; i++) begin
                charge_outa[i] <= '0;
                charge_outb[i] <= '0;
            end
            for (int i = 0; i < 2; i++) begin
                half_chargea[i] <= '0;
                half_chargeb[i] <= '0;
                charge_out[i] <= '0;
            end
            valid_addrs <= 1'b0;
            for (int i = 0; i < 3; i++) begin
                valid_mem[i] <= 1'b0;
            end
            valid_charge_out <= 1'b0;
            valid_halfcharges <= 1'b0;
        end else begin
            case (step)
            SCATTER: begin
                //interpolation is performed by interpolator module
                if (valid_interpolated) begin
                    bmag_ff <= total_bmag[BWIDTH+PFRAC*2+1-:BWIDTH+2];// + BMIN;
                    gyroaverage_info_ff <= user_out[PSIZE-1:0];
                    tlast[0] <= user_out[PSIZE];
                    valid_bmag <= 1'b1;
                end else begin
                    valid_bmag <= 1'b0;
                end
                //here, the division is performed to get the gyroradius
                
                if (valid_div) begin
                    gyroradius_ff <= divider_out[PWIDTH-1:0];
                    gyrocenter_ff <= div_user_out[PSIZE-:PWIDTH*2];
                    tlast[1] <= div_user_out[0];
                    valid_gyroradius <= 1'b1;
                end else begin
                    valid_gyroradius <= 1'b0;
                end

                if (valid_gyroradius) begin
                    for (int i = 0; i < 4; i++) begin
                        gyropoints_y[i] <= gyrocenter_ff[PWIDTH*2-1:PWIDTH] + (i[1] ? (i[0] ? gyroradius_ff : -gyroradius_ff) : 1'b0);
                        gyropoints_x[i] <= gyrocenter_ff[PWIDTH-1:0] + (i[1] ? 1'b0 : (i[0] ? gyroradius_ff : -gyroradius_ff));
                    end
                    tlast[2] <= tlast[1];
                    valid_gyropoint <= 1'b1;
                end else begin
                    valid_gyropoint <= 1'b0;
                end

                //wait another 8 clocks for final charge to be written to accumulators
                if (valid_gyropoint) begin
                    tlast[3] <= tlast[2];
                    valid_accum[0] <= 1'b1;
                end else begin
                    valid_accum[0] <= 1'b0;
                end

                for (int i = 1; i < 8; i++) begin
                    if (valid_accum[i-1]) begin
                        tlast[3+i] <= tlast[2+i];
                        valid_accum[i] <= 1'b1;
                    end else begin
                        valid_accum[i] <= 1'b0;
                    end
                end


                if (valid_accum[7]) begin
                    tlast_out <= tlast[10];
                end else begin
                    tlast_out <= 1'b0;
                end 
            end
            SOLVE: begin
                if (valid_req) begin
                    requested_addra <= grid_addr_in[0];
                    requested_addrb <= grid_addr_in[1];
                    valid_addrs <= 1'b1;
                end else begin
                    valid_addrs <= 1'b0;
                end

                //wait three cycles
                valid_mem[0] <= valid_addrs;
                valid_mem[1] <= valid_mem[0];
                valid_mem[2] <= valid_mem[1];

                if (valid_mem[2]) begin
                    for (int i = 0; i < 4; i++) begin
                        for (int j = 0; j < 4; j++) begin
                            charge_outa[i][j] <= douta[i][j];
                            charge_outb[i][j] <= doutb[i][j];
                        end
                    end
                    valid_charge_out <= 1'b1;
                end else begin
                    valid_charge_out <= 1'b0;
                end

                if (valid_charge_out) begin
                    for (int i = 0; i < 2; i++) begin
                        for (int j = 0; j < 4; j++) begin
                            half_chargea[i][j] <= charge_outa[i][j] + charge_outa[i+2][j];
                            half_chargeb[i][j] <= charge_outb[i][j] + charge_outb[i+2][j];
                        end
                    end
                    valid_halfcharges <= 1'b1;
                end else begin
                    valid_halfcharges <= 1'b0;
                end

                if (valid_halfcharges) begin
                    for (int i = 0; i < 4; i++) begin
                        charge_out[0][i] <= half_chargea[0][i] + half_chargea[1][i];
                        charge_out[1][i] <= half_chargeb[0][i] + half_chargeb[1][i];
                    end 
                end
            end
            endcase
        end
    end
endmodule