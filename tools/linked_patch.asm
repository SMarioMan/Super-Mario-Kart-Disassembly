; Two- through eight-console Grand Prix patch for the verified USA baseline.
; Requires the companion Ares link device. The stock rebuild stays untouched.
hirom
org $C0FFC0
  db "SUPER MARIO KART LINK"
org $C0FFD7
  db $0A
; A private presentation pass updates the native projection/OAM pipeline without
; advancing racer physics, lap checks, the race clock, or inventory transitions.
org $808067
  jml GatePresentation
  nop
; Run one native Lakitu interpreter per racer, with isolated object/timer state.
; The old second viewport call must not advance another interpreter twice.
org $8080EC
  jsl UpdateLinkedLakitu
  rts
org $8080FC
  rts
org $85E124
  jml GateLakituDrawing
  nop
org $85E197
  jml GateLakituBubble
  nop
  nop
  nop
org $85E185
  jml GateLakituHide
  nop
  nop
assert read3($85DFB9) == $DF9ABC
org $85DFB9
  jsl SelectLakituContext
  nop
assert read3($85DFB4) == $1DC0BC
org $85DFB5
  dw $37C0
assert read3($85DFBE) == $0F943C
org $85DFBF
  dw $37A0
assert read3($85E02F) == $0F94DE
org $85E030
  dw $37A0
assert read3($85DFFD) == $010A9E
org $85DFFE
  dw $37B0
assert read3($85E056) == $010A9D
org $85E057
  dw $37B0
; Every linked console uses the first viewport. Native Lakitu otherwise reads
; the minimap/second-view projection for every racer except address $1000.
assert read2($85DF18) == $08D0
org $85DF18
  nop
  nop
; Mode is selected by the link session. Keep native class/course screens while
; removing entry points that could override the shared session configuration.
org $858268
  jsl ConstrainLinkMenu
org $858730
  pla
  rts
org $8587A2
  pla
  rts
org $8583BF
  dw $0815,$0812,$0817,$0814,$002F,$002F,$002F  ; LINK
org $8583CD
  dw $002F,$002F,$002F,$002F,$002F,$002F,$002F
org $858435
  dw $002F,$002F,$002F,$002F,$002F,$002F,$002F,$002F,$002F,$002F
org $81EC54
  jsl ResolveCourse
  nop
  nop
org $81E13E
  jsl SelectHostCharacter
  nop
  nop
org $81E3AA
  jsl InitializeCoins
  rts
; Finish-order insertion is shared by all eight. The original early-exit path
; only waited for the native human slots and could end a linked race prematurely.
org $8089FC
InsertLinkedFinish:
  lda.b $10,x
  bit.w #$0020
  bne .done
  lda.w #$4000
  ora.b $D4,x
  sta.b $D4,x
  jsr $8A89
  lda.w #$0068
  jsl $81F57A
  bra .record
.done:
  rts
padbyte $EA
pad $808A2E
.record:
org $809814
  rts
; Linked Grand Prix keeps the whole lobby in the cup instead of eliminating
; the lower four human finishers. Native standings and points still apply.
assert read2($81A6B0) == $0008
org $81A6B0
  dw $0010
assert read2($81CC4A) == $CC5A
org $81CC4A
  dw $CC56,$CC56,$CC56,$CC56
org $81ED61
  jsl ResetLinkRace
org $84D50D
  jml RecordNativeHistory

; Release the starting-line inhibit for every human racer when Lakitu starts.
org $80A1EB
  jsl ReleaseStartingGrid
  rts

; The world update performs pickup and inventory transitions for all eight once
; per game tick. The HUD interpreter must not update the two native inventories again.
org $80CCE6
  nop
  nop
  nop
  nop
org $81B73D
  jsl UpdateInventories
  rtl
org $81B744
  jsl ItemRacerPointer
  nop
org $81B426
  jml ClearItemHUD
