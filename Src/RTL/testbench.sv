`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 09/24/2023 10:49:42 AM
// Design Name: 
// Module Name: testbench
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



module testbench();
    import defs::*;

    logic clk_p;
    logic clk_n;
    logic rst;
    logic rxd_i;
    logic txd_o;
    //dut
    plasma_sim dut (
        .sys_clk_p(clk_p),
        .sys_clk_n(clk_n),
        .usr_rst(rst),
        .rxd_i(rxd_i),
        .txd_o(txd_o),
        .data_out(),
        .led()
    );

    tb_uart_driver driver (
        .data_out(rxd_i)
    );

    logic [7:0] char;
    logic char_val;
    tb_uart_monitor monitor (
        .data_in(txd_o),
        .char(char),
        .char_val(char_val)
    );

    logic [8*15-1:0] particle0_write = "*p4000200002000";
    logic [8*15-1:0] particle1_write = "*p2000100002800";
    logic [8*9-1:0] bmag_write = "*m000ffff";
    logic [8*10-1:0] go = "*g00000004";
    logic [8*6-1:0] charge_read = "*c202";
    logic [8*6-1:0] phi_read = "*e202";
    defparam dut.uart_ctl.BAUD_RATE = 9_600;  //6_250_000
    initial begin
        $display("Starting testbench");
        clk_p <= 1'b0;
        rst <= 1'b0;
        #600;
        $display("Sending first message");
        for (int i = 14; i >= 0; i--) begin
            driver.send_char(particle0_write[i*8+:8]);
        end
        for (int i = 14; i >= 0; i--) begin
            driver.send_char(particle1_write[i*8+:8]);
        end
        for (int i = 8; i >= 0; i--) begin
            driver.send_char(bmag_write[i*8+:8]);
        end
        for (int i = 9; i >= 0; i--) begin
            driver.send_char(go[i*8+:8]);
        end
        #5000ns
        for (int i = 5; i >= 0; i--) begin
            driver.send_char(charge_read[i*8+:8]);
        end
        #50ns
        for (int i = 5; i >= 0; i--) begin
            driver.send_char(phi_read[i*8+:8]);
        end
    end
    assign clk_n = ~clk_p;
    always begin
        #2.5ns;
        clk_p <= ~clk_p;
    end

endmodule