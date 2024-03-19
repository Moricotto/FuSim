//-----------------------------------------------------------------------------
//  
//  Project  : SSRM RF Processor
//  Module   : ssu_uart_rx.v
//  Parent   : ss_ui.v
//  Children : ssu_uart_rx_ctl.v ss_uart_baud_gen.v ss_meta_harden.v
//
//  Description: 
//     Top level of the UART receiver.
//     Brings together the metastability hardener for synchronizing the 
//     rxd pin, the baudrate generator for generating the proper x16 bit
//     enable, and the controller for the UART itself.
//     
//
//  Parameters:
//     BAUD_RATE : Baud rate - set to 115,200bps by default
//     CLOCK_RATE: Clock rate - set to 100MHz by default
//
//  Local Parameters:
//
//  Notes       : 
//
//  Multicycle and False Paths
//     The uart_baud_gen module generates a 1-in-N pulse (where N is
//     determined by the baud rate and the system clock frequency), which
//     enables all flip-flops in the uart_rx_ctl module. Therefore, all paths
//     within uart_rx_ctl are multicycle paths, as long as N > 2 (which it
//     will be for all reasonable combinations of Baud rate and system
//     frequency).
//

`timescale 1ns/1ps


module ui_uart_rx (
  // Write side inputs
  input            clk,       // Clock input
  input            rst,   // Active HIGH reset - synchronous to clk

  input            rxd_i,        // RS232 RXD pin - Directly from pad

  output     [7:0] rx_data,      // 8 bit data output
                                 //  - valid when rx_data_rdy is asserted
  output           rx_data_rdy,  // Ready signal for rx_data
  output           frm_err       // The STOP bit was not detected
);


//***************************************************************************
// Parameter definitions
//***************************************************************************

  parameter BAUD_RATE    =     9_600;             // Baud rate
  parameter CLOCK_RATE   = 200_000_000;

//***************************************************************************
// Reg declarations
//***************************************************************************

//***************************************************************************
// Wire declarations
//***************************************************************************

  wire             rxd_clk_sys;   // RXD pin, synchronized to clk

  wire             baud_x16_en;  // 1-in-N enable for uart_rx_ctl FFs
  
//***************************************************************************
// Code
//***************************************************************************

  /* Synchronize the RXD pin to the clk clock domain. Since RXD changes
  * very slowly wrt. the sampling clock, a simple metastability hardener is
  * sufficient */
  ui_meta_harden ui_meta_harden_rxd_i0 (
    .clk_dst      (clk),
    .rst_dst      (rst), 
    .signal_src   (rxd_i),
    .signal_dst   (rxd_clk_sys)
  );

  ui_uart_baud_gen #
  ( .BAUD_RATE  (BAUD_RATE),
    .CLOCK_RATE (CLOCK_RATE)
  ) ss_uart_baud_gen_rx_i0 (
    .clk         (clk),
    .rst         (rst),
    .baud_x16_en (baud_x16_en)
  );

  ui_uart_rx_ctl ui_uart_rx_ctl_i0 (
    .clk         (clk),
    .rst         (rst),
    .baud_x16_en (baud_x16_en),

    .rxd_clk_sys (rxd_clk_sys),
    
    .rx_data_rdy (rx_data_rdy),
    .rx_data     (rx_data),
    .frm_err     (frm_err)
  );

endmodule
