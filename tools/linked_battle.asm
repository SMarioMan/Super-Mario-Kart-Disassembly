; Native balloon battle adapter. Independent racers retain $1000-$17FF;
; balloons and battle items use the link device's second 4 KiB RAM window.
org $81EC95
InitializeLinkedBattle:
  jsr $EE28
  jsr $ED0C
  jsr $ED50
  jsr $ED61
  jsl PrepareLinkedBattle
  rts
BattleRacerReset:
  jsr $F0C5
  rtl
BattlePopBalloon:
  jsr $BE77
  rtl
BattleLoadCourseGraphics:
  jsr $E50D
  jsr $EC5E
  rtl
BattleItemCollision:
  jsr $982A
  rtl
warnpc $81ED0C

; Native battle object descriptors are bank-local pointers; point them at the
; generated table in bank-mirrored link RAM instead of the six stock balloons.
org $818D27
  dw $3D00,$3D00,$3D00
; Battle projectiles must not occupy the extra racer records.
org $80F4EC
  jml ClearLinkedBattleItems
; Balloon losses run in the shared world for every racer, never in two HUDs.
org $81BE3E
  rts
org $81BE41
  rts
org $81BE78
  dw $3C60
assert read2($81BEA5) == $0D4C
org $81BEA5
  dw $3C10
; Finish race initialization after native object scripts have been created.
org $81E2E8
  jsl FinalizeLinkedBattle

org $C8F200
PrepareLinkedBattle:
  php
  rep #$30
  phx
  ldx.w #$03FE
.clear:
  stz.w $3C00,x
  dex
  dex
  bpl .clear
  ldx.w #$0154
.table:
  lda.l BattleBalloonTable,x
  sta.w $3D00,x
  dex
  dex
  bpl .table
  ldx.w #$0000
  ldy.w #$0000
.connected:
  txa
  clc
  adc.w #$002A
  tax
  iny
  iny
  cpy.w $33B0
  bcc .connected
  stz.w $3D04,x
  ldx.w #$0010
.items:
  lda.l BattleItemPointers,x
  sta.w $3E60,x
  dex
  dex
  bpl .items
  ldx.w #$004E
.lists:
  lda.l BattleBalloonLists,x
  sta.w $3C60,x
  dex
  dex
  bpl .lists
  lda.w #$FFFF
  sta.w $3CB0
  plx
  plp
  rtl
ClearLinkedBattleItems:
  ldx.b $2C
  beq .original
  ldx.w #$03FE
.clear:
  stz.w $5C00,x
  dex
  dex
  bpl .clear
  ; B6 selects a native viewport phase, not the session's racer count. Bypass
  ; its two-player pool selection instead of patching one phase-table entry.
  stz.w $015A
  stz.w $0DFC
  lda.w #$0006
  sta.w $0DF8
  ldy.w #$3E60
  sty.w $0DFA
  stz.b $00
  jml $80F523
.original:
  jml $80F500
FinalizeLinkedBattle:
  lda.b $2C
  cmp.w #$0006
  beq +
  brl .original
+
  lda.w $3CB2
  beq +
  brl .original
+
  inc.w $3CB2
  ldx.w #$1000
  ldy.w #$0000
.player:
  tya
  cmp.w $33B0
  bcc .human
  stz.b $10,x
  bra .next
.human:
  lda.w #$8040
  sta.b $10,x
  lda.w #$0003
  sta.w $3C10,y
  phx
  phy
  tya
  lsr
  lsr
  asl
  tax
  lda.l BattleSpawnX,x
  ply
  plx
  sta.b $18,x
  tya
  and.w #$0002
  beq .top
  lda.w #$0278
  sta.b $1C,x
  lda.w #$8000
  bra .angle
.top:
  lda.w #$0188
  sta.b $1C,x
  lda.w #$0000
.angle:
  sta.b $A4,x
  sta.b $A2,x
  sta.b $2A,x
  phy
  phx
  jsl BattleRacerReset
  plx
  ply
  ; F0C5 resets the angle. Face inward, toward the other starting row.
  tya
  and.w #$0002
  xba
  asl
  asl
  asl
  asl
  asl
  asl
  sta.b $A4,x
  sta.b $A2,x
  sta.b $2A,x