org $81B45C
  jml DrawItemHUD
; These are script table entries, not instruction scans. Move their effects to
; the single world update so visibility and local camera choice cannot affect them.
assert read2($80CAF7) == $E88A
assert read2($80CB41) == $E88A
assert read2($80CC53) == $E88A
assert read2($80CC59) == $E88A
org $80CAF7
  dw SkipItemEffects
org $80CB41
  dw SkipItemEffects
org $80CC53
  dw SkipItemEffects
org $80CC59
  dw SkipItemEffects
; Human status timers must tick for all eight, even when their native object
; script is the old CPU path. Remove both native human and staggered CPU ticks.
macro SkipStatus(address, original)
  assert read2(<address>) == <original>
  org <address>
    dw SkipItemEffects
endmacro
%SkipStatus($80CAED,$EAA7)
%SkipStatus($80CB23,$EAA7)
%SkipStatus($80CB39,$EAA7)
%SkipStatus($80CB69,$EAA7)
%SkipStatus($80CB7B,$EAA7)
%SkipStatus($80CBF1,$EAA7)
%SkipStatus($80CAB8,$EB29)
%SkipStatus($80CBC9,$EB29)
%SkipStatus($80CBDB,$EB29)
%SkipStatus($80CBE1,$EB29)
%SkipStatus($80CBE7,$EB29)
; Boo must consider every other inventory, rather than XORing the two native
; player indices. Retain the original steal/roulette/failure transitions.
assert read2($80E963) == $B8A5
org $80E963
  jsl SelectGhostVictim
  nop
  nop
  nop

; Dispatch connected human racers and native CPU vacancies in the same bank.
; All original subroutines retain their bank-local JSR/RTS calling convention.
org $80A2A3
LinkedDispatch:
  jsl CheckRaceCompletion
  lda.b $20
  pha
  lda.b $28
  pha
  lda.w $3440
  pha
  ldx.w #$1700
.racer:
  lda.b $10,x
  beq .next
  bmi .human
  jsr RunLinkedCPU
  bra .next
.human:
  bit.w #$4000
  bne .control
  jsr $A4D0
.control:
  jsr $B1BE
  jsr $A892
  phx
  txa
  xba
  and.w #$0007
  asl
  tax
  lda.w $33A0,x
  sta.b $20
  eor.w $3480,x
  and.b $20
  sta.b $28
  lda.b $20
  sta.w $3480,x
  lda.w $3440,x
  sta.w $3440
  plx
  ldy.w #$0000
  jsr $A3B7
  jsr $B0EE
  jsr $B7EB
  phx
  txa
  xba
  and.w #$0007
  asl
  tax
  lda.w $3440
  sta.w $3440,x
  plx
.next:
  txa
  sec
  sbc.w #$0100
  tax
  cmp.w #$1000
  bcs .racer
  pla
  sta.w $3440
  pla
  sta.b $28
  pla
  sta.b $20
  rts
LinkedDispatchEnd:
warnpc $80A320

org $80A320
RunExtraItemEffects:
  ldx.w #ItemEffectsScript
  jmp ($0000,x)
ItemEffectsScript:
  dw $EAA7,$E88A,$BA60
org $80A32C
FinishCPURacer:
  jsr $89FC
  rtl
org $80A330
SkipItemEffects:
  inx
  inx
  jmp ($0000,x)
org $80A340
DrawLocalScene:
  phb
  phk
  plb
  jsr $8621
  jsl $81856D
  jsr $8E91
  jsr $861A
  jsr $8E60
  jsl $818587
  jsr $80EC
  jsl CountPrivateDrawing
  plb
  rtl
warnpc $80A360
org $80A33F
ReturnFromPresentation:
  rts
org $80A360
RunLinkedCPU:
  lda.w $0142
  bpl .done
  jsr $AD48
  jsr $AD5E
  jsr $AD8E
.done:
  rts
warnpc $80A370

