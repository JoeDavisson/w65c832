.65832

.include "test/registers.inc"

.org 0x4000
start:
  ; Set 65C816 mode.
  clc
  xce

  ; Set 65C832 mode.
  clc
  clv
  xce

  ; Set A to 8-bit.
  ; Set X/Y to 32 bit.
  SET_M8_X32

main:
  lda.b #7
  sta SPI_DIV_1

  jsr clear_screen

  ;lda.b #'A'
  ;jsr spi_send_data
  ;lda.b #':'
  ;jsr spi_send_data
  ;lda.b #' '
  ;jsr spi_send_data

  ;jsr print_accum

  ldx.l #tang_text
  jsr print_string

run:
  ;; LED on.
  lda.b #0x01
  sta 0x8008

  jsl delay

  ;; LED off.
  lda.b #0x00
  sta 0x8008

  jsl delay
  jmp run

clear_screen:
  lda.b #'|'
  jsr spi_send_data
  lda.b #0x2d
  jsr spi_send_data
  rts

print_string:
  lda 0, x
  cmp.b #0
  beq print_string_done
  jsr spi_send_data
  inx
  bra print_string
print_string_done:
  rts

print_accum:
  phx
  php
  SET_M32_X32_FULL
  lda.l #0x1234abcd
  sta 0
  SET_M8_X8
  ldx.b #3
print_accum_loop:
  lda 0, x
  lsr
  lsr
  lsr
  lsr
  jsr print_nibble
  lda 0, x
  and.b #0x0f
  jsr print_nibble
  dex
  bpl print_accum_loop
  plp
  plx
  rts

print_nibble:
  cmp.b #10
  bpl print_nibble_af
  clc
  adc.b #'0'
  jsr spi_send_data
  rts
print_nibble_af:
  clc
  adc.b #'A' - 10
  jsr spi_send_data
  rts

;; spi_send_data()
spi_send_data:
  php
  SET_M8_X8
  sta SPI_TX_1
  lda.b #1
  trb SPI_IO_1
  lda.b #SPI_START
  tsb SPI_CTL_1
spi_send_data_wait:
  lda.b #SPI_BUSY
  bit SPI_CTL_1
  bne spi_send_data_wait
  lda.b #1
  tsb SPI_IO_1
  plp
  rts

delay:
  ldx.l #0x0002_0000
delay_loop:
  dex
  bne delay_loop
  rtl

tang_text:
.asciiz "Tang Nano running   w65c832 (32bit 6502)code"

