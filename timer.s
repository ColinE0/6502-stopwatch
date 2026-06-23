; 6502 stopwatch. counts MM:SS on a 16x2 LCD, button on CA1 resets to 00:00.
; W65C02 + W65C22 VIA @ 1MHz. LCD data on port B, control lines on port A.
; build: vasm6502_oldstyle -wdc02 -Fbin -dotdir -o timer.bin timer.s

PORTB = $6000
PORTA = $6001
DDRB  = $6002
DDRA  = $6003
T1CL  = $6004
T1CH  = $6005
ACR   = $600b
PCR   = $600c
IFR   = $600d
IER   = $600e

E  = %10000000
RW = %01000000
RS = %00100000

ticks   = $00
seconds = $01
minutes = $02
redraw  = $03

  .org $8000

reset:
  ldx #$ff
  txs

  lda #%11111111
  sta DDRB
  lda #%11100000
  sta DDRA              ; E, RW, RS are outputs

  stz ticks
  stz seconds
  stz minutes

  ; let the lcd settle after power-on (~25ms)
  ldx #20
pwr_wait:
  ldy #0
pwr_loop:
  dey
  bne pwr_loop
  dex
  bne pwr_wait

  lda #%00111000        ; 8-bit, 2 line, 5x8
  jsr lcd_instruction
  lda #%00001100        ; display on, cursor off
  jsr lcd_instruction
  lda #%00000110        ; advance cursor, no shift
  jsr lcd_instruction
  lda #%00000001        ; clear
  jsr lcd_instruction

  stz PCR               ; CA1 fires on falling edge
  lda #%01000000
  sta ACR               ; timer 1 free run
  lda #$0e
  sta T1CL
  lda #$27
  sta T1CH              ; $270e + 2 = 10000 cycles = 10ms
  lda #%11000010
  sta IER               ; enable timer 1 and CA1

  lda #1
  sta redraw
  cli

loop:
  wai
  lda redraw
  beq loop
  stz redraw
  jsr render
  jmp loop

irq:
  pha

  lda IFR
  and #%00000010
  bne reset_time

  lda T1CL              ; clears the timer flag
  inc ticks
  lda ticks
  cmp #100
  bne done
  stz ticks
  inc seconds
  lda seconds
  cmp #60
  bne mark
  stz seconds
  inc minutes
  lda minutes
  cmp #60
  bne mark
  stz minutes
mark:
  lda #1
  sta redraw
  jmp done

reset_time:
  lda PORTA             ; clears the CA1 flag
  stz ticks
  stz seconds
  stz minutes
  lda #1
  sta redraw

done:
  pla
  rti

nmi:
  rti                   ; unused

render:
  lda #%00000010        ; cursor home
  jsr lcd_instruction
  lda minutes
  jsr print_2digits
  lda #':'
  jsr print_char
  lda seconds
  jsr print_2digits
  rts

; A holds 0..99, prints two digits. no divide on this chip so subtract.
print_2digits:
  ldx #0
pd_tens:
  cmp #10
  bcc pd_print
  sbc #10
  inx
  jmp pd_tens
pd_print:
  pha
  txa
  ora #'0'
  jsr print_char
  pla
  ora #'0'
  jsr print_char
  rts

lcd_instruction:
  jsr lcd_wait
  sta PORTB
  lda #0
  sta PORTA
  lda #E
  sta PORTA
  lda #0
  sta PORTA
  rts

print_char:
  jsr lcd_wait
  sta PORTB
  lda #RS
  sta PORTA
  lda #(RS | E)
  sta PORTA
  lda #RS
  sta PORTA
  rts

lcd_wait:
  pha
  lda #%00000000
  sta DDRB              ; port b to input so we can read the busy flag
lcd_busy:
  lda #RW
  sta PORTA
  lda #(RW | E)
  sta PORTA
  lda PORTB
  and #%10000000
  bne lcd_busy
  lda #RW
  sta PORTA
  lda #%11111111
  sta DDRB
  pla
  rts

  .org $fffa
  .word nmi
  .word reset
  .word irq