; Select the handling table belonging to this racer, rather than P1/P2's table.
org $80A444
  sta.b $28,x
  jsl HandlingPointer
  nop
  nop
  nop
  nop
  nop
  nop
  nop
HandlingHookEnd:
warnpc $80A451

; Assign the lobby's eight unique characters before handling initialization.
org $81EE28
AssignRoster:
  ldx.w #$1000
  ldy.w #$0000
.assign:
  lda.w $21F0,y
  and.w #$00FF
  asl
  sta.b $12,x
  iny
  txa
  clc
  adc.w #$0100
  tax
  cmp.w #$1800
  bcc .assign
  jsr $EDF2
  jsr $FEB6
  bra .ranking
padbyte $EA
pad $81EE58
.ranking:

; Initialize all eight handling tables. Keep a bank-local trampoline for F01F.
org $81EDF2
InitHandlingHook:
  jsl InitializeHandling
  bra ResumeHandling
InitTrampoline:
  jsr $F01F
  rtl
ItemPickupTrampoline:
  phb
  phk
  plb
  jml $81B744
pad $81EE04
ResumeHandling:

; Mark connected slots as human and leave the remaining racers under CPU control.
org $81ED0C
InitializeHumanFlags:
  rep #$30
  lda.w $21D7
  and.w #$00FF
  asl
  sta.w $33B0
  ldx.w #$1700
.flags:
  txa
  xba
  and.w #$0007
  asl
  cmp.w $33B0
  bcc .human
  lda.w #$2000
  bra .store
.human:
  lda.w #$8040
.store:
  sta.b $10,x
  txa
  sec
  sbc.w #$0100
  tax
  cmp.w #$1000
  bcs .flags
  rts
InitializeHumanFlagsEnd:
warnpc $81ED50

org $C80000
GatePresentation:
  lda.w $21D5
  and.w #$00FF
  beq .canonical
  lda.w $3CD8
  cmp.w #$0003
  bcs .waiting
  jsl DrawPrivateInventory
  jsl DrawLocalScene
  jml ReturnFromPresentation
.waiting:
  jml ReturnFromPresentation
.canonical:
  lda.w $0162
  bmi .paused
  jml $80806C
.paused:
  jml $808097

; Item transitions happen only in the shared world. Refresh the local tilemap
; from its copied inventory without running pickup/use/roulette a second time.
DrawPrivateInventory:
  php
  rep #$30
  pha
  phx
  lda.l $803500
  bpl .empty
  and.w #$00FF
  cmp.w #$000B
  bcs .empty
  asl
  tax
  lda.l $81B320,x
  sta.l $7E0C26
  inc
  sta.l $7E0C28
  inc
  sta.l $7E0C66
  inc
  sta.l $7E0C68
  bra .done
.empty:
  lda.w #$3CE9
  sta.l $7E0C26
  sta.l $7E0C28
  dec
  sta.l $7E0C66
  sta.l $7E0C68
.done:
  plx
  pla
  plp
  rtl

GateLakituDrawing:
  phx
  lda.w $37FA
  bne .skip
  ldx.b $B4
  sep #$21
  jml $85E129
.skip:
  jml $85E162

GateLakituBubble:
  lda.w $37FA
  bne .skip
  ldx.b $B4
  sep #$20
  ldy.w #$E214
  jml $85E19E
.skip:
  clc
  jml $85E1FF

GateLakituHide:
  lda.w $37FA
  bne .skip
  sep #$20
  lda.b #$55
  ldy.b $CE
  jml $85E18B
.skip:
  jml $85E1FF

SelectLakituContext:
  php
  pha
  txa
  xba
  lsr
  lsr
  clc
  adc.w #$3800
  tay
  sty.b $B4
  pla
  plp
  rtl

