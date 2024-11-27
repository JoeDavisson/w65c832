// W65C832 FPGA Soft Processor
//  Author: Michael Kohn
//   Email: mike@mikekohn.net
//     Web: https://www.mikekohn.net/
//   Board: iceFUN iCE40 HX8K
// License: MIT
//
// Copyright 2024 by Michael Kohn

module uart
(
  input  raw_clk,
  input [7:0] tx_data,
  input  tx_strobe,
  output reg tx_busy,
  output reg tx_pin,
  output reg [7:0] rx_data,
  output reg rx_ready,
  input  rx_pin
);

reg [3:0] tx_count;
reg [3:0] rx_count;

reg [9:0] rx_buffer;
reg [9:0] tx_buffer;

parameter STATE_IDLE         = 0;
parameter STATE_NEXT_BIT     = 1;
parameter STATE_RX_BIT_BACK  = 1;
parameter STATE_RX_BIT_FRONT = 2;

reg [1:0] rx_state;
reg [1:0] tx_state;

// 12,000,000 MHz / 9600 = 1250 clocks.
// 12,000,000 MHz / 9600 =  625 clocks for double speed to make sure
//   bits are clocked in / out in the center of each bit transmission.
reg [10:0] tx_divisor;
reg [9:0]  rx_divisor;

// Transmit.
always @(posedge raw_clk) begin
  case (tx_state)
    STATE_IDLE:
      begin
        // Wait for the CPU to strobe to start a read.
        if (tx_strobe) begin
          tx_state <= STATE_NEXT_BIT;
          tx_buffer[0] <= 0;
          tx_buffer[1:8] <= tx_data;
          tx_buffer[9] <= 1;
          tx_count <= 0;
          tx_busy <= 1;
          tx_divisor <= 0;
        end else begin
          tx_busy <= 0;
          tx_pin  <= 1;
        end
      end
    STATE_NEXT_BIT:
      begin
        if (tx_divisor == 1249) begin
          tx_divisor <= 0;
        end else begin
          tx_divisor <= tx_divisor + 1;
        end

        if (tx_divisor == 0) begin
          tx_pin   <= tx_buffer[tx_count];
          tx_count <= tx_count + 1;
          if (tx_count == 9) tx_state <= STATE_IDLE;
        end
      end
  endcase
end

// Receive.
always @(posedge raw_clk) begin
  case (rx_state)
    STATE_IDLE:
      begin
        // Wait for start bit to start a read.
        if (rx_pin == 0) begin
          rx_divisor <= 0;
          rx_count <= 0;
          rx_ready <= 0;
          rx_state <= STATE_RX_BIT_FRONT;
        end else begin
          rx_ready <= 1;
        end
      end
    STATE_RX_BIT_FRONT:
      begin
        if (rx_divisor == 624) begin
          rx_divisor <= 0;
        end else begin
          rx_divisor <= rx_divisor + 1;
        end
      end
    STATE_RX_BIT_BACK:
      begin
        if (rx_divisor == 624) begin
          rx_divisor <= 0;

          if (rx_count == 9) begin
            rx_data <= rx_buffer[8:1];
            rx_state <= STATE_IDLE;
          end else begin
            rx_state <= STATE_RX_BIT_FRONT;
          end
        end else begin
          rx_divisor <= rx_divisor + 1;
        end

        rx_buffer[rx_count] <= rx_pin;
        rx_count <= rx_count + 1;
      end
  endcase
end

endmodule