.next:
  iny
  iny
  txa
  clc
  adc.w #$0100
  tax
  cpx.w #$1800
  bcc .player
  ; Native assignment walks a rank list that was originally only two entries.
  ; Pin viewport roles to the two canonical objects after extending that list.
  lda.w #$CC27
  sta.w $1004
  lda.w #$CBFD
  sta.w $100C
  lda.w #$CB87
  sta.w $1104
  lda.w #$CC31
  sta.w $110C
  ; Character/course screens can leave OAM-tail cursors beyond the two battle
  ; buffers. Never let native hide-unused-sprites clear into HDMA tables at $0640.
  lda.w #$0400
  sta.w $1EF0
  lda.w #$0620
  sta.w $1EF2
.original:
  jsl $84EA17
  rtl
BattleSpawnX:
  dw $01E8,$01F8,$0208,$0218
BattleItemPointers:
  dw $5C00,$5C80,$5D00,$5D80,$5E00,$5E80,$5F00,$5F80,$0000
BattleBalloonLists:
  dw $3C70,$3C78,$3C80,$3C88,$3C90,$3C98,$3CA0,$3CA8
!slot = 0
while !slot < 8
  dw $5000+(!slot*$180),$5080+(!slot*$180),$5100+(!slot*$180),$0000
  !slot #= !slot+1
endif
BattleBalloonTable:
  dw $910D,$8D87
!slot = 0
while !slot < 8
  !balloon = 0
  while !balloon < 3
    ; Native tile $2320 uses palette 1; XOR encodes the stable player slot.
    ; The link worker supplies a separate shaded OBJ palette for these tiles.
    dw $5000+(!slot*$180)+(!balloon*$80),$A000,(!slot^1)*$0200
    dw $1000+(!slot*$100),!balloon*$5000,$E616,$E626
    !balloon #= !balloon+1
  endif
  !slot #= !slot+1
endif
  dw $0000

org CheckRaceCompletion
  jml CheckLinkedModeCompletion
org $80810C
  jml GateBattlePresentation
  nop
org $C8F800
CheckLinkedModeCompletion:
  sta.w $21DC
  lda.b $2C
  cmp.w #$0006
  beq .battle
  lda.w $0144
  jml CheckRaceCompletion+$0006
.battle:
  jsl UpdateLinkedBattle
  rtl
GateBattlePresentation:
  lda.w #$0018
  sta.w $1EFC
  lda.w $21D5
  and.w #$00FF
  beq .canonical
  lda.w $3CD8
  cmp.w #$0003
  bcs .waiting
  jsl ClearBattleForegroundOAM
  jsl EnsureBattleForeground
  jsl DrawPrivateInventory
  jsl DrawLocalScene
  jml ReturnFromPresentation
.waiting:
  jml ReturnFromPresentation
.canonical:
  lda.w $0162
  bmi .paused
  jml $808111
.paused:
  jml $808097
UpdateLinkedBattle:
  php
  rep #$30
  phx
  phy
  pha
  lda.b $B8
  pha
  lda.w $3CB4
  beq +
  brl .done
+
  lda.b $38
  cmp.w $3CB6
  bne +
  brl .done
+
  sta.w $3CB6
  jsl SharedBattleItemCollisions
  stz.w $3CB8
  lda.w #$FFFF
  sta.w $3CBA
  ldx.w #$1000
  ldy.w #$0000
.player:
  lda.w $3C10,y
  beq .next
  lda.b $8C,x
  bit.w #$0001
  beq .alive
  and.w #$FFFE
  sta.b $8C,x
  phy
  phx
  sty.b $B8
  tyx
  jsl BattlePopBalloon
  plx
  ply
  lda.w $3C10,y
  bne .alive
  stz.b $10,x
  phy
  jsl $80C2BE
  ply
  lda.w #$0000
  sta.w $3500,y
  bra .next
.alive:
  inc.w $3CB8
  sty.w $3CBA
.next:
  iny
  iny
  txa
  clc
  adc.w #$0100
  tax
  cpy.w $33B0
  bcc .player
  jsl RebuildBattleRankList
  lda.w $3CB8
  cmp.w #$0002
  bcs .done
  inc.w $3CB4
  lda.w $3CBA
  cmp.w #$FFFF
  beq .tie
  lsr
  sta.w $3CB0
  lda.w #$0001
  sta.w $0D4C
  sta.w $0D4E
  lda.w $3CBA
  beq .hostWins
  lda.w #$0000
  sta.w $0D4C
  lda.w $3CBA
  xba
  lsr
  clc
  adc.w #$1000
  tax
  lda.b $12,x
  sta.w $1112
  bra .done