UpdateLinkedLakitu:
  php
  rep #$30
  phb
  phx
  phy
  pha
  lda.b $B4
  pha
  lda.b $B8
  pha
  lda.w $0E00
  pha
  sep #$20
  lda.b #$85
  pha
  plb
  rep #$20
  lda.w $21D5
  and.w #$00FF
  beq .world
  stz.b $B8
  stz.w $37FA
  lda.w $10D4
  sta.w $37B0
  lda.w $3440
  sta.w $0E00
  ldx.w #$0000
  lda.w $37B0
  jsl $85DFB4
  brl .done
.world:
  lda.w $37F4
  bne .initialized
  inc.w $37F4
  ldx.w #$03FE
  lda.w #$0000
.clear:
  sta.w $3800,x
  dex
  dex
  bpl .clear
  ldx.w #$0000
.cloneHost:
  lda.w $1C00,x
  sta.w $3800,x
  inx
  inx
  cpx.w #$0080
  bcc .cloneHost
  ldx.w #$0080
.idle:
  lda.w #$DF76
  sta.w $3800,x
  lda.w #$2000
  sta.w $3814,x
  txa
  asl
  clc
  adc.w #$1000
  sta.w $380E,x
  txa
  clc
  adc.w #$0080
  tax
  cpx.w #$0400
  bcc .idle
  lda.w $0F94
  sta.w $37A0
.initialized:
  lda.w $101F
  xba
  and.w #$00FF
  sta.w $37FC
  lda.w $102E
  clc
  adc.w $37FC
  sta.w $37FC
  stz.w $37FA
.player:
  lda.w $37FA
  lsr
  xba
  clc
  adc.w #$1000
  sta.w $37F8
  tax
  lda.b $D4,x
  ldx.w $37FA
  sta.w $37B0,x
  cpx.w #$0000
  beq .active
  cmp.w #$0000
  bne .active
  jsl SelectLakituContext
  lda.w $0004,y
  bne .active
  bra .advance
.active:
  ldx.w $37F8
  lda.b $2E,x
  pha
  lda.b $1F,x
  xba
  and.w #$00FF
  sta.w $37FE
  lda.w $37FC
  sec
  sbc.w $37FE
  sta.b $2E,x
  ldx.w $37FA
  lda.w $3440,x
  sta.w $0E00
  stz.b $B8
  lda.w $37B0,x
  jsl $85DFB4
  ldx.w $37F8
  pla
  sta.b $2E,x
  ldx.w $37FA
  lda.w $0E00
  sta.w $3440,x
  lda.w $37B0,x
  ldx.w $37F8
  sta.b $D4,x
.advance:
  inc.w $37FA
  inc.w $37FA
  lda.w $37FA
  cmp.w #$0010
  bcc .player
  stz.w $37FA
.done:
  pla
  sta.w $0E00
  pla
  sta.b $B8
  pla
  sta.b $B4
  pla
  ply
  plx
  plb
  plp
  rtl

ConstrainLinkMenu:
  lda.b $85
  and.b #$C6
  sta.b $85
  lda.b #$02
  sta.b $2E
  cmp.b #$02
  rtl

ResetLinkRace:
  php
  phx
  phy
  pha
  stz.b $3C
  stz.b $3E
  jsl InitializeHandling
  pla
  ply
  plx
  plp
  rtl

CheckRaceCompletion:
  sta.w $21DC             ; Atomically freeze one complete eight-pad bundle.
  lda.w $0144
  cmp.w #$0010
  bcc .checkHumans
  lda.w $37F2
  bne .done
  inc.w $37F2
  lda.w #$0009
  jsl $80985F
  lda.w $1012
  sta.w $0122
.done:
  rtl
.checkHumans:
  lda.w $33B0
  cmp.w #$0010
  beq .done
  ldx.w #$1000
  ldy.w #$0000
.human:
  lda.b $10,x
  bit.w #$0020
  beq .done
  txa
  clc
  adc.w #$0100
  tax
  iny
  iny
  cpy.w $33B0
  bcc .human
  ; When every connected player finishes, place the remaining CPU racers in
  ; their current native order. Absent clients must never block race results.
  ldy.w #$000E
