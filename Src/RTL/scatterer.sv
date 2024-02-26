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
    //from pusher
    input logic valid_scatter,
    input particle_t particle_in,
    input bmag_t [3:0] bmag_in,
    output addr_t [3:0] bmag_raddr,
    output logic done, //asserted when all particles have been scattered
    //from solver
    input logic valid_req,
    input addr_t [3:0] grid_addr_in [1:0],
    output charge_t [3:0] charge_out [1:0]
    );

    logic rst_ff;
    //signals for scatter step
    posvec_t pos;
    addr_t [3:0] grid_addr;
    bmag_t [3:0] bmag_out;
    particle_t user_out;
    particle_t particle_ff;
    logic [BWIDTH+PFRAC*2-1:0] total_bmag;
    bmag_t bmag_ff;
    logic [31:0] divider_out;
    pos_t gyroradius_ff;
    particle_t div_user_out;
    posvec_t gyrocenter_ff;
    pos_t [3:0] gyropoints_y;
    pos_t [3:0] gyropoints_x;
    charge_t [3:0] stored_charge [3:0];
    addr_t [3:0] swapped_addr [3:0];
    addr_t [3:0] waddr [3:0];
    charge_t [3:0] new_charge [3:0];
    addr_t [3:0] raddr [3:0];
    //signals for solve step
    addr_t [3:0] requested_addra;
    addr_t [3:0] requested_addrb;
    charge_t [3:0] charge_outa [3:0];
    charge_t [3:0] charge_outb [3:0];
    //overflow is possible here
    charge_t [3:0] half_chargea [1:0];
    charge_t [3:0] half_chargeb [1:0];
    
    //true signals being passed to ports
    addr_t [3:0] addra [3:0];
    addr_t [3:0] addrb [3:0];
    charge_t [3:0] douta [3:0];
    charge_t [3:0] doutb [3:0];
    logic [13:0] cnt;
    logic done_ff [9:0];

    //valids
    logic valid_interpolated;
    logic valid_partials;
    logic valid_halfpartials;
    logic valid_bmag;
    logic valid_div;
    logic valid_gyroradius;
    logic valid_gyropoint;
    
    logic valid_addrs;
    logic valid_mem [3:0];
    logic valid_charge_out;
    logic valid_halfcharges;
    logic valid_accum [7:0];


    assign pos = {particle_in.pos.y, particle_in.pos.x};
    interpolator #(.DWIDTH(BWIDTH), .UWIDTH(PSIZE)) bmag_interpolate (
        .clk(clk),
        .rst(rst),
        .valid(valid_scatter),
        .pos(pos),
        .user_in(particle_in),
        .interpolated_data_out(total_bmag),
        .user_out(user_out),
        .data_in(bmag_in),
        .valid_out(valid_interpolated),
        .raddr_out(bmag_raddr)
    );
    
    gyroradius_div divider (
        .aclk(clk),                                      // input wire aclk
        .s_axis_divisor_tvalid(valid_bmag),    // input wire s_axis_divisor_tvalid
        .s_axis_divisor_tdata(bmag_ff),      // input wire [15 : 0] s_axis_divisor_tdata
        .s_axis_dividend_tvalid(valid_bmag),  // input wire s_axis_dividend_tvalid
        .s_axis_dividend_tuser(particle_ff),    // input wire [11 : 0] s_axis_dividend_tuser
        .s_axis_dividend_tdata(particle_ff.vperp),    // input wire [15 : 0] s_axis_dividend_tdata
        .m_axis_dout_tvalid(valid_div),          // output wire m_axis_dout_tvalid
        .m_axis_dout_tuser(div_user_out),
        .m_axis_dout_tdata(divider_out)            // output wire [23 : 0] m_axis_dout_tdata
    );

    
    generate
        for (genvar i = 0; i < 4; i++) begin
            assign addra[i] = valid_addrs ? requested_addra : raddr[i];
            assign addrb[i] = valid_addrs ? requested_addrb : waddr[i];
            assign stored_charge[i] = douta[i];
            accumulator accum (
                .clk(clk),
                .rst(rst),
                .valid_in(valid_gyropoint),
                .gyropoint({gyropoints_y[i], gyropoints_x[i]}),
                .charge_in(stored_charge[i]),
                .swapped_addr_in(swapped_addr[i]),
                .waddr_out(waddr[i]),
                .charge_out(new_charge[i]),
                .raddr_out(raddr[i])
            );

            //bram instantiation
            grid_mem #(.WIDTH(CWIDTH)) charge_grid (
                .clk(clk),
                .rst(rst),
                .swap_rout(valid_addrs),
                .wea(4'b0),
                .web(valid_addrs ? 4'h0 : 4'hf),
                .addra(addra[i]),
                .addrb(addrb[i]),
                .dina('0),
                .dinb(new_charge[i]),
                .douta(douta[i]),
                .doutb(doutb[i]),
                .swapped_addra(swapped_addr[i]),
                .swapped_addrb()
            );
        end
    endgenerate;

    assign done = done_ff[9];
    always_ff @(posedge clk) begin
        rst_ff <= rst;
        if (rst_ff) begin
            for (int i = 0; i < 4; i++) begin
                gyropoints_y[i] <= '0;
                gyropoints_x[i] <= '0;
            end
            bmag_ff <= '0;
            particle_ff <= '0;
            gyroradius_ff <= '0;
            gyrocenter_ff <= '0;
            cnt <= '0;
            //reset valids
            valid_partials <= 1'b0;
            valid_halfpartials <= 1'b0;
            valid_bmag <= 1'b0;
            valid_gyroradius <= 1'b0;
            valid_gyropoint <= 1'b0;
            for (int i = 0; i < 8; i++) begin
                valid_accum[i] <= 1'b0;
            end
            done_ff <= '{default:'0};
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
            //interpolation is performed by interpolator module
            if (valid_interpolated) begin
                bmag_ff <= total_bmag[BWIDTH+PFRAC*2-1-:BWIDTH];
                particle_ff <= user_out;
                valid_bmag <= 1'b1;
            end else begin
                valid_bmag <= 1'b0;
            end

            //here, the division is performed to get the gyroradius
            
            if (valid_div) begin
                gyroradius_ff <= divider_out[PWIDTH-1:0];
                gyrocenter_ff <= div_user_out.pos;
                valid_gyroradius <= 1'b1;
            end else begin
                valid_gyroradius <= 1'b0;
            end

            if (valid_gyroradius) begin
                for (int i = 0; i < 4; i++) begin
                    //note that this can wrap, and this behaviour is desired to enforce periodic boundary condition
                    //this is why the y and x components of the gyropoint are treated separately
                    gyropoints_y[i] <= gyrocenter_ff.y + (i[1] ? (i[0] ? gyroradius_ff : -gyroradius_ff) : 1'b0);
                    gyropoints_x[i] <= gyrocenter_ff.x + (i[1] ? 1'b0 : (i[0] ? gyroradius_ff : -gyroradius_ff));
                    cnt <= cnt + 1;
                end
                valid_gyropoint <= 1'b1;
            end else begin
                valid_gyropoint <= 1'b0;
            end

            done_ff[0] <= cnt == NUM_PARTICLES - 1;
            done_ff[1] <= done_ff[0];
            done_ff[2] <= done_ff[1];
            done_ff[3] <= done_ff[2];
            done_ff[4] <= done_ff[3];
            done_ff[5] <= done_ff[4];
            done_ff[6] <= done_ff[5];
            done_ff[7] <= done_ff[6];
            done_ff[8] <= done_ff[7];
            done_ff[9] <= done_ff[8];

            if (valid_req) begin
                requested_addra <= grid_addr_in[0];
                requested_addrb <= grid_addr_in[1];
                valid_addrs <= 1'b1;
            end else begin
                valid_addrs <= 1'b0;
            end

            //wait four cycles
            valid_mem[0] <= valid_addrs;
            valid_mem[1] <= valid_mem[0];
            valid_mem[2] <= valid_mem[1];
            valid_mem[3] <= valid_mem[2];

            if (valid_mem[3]) begin
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
    end
endmodule