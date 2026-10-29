; Standalone homebrew diagnostic for the experimental Ares link input window.
; This is not a patch to Super Mario Kart. No original game assets are needed.
lorom
org $008000
Reset:
  sei
  clc
  xce
  rep #$30
  ldx #$1fff
  txs
  lda #$0000
  tcd
CopyInputs:
  sta.l $0021dc
  ldx #$000e
.loop:
  lda.l $0021c0,x
  sta.l $7e0100,x
  lda.l $0021e0,x
  sta.l $7e0120,x
  dex
  dex
  bpl .loop
  bra CopyInputs

org $00ffc0
  db "LINK INPUT PROBE     "  ; 21-byte title
  db $20,$00,$05,$00,$01,$00,$00
  dw $ffff,$0000
org $00ffea
  dw Reset
org $00ffee
  dw Reset
org $00fffa
  dw Reset
org $00fffc
  dw Reset
org $00fffe
  dw Reset