.copyRank:
  lda.w $010E,y
  sta.w $33C0,y
  dey
  dey
  bpl .copyRank
  ldy.w #$0000
.finishCPU:
  ldx.w $33C0,y
  lda.b $10,x
  bit.w #$0020
  bne .nextCPU
  lda.b $D4,x
  bit.w #$4000
  bne .nextCPU
  phy
  jsl FinishCPURacer
  ply
.nextCPU:
  iny
  iny
  cpy.w #$0010
  bcc .finishCPU
  rtl

RecordNativeHistory:
  cpx.w #$1200
  bcs .done
  lda.b $2C
  bne .done
  jml $84D511
.done:
  rtl

ResolveCourse:
  lda.w $21D6
  and.w #$00FF
  cmp.w #$00FF
  bne .done
  lda.l $81EC1B,x
  and.w #$00FF
.done:
  rtl
SelectHostCharacter:
  lda.w $21F0
  and.w #$00FF
  asl
  sta.w $1012
  lda.w $21F1
  and.w #$00FF
  asl
  sta.w $1112
  rtl
SelectGhostVictim:
  ldy.b $B8
  sty.w $37E0
  ldx.w #$0000
  ldy.w #$0000
.scan:
  cpx.w $37E0
  beq .next
  lda.w $3500,x
  bpl .next
  txa
  sta.w $37D0,y
  iny
  iny
.next:
  inx
  inx
  cpx.w #$0010
  bcc .scan
  sty.w $37E2
  cpy.w #$0000
  beq .none
.random:
  jsl $81BB70
  and.w #$000E
  cmp.w $37E2
  bcs .random
  tax
  lda.w $37D0,x
  tax
  ldy.w $37E0
  rtl
.none:
  lda.w $37E0
  eor.w #$0002
  tax
  ldy.w $37E0
  rtl
InitializeCoins:
  phx
  phy
  ldx.w #$1000
  ldy.w #$0000
.player:
  phx
  lda.b $E6,x
  tax
  lda.l $81E3DA,x
  plx
  sta.w $3440,y
  iny
  iny
  txa
  clc
  adc.w #$0100
  tax
  cpx.w #$1800
  bcc .player
  ply
  plx
  rtl

UpdateInventories:
  php
  rep #$30
  phb
  phx
  phy
  sep #$20
  lda.b #$81
  pha
  plb
  rep #$20
  lda.b $2C
  cmp.w #$0006
  bne .running
  lda.w $3CB4
  beq +
  brl .done
+
.running:
  lda.w $0038
  cmp.w $37F0
  bne +
  brl .done
+
  sta.w $37F0
  lda.w $1EE4
  pha
  lda.b $B8
  pha
  lda.b $B4
  pha
  ldy.w #$0000
.player:
  phy
  lda.b $2C
  cmp.w #$0006
  bne .connected
  cpy.w $33B0
  bcs .next
  lda.w $3C10,y
  beq .next
.connected:
  sty.w $1EE4
  sty.b $B8
  tya
  lsr
  xba
  clc
  adc.w #$1000
  sta.b $B4
  sta.w $3600,y
  tyx
  lda.w $33A0,x
  cpx.w $33B0
  bcc .input
  ; CPU vacancies use native driving routines and the shared item engine.
  ; Pulse A on alternate game ticks so ready CPU inventories are used once.
  lda.w $0038
  and.w #$0001
  beq .cpuReleased
  lda.w #$0080
  bra .input
.cpuReleased:
  lda.w #$0000
.input:
  sta.w $3700,x
  eor.w $3740,x
  and.w $3700,x
  sta.w $3720,x
  lda.w $3700,x
  sta.w $3740,x
  jsl ItemPickupTrampoline
  jsl $81B387
  ldx.w #RunExtraItemEffects
  jsl $80BA28