.hostWins:
  stz.w $0D4E
  bra .done
.tie:
  sta.w $3CB0
  stz.w $0D4C
  stz.w $0D4E
.done:
  pla
  sta.b $B8
  pla
  ply
  plx
  plp
  rtl

; The battle initializer normally truncates the world object/rank list to P1/P2.
; Retain every connected racer so native terrain, collision and drawing scripts
; initialize and run for the added players too.
org $8184F3
  jml InitializeBattleRanks
org $C8FA00
InitializeBattleRanks:
  ldx.w #$1000
  ldy.w #$0000
.player:
  txa
  sta.w $010E,y
  sta.w $0F70,y
  sty.b $E6,x
  iny
  iny
  txa
  clc
  adc.w #$0100
  tax
  cpy.w $33B0
  bcc .player
  lda.w #$0000
.end:
  sta.w $010E,y
  sta.w $0F70,y
  iny
  iny
  cpy.w #$0012
  bcc .end
  jml $818503

org $81E2B9
  jsl LoadLinkedBattleCourse
  nop
  nop
org $C8FB00
LoadLinkedBattleCourse:
  lda.b $2C
  cmp.w #$0006
  bne .original
  lda.w $21D6
  and.w #$00FF
  cmp.w #$0014
  bcc .original
  cmp.w #$0018
  bcs .original
  sta.w $0124
.original:
  jsl BattleLoadCourseGraphics
  rtl

; Enter the same complete initializer for a fresh native battle and a rematch.
org $81ECDD
  jmp InitializeLinkedBattle

; Native per-viewport OAM-tail history can survive a screen transition. Clamp
; before hiding old sprites, so additional racers cannot clear HDMA/control RAM.
org $818179
  jml ClampBattleOAMTail
  nop
org $C8FB40
ClampBattleOAMTail:
  lda.b $2C
  cmp.w #$0006
  bne .original
  ldx.b $B8
  lda.w $1EF0,x
  cpx.w #$0002
  beq .second
  cmp.w #$0400
  bcc .store
  lda.w #$0400
  bra .store
.second:
  cmp.w #$0620
  bcc .store
  lda.w #$0620
.store:
  sta.w $1EF0,x
  bra .return
.original:
  ldx.b $B8
  lda.w $1EF0,x
.return:
  jml $81817E

; Red shells in stock battle alternate $1000/$1100. Target the nearest living
; opponent deterministically instead; retain native GP rank-based targeting.
org $80F3FB
  jml SelectLinkedHomingTarget
org $C8FC00
SelectLinkedHomingTarget:
  lda.b $2C
  bne .battle
  jml $80F40C
.battle:
  phx
  phy
  sty.w $3CC4
  lda.w $0018,y
  sta.w $3CC0
  lda.w $001C,y
  sta.w $3CC2
  lda.w #$FFFF
  sta.w $3CC8
  sty.w $3CCA
  ldx.w #$1000
  ldy.w #$0000
.player:
  cpx.w $3CC4
  beq .next
  lda.b $10,x
  bpl .next
  lda.w $3C10,y
  beq .next
  lda.b $18,x
  sec
  sbc.w $3CC0
  bpl .xPositive
  eor.w #$FFFF
  inc
.xPositive:
  sta.w $3CC6
  lda.b $1C,x
  sec
  sbc.w $3CC2
  bpl .yPositive
  eor.w #$FFFF
  inc
.yPositive:
  clc
  adc.w $3CC6
  cmp.w $3CC8
  bcs .next
  sta.w $3CC8
  stx.w $3CCA
.next:
  iny
  iny
  txa
  clc
  adc.w #$0100
  tax
  cpy.w $33B0
  bcc .player
  lda.w $3CCA
  ply
  plx
  jml $80F41F
warnpc $C8FD00

; Enforce byte capacity at the actual sprite allocators. Cached second-view
; tile scripts bypass the high-level object dispatch and can otherwise overwrite
; the OAM high-bit table or the HDMA descriptors immediately after it.
org $80BC27
  jml GuardBattleTwoSprites
  nop
org $80BC96
  jml GuardBattleFourSprites
  nop
org $80BD84
  jml GuardBattleSingleSprite
  nop
org $80BE01
  jml GuardBattleVariableSprites
  nop
  nop

