// W65C832 FPGA Soft Processor
//  Author: Michael Kohn
//   Email: mike@mikekohn.net
//     Web: https://www.mikekohn.net/
//   Board: iceFUN iCE40 HX8K
// License: MIT
//
// Copyright 2024 by Michael Kohn

// This creates 4096 bytes of ROM on the FPGA itself and pages in the
// memory from a Windbond flash chip that has a maximum of 16MB. Due
// to the wire limitations this can't access the full 16MB.

module flash_rom
(
  input [11:0] page,
  input [11:0] address,
  output reg [7:0] data_out,
  output busy,
  output reg spi_cs,
  output reg spi_clk,
  output reg spi_do,
  input  spi_di,
  input  enable,
  output flash_reset,
  output flash_wp,
  input  clk,
  input  reset
);

parameter STATE_IDLE        = 0;
parameter STATE_START       = 1;
parameter STATE_NEXT_OUT    = 2;
parameter STATE_CLOCK_OUT_0 = 3;
parameter STATE_CLOCK_OUT_1 = 4;
parameter STATE_CLOCK_IN_0  = 5;
parameter STATE_CLOCK_IN_1  = 6;
parameter STATE_NEXT_IN     = 7;
parameter STATE_FINISH      = 8;

reg [7:0] memory [4095:0];
reg [12:0] current_page = 13'h1000;
reg [3:0] state = STATE_IDLE;
reg [2:0] bit = 0;
reg [1:0] cmd_count = 0;
reg [11:0] mem_count;
reg [7:0] data;

assign busy = state != STATE_IDLE;

// Always write-protect the Windbond flash chip.
assign flash_wp = 1;

assign flash_reset = reset;

initial begin
  $readmemh("rom.txt", memory);
end

always @(posedge clk) begin
  if (reset == 1) begin
    current_page <= 13'h1000;
    state <= STATE_IDLE;
  end

  if (enable == 1) begin
    if (page == current_page) begin
      data_out <= memory[address[11:0]];
    end  else begin
      // Read page of flash into memory.
      case (state)
        STATE_IDLE:
          begin
            spi_cs <= 0;
            cmd_count <= 0;
            bit <= 7;
            mem_count <= 0;
            state <= STATE_NEXT_OUT;
          end
        STATE_NEXT_OUT:
          begin
            case (cmd_count)
              0: data <= 8'h03;
              1: data <= page[11:8];
              2: data <= page[7:0];
              3: data <= 0;
            endcase

            cmd_count <= cmd_count + 1;
          end
        STATE_CLOCK_OUT_0:
          begin
            spi_clk <= 1;
            spi_do <= data[bit];
            bit <= bit - 1;
          end
        STATE_CLOCK_OUT_1:
          begin
            spi_clk <= 0;
            if (bit == 7) begin
              if (cmd_count == 0)
                state <= STATE_CLOCK_IN_0;
              else
                state <= STATE_NEXT_OUT;
            end else begin
              state <= STATE_CLOCK_OUT_0;
            end
          end
        STATE_CLOCK_IN_0:
          begin
            spi_clk <= 1;
            state <= STATE_CLOCK_IN_1;
          end
        STATE_CLOCK_IN_1:
          begin
            spi_clk <= 0;
            data[bit] <= spi_di;
            bit <= bit - 1;

            if (bit == 0)
              state <= STATE_NEXT_IN;
            else
              state <= STATE_CLOCK_IN_0;
          end
        STATE_NEXT_IN:
          begin
            data[mem_count] <= data;
            mem_count <= mem_count + 1;

            if (mem_count == 12'hfff)
              state <= STATE_FINISH;
            else
              state <= STATE_CLOCK_IN_0;
          end
        STATE_FINISH:
          begin
            current_page <= page;
            spi_cs <= 1;
            spi_do <= 0;
            state <= STATE_IDLE;
          end
      endcase
    end
  end
end

endmodule