.next:
  ply
  iny
  iny
  cpy.w #$0010
  bcc .player
  pla
  sta.b $B4
  pla
  sta.b $B8
  pla
  sta.w $1EE4
.done:
  ply
  plx
  plb
  plp
  rtl

ItemRacerPointer:
  ldy.w $1EE4
  lda.w $3600,y
  tax
  rtl

ClearItemHUD:
  ldx.b $B8
  cpx.w #$0004
  bcs .done
  lda.l $81B31C,x
  tax
  jml $81B42C
.done:
  rtl
DrawItemHUD:
  ldx.b $B8
  cpx.w #$0004
  bcs .done
  lda.l $81B31C,x
  tax
  jml $81B462
.done:
  rtl

ReleaseStartingGrid:
  phx
  ldx.w #$1700
.loop:
  lda.b $10,x
  and.w #$FFBF
  sta.b $10,x
  txa
  sec
  sbc.w #$0100
  tax
  cmp.w #$1000
  bcs .loop
  plx
  lda.w #$0040
  rtl

HandlingPointer:
  phx
  txa
  xba
  and.w #$0007
  asl
  tax
  lda.l HandlingPointers,x
  plx
  rtl
HandlingPointers:
  dw $3000,$3060,$30C0,$3120,$3180,$31E0,$3240,$32A0

InitializeHandling:
  ldx.w #$03FE
  lda.w #$0000
.clear:
  sta.w $3400,x
  dex
  dex
  bpl .clear
  lda.w #$FFFF
  sta.w $37F0
  ldx.w #$1000
  lda.w #$3000
.loop:
  phx
  pha
  jsl InitTrampoline
  pla
  clc
  adc.w #$0060
  plx
  pha
  txa
  clc
  adc.w #$0100
  tax
  pla
  cpx.w #$1800
  bcc .loop
  rtl

; Keep canonical helper addresses stable: this replacement is presentation only.
org DrawPrivateInventory
  jml DrawPrivateInventoryExact

org $C8F000
DrawPrivateInventoryExact:
  php
  rep #$30
  pha
  phx
  lda.l $8037E4
  bpl .empty
  bit.w #$6000
  bne .icon
  bit.w #$1000
  bne .stolen
  lda.l $8037E6
  bit.w #$0008
  bne .empty
  lda.l $8037E4
  bra .icon
.stolen:
  lda.l $8037E6
  bit.w #$0008
  beq .empty
  lda.w #$0009
.icon:
  and.w #$00FF
  cmp.w #$000B
  bcs .empty
  asl
  tax
  lda.l $81B320,x
  sta.l $7E0C26
  inc
  sta.l $7E0C28
  inc
  sta.l $7E0C66
  inc
  sta.l $7E0C68
  bra .done
.empty:
  lda.w #$3CE9
  sta.l $7E0C26
  sta.l $7E0C28
  dec
  sta.l $7E0C66
  sta.l $7E0C68
.done:
  plx
  pla
  plp
  rtl

org ConstrainLinkMenu
  jml ConstrainLinkMenuMode

org $8585E9
  jsl FinalizeLinkSelection
  nop
  nop

org $C8F100
ConstrainLinkMenuMode:
  lda.b $85
  and.b #$C6
  sta.b $85
  lda.w $21DD
  beq .gp
  lda.b $85
  ora.b #$11
  sta.b $85
.gp:
  lda.b #$02
  sta.b $2E
  cmp.b #$02
  rtl
FinalizeLinkSelection:
  rep #$20
  lda.w $21DD
  and.w #$00FF
  beq .gp
  lda.w #$0006
  sta.b $2C
  stz.b $2E
  bra .selected
.gp:
  lda.w #$0002
  sta.b $2E
.selected:
  jsl $81F4B2
  rtl

incsrc "linked_battle.asm"

org $CFFFFF
  db $00
