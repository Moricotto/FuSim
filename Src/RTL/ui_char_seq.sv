//-----------------------------------------------------------------------------
//  
//  Project  : SSRM RF Processor
//  Module   : ssu_char_seq.v
//  Parent   : ss_ui
//  Children : none
//
//  Description: 
//     This is a simple adapter that pops data from the character FIFO and
//     sends it to the UART transmitter.
//
//     The data and valid to the UART persist until the done is signalled
//     (which is at the beginning of the stop bit). If a next character exists
//     in the FIFO it should be popped and ready within one bit period.
//    
//
//  Parameters:
//     None
//
//  Local Parameters:
//
//  Notes       : 
//
//  Multicycle and False Paths
//     None
//

`timescale 1ns/1ps


module ui_char_seq (
  // Write side inputs
  input            clk,          // Clock input
  input            rst,          // Active HIGH reset - synchronous to clk

  input            char_fifo_empty,
  output reg       char_fifo_rd_en,
  input      [7:0] char_fifo_dout,

  output reg       tx_data_val,
  output reg [7:0] tx_data,
  input            tx_done
);


//***************************************************************************
// Parameter definitions
//***************************************************************************

  parameter [1:0]
    IDLE  = 2'b00,
    FETCH = 2'b01,
    WAIT  = 2'b10,
    SEND  = 2'b11;


//***************************************************************************
// Reg declarations
//***************************************************************************

  reg [1:0] state;
  reg       old_tx_done;

//***************************************************************************
// Wire declarations
//***************************************************************************
  
//***************************************************************************
// Code
//***************************************************************************

  // Main state machine
  always @(posedge clk)
  begin
    if (rst)
    begin
      char_fifo_rd_en <= 1'b0;
      tx_data_val     <= 1'b0;
      tx_data         <= 8'h0;
      state           <= IDLE;
      old_tx_done     <= 1'b0;
    end
    else
    begin
      old_tx_done     <= tx_done;
		char_fifo_rd_en <= 1'b0;
      case (state)
        IDLE: begin
          if (!char_fifo_empty)
          begin
            char_fifo_rd_en <= 1'b1;
            state <= FETCH;
          end
        end // IDLE state

        FETCH: begin
          // The FIFO is doing the read this clock
          state <= WAIT;
        end // FETCH state

        WAIT: begin
          // Capture the data and signal ready to the TX
          tx_data     <= char_fifo_dout;
          tx_data_val <= 1'b1;
          state       <= SEND;
        end // WAIT state

        SEND: begin
          // Wait for the TX to send it
          if (tx_done && !old_tx_done)
          begin
            tx_data_val <= 1'b0;
            state       <= IDLE;
          end
        end // SEND state
      endcase
    end // if rst
  end // always 

endmodule
