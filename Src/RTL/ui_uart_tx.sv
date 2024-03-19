//-----------------------------------------------------------------------------
//  
//  Project  : SSRM RF Processor
//  Module   : ss_uart_tx.v
//  Parent   : ss_ui.v and ssrm_top.v
//  Children : ss_uart_tx_ctl.v ss_uart_baud_gen.v .v
//
//  Description: 
//     Top level of the UART transmitter.
//     Brings together the baudrate generator and the actual UART transmit
//     controller
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
//     enables all flip-flops in the uart_tx_ctl module. Therefore, all paths
//     within uart_tx_ctl are multicycle paths, as long as N > 2 (which it
//     will be for all reasonable combinations of Baud rate and system
//     frequency).
//

`timescale 1ns/1ps


module ui_uart_tx (
  input        clk,      // Clock input
  input        rst,      // Active HIGH reset - synchronous to clk

  input        tx_data_val,     // Indicates new character ready
  input  [7:0] tx_data,         // Data from the char FIFO
  output       tx_done,         // Pop signal to the char FIFO

  output       txd_o            // The transmit serial signal
);


//***************************************************************************
// Parameter definitions
//***************************************************************************

  parameter BAUD_RATE    =     9_600;              // Baud rate

  parameter CLOCK_RATE   = 200_000_000;

//***************************************************************************
// Reg declarations
//***************************************************************************

//***************************************************************************
// Wire declarations
//***************************************************************************

  wire             baud_x16_en;  // 1-in-N enable for uart_rx_ctl FFs
  
//***************************************************************************
// Code
//***************************************************************************

  ui_uart_baud_gen #
  ( .BAUD_RATE  (BAUD_RATE),
    .CLOCK_RATE (CLOCK_RATE)
  ) ss_uart_baud_gen_tx_i0 (
    .clk         (clk),
    .rst         (rst),
    .baud_x16_en (baud_x16_en)
  );

  ui_uart_tx_ctl ui_uart_tx_ctl_i0 (
    .clk	        (clk),         // Clock input
    .rst	        (rst),         // Active HIGH reset

    .baud_x16_en        (baud_x16_en), // 16x oversample enable

    .tx_data_val	(tx_data_val), // New character available
    .tx_data	        (tx_data),     // Data from the char FIFO
    .tx_done	        (tx_done),     // Pop signal to the char FIFO 
    .txd_o	        (txd_o)        // The transmit serial signal
  );

endmodule