macro GuardBattleSprite(name, operand, resume, foregroundOffset)
<name>:
  php
  pha
  phx
  stz.w $3CCE
  lda.b $2C
  cmp.w #$0006
  bne .draw
  lda.b $36
  cmp.w #$000E
  bne .draw
  lda.b $B4
  cmp.w #$1000
  bcc .notRacer
  cmp.w #$1800
  bcs .notRacer
  tax
  lda.b $10,x
  bpl .skip
.notRacer:
  lda.b $B4
  ldx.b $B8
  cmp.b $A8,x
  bne .ordinary
  lda.b $3C
  sta.w $3CCC
  inc.w $3CCE
  lda.b $CE
  clc
  adc.w <foregroundOffset>
  sta.b $3C
  bra .draw
.ordinary:
  lda.b $3C
  sec
  sbc.b $CE
  cmp.w #$01F0
  bcs .skip
.draw:
  plx
  pla
  plp
  sta.b $0B
  lda.w <operand>,x
  jml <resume>
.skip:
  plx
  pla
  plp
  jml $80C6E3
endmacro

org $C8E000
%GuardBattleSprite(GuardBattleTwoSprites,$0004,$80BC2C,#$0090)
%GuardBattleSprite(GuardBattleFourSprites,$0004,$80BC9B,#$0070)
%GuardBattleSprite(GuardBattleSingleSprite,$0002,$80BD89,#$0070)
GuardBattleVariableSprites:
  php
  pha
  phx
  stz.w $3CCE
  lda.b $2C
  cmp.w #$0006
  bne .draw
  lda.b $36
  cmp.w #$000E
  bne .draw
  lda.b $B4
  ldx.b $B8
  lda.b $A8,x
  tax
  lda.b $10,x
  bpl .skip
  ; The foreground kart has a reserved 32-byte OAM area ahead of the crowd.
  lda.b $3C
  sta.w $3CCC
  inc.w $3CCE
  lda.b $CE
  clc
  adc.w #$0070
  sta.b $3C
  bra .draw
.ordinary:
  lda.b $3C
  sec
  sbc.b $CE
  cmp.w #$01E0
  bcs .skip
.draw:
  plx
  pla
  plp
  pea.w $807E
  plb
  stx.b $12
  jml $80BE07
.skip:
  plx
  pla
  plp
  jml $80C6E3
warnpc $C8E200

org $818200
  jml StartLinkedBattleOAM
  nop
  nop
assert read2($80BE52) == $60AB
org $80BE50
  jml RestoreBattleForegroundOAM
org $C8E200
StartLinkedBattleOAM:
  lda.b $2C
  cmp.w #$0006
  bne .normal
  lda.b $36
  cmp.w #$000E
  bne .normal
  lda.w #$00A0
  bra .start
.normal:
  lda.w #$0070
.start:
  clc
  adc.b $CE
  jml $818206
RestoreBattleForegroundOAM:
  sta.b $00,x
  plb
  php
  pha
  lda.w $3CCE
  beq .done
  lda.w $3CCC
  sta.b $3C
  stz.w $3CCE
.done:
  pla
  plp
  jml $80C6E3
warnpc $C8E300

org $80BD41
  jml RestoreBattleQuadOAM
org $80BDC4
  jml RestoreBattleSingleOAM
org $C8E300
RestoreBattleQuadOAM:
  sta.b $00,x
  rep #$20
  bra RestoreBattleOAMCursor
RestoreBattleSingleOAM:
  sta.w $FFFF,y
RestoreBattleOAMCursor:
  php
  pha
  lda.w $3CCE
  beq .done
  lda.w $3CCC
  sta.b $3C
  stz.w $3CCE
.done:
  pla
  plp
  jml $80C6E3
warnpc $C8E400

org $C8E400
RebuildBattleRankList:
  phx
  phy
  ldx.w #$1000
  ldy.w #$0000
.player:
  lda.b $10,x
  bpl .next
  txa
  sta.w $010E,y
  sta.w $0F70,y
  iny
  iny
.next:
  txa
  clc
  adc.w #$0100
  tax
  cpx.w #$1800
  bcc .player
  lda.w #$0000
.end:
  sta.w $010E,y
  sta.w $0F70,y
  iny
  iny
  cpy.w #$0012
  bcc .end
  ply
  plx
  rtl
EnsureBattleForeground:
  lda.w $3CD0
  beq .done
  stz.w $3CD0
  ldx.w #$1000
  lda.b $04,x
  jsl $80C25A
  ldx.w #$1000
  lda.b $0C,x
  jsl $80C24D
.done:
  rtl
warnpc $C8E500

; The native projectile graphics scheduler has a second, fixed table of object
; fields. Relocate those cache pointers too: its old $14AC entries are racer
; acceleration state, even when no projectile has been thrown.
assert read1($80F66B) == $BE
org $80F66B
  jsl SelectBattleItemCache
  nop
org $C8E500
SelectBattleItemCache:
  lda.b $2C
  cmp.w #$0006
  bne .original
  tya
  tax
  lda.l BattleItemCachePointers,x
  tax
  lda.b $04,x
  rtl
.original:
  ldx.w $F62E,y
  lda.b $04,x
  rtl
BattleItemCachePointers:
  dw $5C74,$5CF4,$5C76,$5CF6,$5D74,$5DF4,$5D76,$5DF6
  dw $5E74,$5EF4,$5E76,$5EF6,$5F74,$5FF4,$5F76,$5FF6
warnpc $C8E600

; Keep the foreground racer eligible before native high-level object culling.
; Reserving OAM alone cannot help if a crowded frame skips its draw script.
org $80C730
  jml PrioritizeBattleFirstView
  nop
org $80C70D
  jml PrioritizeBattleSecondView
  nop
macro PrioritizeBattleKart(name, flag, resume, draw)
<name>:
  php
  pha
  phx
  lda.b $2C
  cmp.w #$0006
  bne .normal
  lda.b $36
  cmp.w #$000E
  bne .normal
  ldx.b $B8
  lda.b $A8,x
  cmp.b $B4
  bne .normal
  plx
  pla
  plp
  txy
  jml <draw>
.normal:
  plx
  pla
  plp
  txy
  bit.b <flag>
  bvs .special
  jml <resume>
.special:
  jml $80C769
endmacro
org $C8E600
%PrioritizeBattleKart(PrioritizeBattleFirstView,$C8,$80C735,$80C746)
%PrioritizeBattleKart(PrioritizeBattleSecondView,$CA,$80C712,$80C723)
warnpc $C8E700

; A viewport can call StartOAM more than once while assembling a frame. Clear
; the reserved slots once at the presentation gate, before either view draws.
org $C8E700
ClearBattleForegroundOAM:
  pha
  phx
  ldx.w #$002C
  lda.w #$E0E0
.clear:
  sta.w $0270,x
  sta.w $0490,x
  dex
  dex
  dex
  dex
  bpl .clear
  plx
  pla
  rtl
warnpc $C8E740

; Native first-viewport graphics refresh is staggered by world-tick parity.
; Private presentation freezes that tick, so explicitly refresh its foreground
; cache on either parity without advancing world time.
assert read1($808E65) == $B0
org $808E65
  jml RefreshPrivateForeground
  nop
org $C8E740
RefreshPrivateForeground:
  php
  lda.w $21D5
  and.w #$00FF
  bne .private
  plp
  bcs .skip
  bra .refresh
.private:
  plp
  lda.w #$FFFF
  sta.w $10BA
.refresh:
  lda.w #$0000
  jml $808E6A
.skip:
  jml $808E6D
warnpc $C8E780
org $C8E780
CountPrivateDrawing:
  lda.l $803CD8
  inc
  sta.l $803CD8
  rtl
warnpc $C8E7A0

; Native human contact checks depend on the two viewport scripts. Run item
; contact in the shared world for every live human, independent of visibility.
org $C8E800
SharedBattleItemCollisions:
  php
  phb
  pea.w $8181
  plb
  plb
  rep #$30
  phx
  phy
  ldx.w #$5C00
.item:
  lda.b $12,x
  bpl .nextItem
  lda.b $42,x
  bmi .nextItem
  ldy.w #$1000
.racer:
  lda.w $0010,y
  bpl .nextRacer
  lda.b $6A,x
  sta.w $3CDE
  cpy.w $3CDE
  bne .contact
  lda.b $6C,x
  bne .nextRacer
.contact:
  phx
  phy
  ; The native helper uses bank-81 ROM tables and preserves both actor indices.
  jsl BattleItemCollision
  ply
  plx
  lda.b $42,x
  bmi .nextItem
.nextRacer:
  tya
  clc
  adc.w #$0100
  tay
  cpy.w #$1800
  bcc .racer
.nextItem:
  txa
  clc
  adc.w #$0080
  tax
  cpx.w #$6000
  bcc .item
  ply
  plx
  plb
  plp
  rtl
warnpc $C8E900
