//-----------------------------------------------------------------------------
//  
//  Copyright (c) 2011 Beel
//
//  Project  : SSRM RF Processort
//  Module   : ss_ui.v
//  Parent   : ssrm_top.v
//  Children : ss_uart_rx, ss_cmd_parse, ss_resp_gen
//
//  Description: 
//     This module is the top level of the user interface. It receives/drives
//     the RS232 signals directly, parses the commands, and generates the
//     responses. 
//     
//     It generates a "standard" register interface to the registers, counters
//     and other register sources (the Mode-S processor), and also interacts
//     with the SPI interface
//
//  Parameters:
//     CLOCK_RATE, BAUD_RATE
//
//  Local Parameters:
//
//  Notes       : 
//
//  Multicycle and False Paths
//     None
//

`timescale 1ns/1ps


module ui_ui (
  input             clk,            // Clock input
  input             rst,            // Active HIGH reset - synchronous to clk_rx

  input             rxd_i,          // RS232 input
  output            txd_o,          // RS232 output

  
  output reg [7:0] saved_rx_data, // The last received character
  
  // to particle FIFO
  output             ui_particle_wr, // Write strobe
  output [PSIZE-1:0] ui_particle_wdata,   // Particle data

  //to magnetic field memory
  output              ui_mag_wr, // Write strobe
  output [ADDRWIDTH-1:0] ui_mag_addr, // Address  
  output [BWIDTH-1:0] ui_mag_wdata, // Write data

  //to/from charge memory
  output                 ui_chrg_rd, // Read strobe
  output [ADDRWIDTH-1:0] ui_chrg_addr, // Address
  input                  ui_chrg_rdy, // Command complete
  input [CWIDTH-1:0]     ui_chrg_rdata, // Read data

  //to/from electrostatic potential field memory
  output                 ui_phi_rd, // Read strobe
  output [ADDRWIDTH-1:0] ui_phi_addr, // Address
  input                  ui_phi_rdy, // Command complete
  input [PHIWIDTH-1:0]   ui_phi_rdata, // Read data

  //to cnt register
  output        ui_go_wr, // Write strobe (go)
  output [31:0] ui_go_wdata // Write data (#timesteps) 
);


//***************************************************************************
// Parameter definitions
//***************************************************************************

  parameter 
    BAUD_RATE  =     500_000,
    CLOCK_RATE = 200_000_000;

//***************************************************************************
// Reg declarations
//***************************************************************************


//***************************************************************************
// Wire declarations
//***************************************************************************

  //********** From ui_uart_rx
  wire [7:0]  rx_data;
  wire        rx_data_val;

  //********** From ui_cmd_parse
  wire        send_char_val;  // A character is ready to be sent
  wire [7:0]  send_char;      // Character to be sent

  wire        send_resp_val;  // A response is requested
  wire [1:0]  send_resp_type; // Type of response - see localparams

  //********** From ssu_send_resp
  wire        send_resp_done; // Response generator is done
  wire [7:0]  char_fifo_din;  // Character to push to FIFO
  wire        char_fifo_wr_en; // Push

  //********** From ui_char_fifo
  wire [7:0]  char_fifo_dout;
  wire        char_fifo_full; 
  wire        char_fifo_empty;

  //********** From ui_char_seq
  wire        char_fifo_rd_en;
  wire        tx_data_val;
  wire [7:0]  tx_data;

  //********** From ui_uart_tx
  wire        tx_done;

//***************************************************************************
// Tasks and Functions
//***************************************************************************


//***************************************************************************
// Code
//***************************************************************************

  // Instantiate UART receiver
  ui_uart_rx #(
    .BAUD_RATE    (BAUD_RATE),
    .CLOCK_RATE   (CLOCK_RATE)
  ) ui_uart_rx_i0 (
    .clk          (clk),
    .rst          (rst),
    
    .rxd_i        (rxd_i),
    
    .rx_data      (rx_data),
    .rx_data_rdy  (rx_data_rdy),
    .frm_err      ()   // Not used
  );

  always @(posedge clk) begin
    if (rst) begin
      saved_rx_data <= 8'h00;
    end else if (rx_data_rdy) begin
      saved_rx_data <= rx_data;
    end
  end

  // Instantiate Command Parser
  ui_cmd_parse ui_cmd_parse_i0 (
    .clk	     (clk),         // Clock input
    .rst	     (rst),         // Active HIGH reset - synchronous to clk

    .rx_data	     (rx_data),        // Character to be parsed
    .rx_data_rdy     (rx_data_rdy),    // Ready signal for rx_data

    // From Character FIFO
    .char_fifo_full  (char_fifo_full), // The char_fifo is full

    // To/From Response generator
    .send_char_val   (send_char_val),  // A character is ready to be sent
    .send_char	     (send_char),      // Character to be sent

    .send_resp_val   (send_resp_val),  // A response is requested
    .send_resp_type  (send_resp_type), // Type of response - see localparams

    .send_resp_done  (send_resp_done), // The response generation is complete

    // To particle FIFO
    .ui_particle_wr  (ui_particle_wr), // Write strobe
    .ui_particle_data(ui_particle_wdata), // Particle data

    //to magnetic field memory
    .ui_mag_wr       (ui_mag_wr), // Write strobe
    .ui_mag_addr     (ui_mag_addr), // Address
    .ui_mag_data    (ui_mag_wdata), // Write data

    //to charge memory
    .ui_chrg_rd      (ui_chrg_rd), // Read strobe
    .ui_chrg_addr    (ui_chrg_addr), // Address

    //to electrostatic potential field memory
    .ui_phi_rd       (ui_phi_rd), // Read strobe
    .ui_phi_addr     (ui_phi_addr), // Address

    //to cnt register
    .ui_go_wr        (ui_go_wr), // Read strobe (go)
    .ui_go_data     (ui_go_wdata) // Write data (#timesteps)
  );


  // Instantiate the response generator
  ui_resp_gen ui_resp_gen_i0 (
    .clk	(clk),         // Clock input
    .rst	(rst),     // Active HIGH reset - synchronous to clk

    // From Character FIFO
    .char_fifo_full	(char_fifo_full), // The char_fifo is full

    // To/From the Command Parser
    .send_char_val	(send_char_val),  // A character is ready to be sent
    .send_char	(send_char),      // Character to be sent

    .send_resp_val	(send_resp_val),  // A response is requested
    .send_resp_type	(send_resp_type), // Type of response - see localparams

    //from electostatic potential memory
    .phi_rdy	(ui_phi_rdy), // Ready from PHI
    .phi_rdata	(ui_phi_rdata), // Read data from PHI

    //from charge memory
    .chrg_rdy	(ui_chrg_rdy), // Ready from charge
    .chrg_rdata	(ui_chrg_rdata), // Read data from charge memory

    .send_resp_done	(send_resp_done), // The response generation is complete

    // To character FIFO
    .char_fifo_din	(char_fifo_din),  // Character to push into the FIFO
    .char_fifo_wr_en    (char_fifo_wr_en) // Write enable (push) for the FIFO
  );

  // Instantiate the character FIFO
  ui_char_fifo ui_char_fifo_i0 (
    .clk   (clk), // input clk
    .srst  (rst), // input srst
    .din   (char_fifo_din), // input [7 : 0] din
    .wr_en (char_fifo_wr_en), // input wr_en
    .rd_en (char_fifo_rd_en), // input rd_en
    .dout  (char_fifo_dout), // output [7 : 0] dout
    .full  (char_fifo_full), // output full
    .empty (char_fifo_empty) // output empty
  );
  

  // Instantiate the character sequencer
  ui_char_seq ui_char_seq_i0 (
    .clk	(clk),          // Clock input
    .rst	(rst),          // Active HIGH reset - synchronous to clk

    .char_fifo_empty	(char_fifo_empty),
    .char_fifo_rd_en	(char_fifo_rd_en),
    .char_fifo_dout	(char_fifo_dout),

    .tx_data_val	(tx_data_val),
    .tx_data	        (tx_data),
    .tx_done	        (tx_done)
  );

  // Instantiate the UART transmitter

  ui_uart_tx #(
    .BAUD_RATE    (BAUD_RATE),
    .CLOCK_RATE   (CLOCK_RATE)
  ) ssu_uart_tx_i0 (
    .clk	(clk),      // Clock input
    .rst	(rst),      // Active HIGH reset - synchronous to clk

    .tx_data_val (tx_data_val),     // Indicates new character ready
    .tx_data	   (tx_data),         // Data from the char FIFO
    .tx_done	   (tx_done),         // Pop signal to the char FIFO

    .txd_o	(txd_o)            // The transmit serial signal
);

endmodule
