;	include "hardware/custom.i"

	xdef _sid_write_reg
	xdef _sid_read_reg
	xdef _sid_init
	xdef _sid_exit

; Arguments
; d0 - SID address
; d1 - SID data
_sid_write_reg:
	move.l	a6,-(sp)
	move.l	$4.w,a6
	jsr	-120(a6)

;	lea $DFF000+$32,a0 ; SERPER
;	move.w	#6,(a0)	; 506699.2857..bps

	lea	$DFF000+$18,a0 ; SERDATR
	lea	$DFF000+$30,a1 ; SERDAT

	and.w	#$1f,d0
	or.w	#$100+$e0,d0	; pre-load with stop bit and SIDBlaster write command
	swap	d1
.waitSendSIDAddrLoop:
	move.w	(a0),d1 ; SERDATR read
	btst	#13,d1
	beq.s	.waitSendSIDAddrLoop
	move.w	d0,(a1) ; data byte to SERDAT
	swap	d1

	and.w	#$ff,d1
	or.w	#$100,d1	; pre-load with stop bit
.waitSendSIDDataLoop:
	move.w	(a0),d0 ; SERDATR read
	btst	#13,d0
	beq.s	.waitSendSIDDataLoop
	move.w	d1,(a1) ; data byte to SERDAT

.waitSendSIDAddrLoop2:
	move.w	(a0),d1 ; SERDATR read
	btst	#13,d1
	beq.s	.waitSendSIDAddrLoop2

	jsr	-126(a6)
	move.l	(sp)+,a6
	rts

_sid_init:
	lea $DFF000+$32,a0 ; SERPER
	move.w	#6,(a0)	; 506699.2857..bps
	moveq.l #1,d0
	rts


_sid_exit:
	move.l	d2,-(sp)
	moveq.l #0,d2
.resetLoop:
	move.w	d2,d0
	moveq.l	#0,d1
	bsr.s	_sid_write_reg
	addi.w	#1,d2
	cmp.w	#25,d2
	bne.s	.resetLoop
	
	move.l (sp)+,d2
	rts

_sid_read_reg
	lea	$DFF000+$18,a0 ; SERDATR
	lea	$DFF000+$30,a1 ; SERDAT

	and.w	#$1f,d0
	or.w	#$100+$a0,d0	; pre-load with stop bit and SIDBlaster write command

.waitSendSIDAddrLoop:
	move.w	(a0),d1 ; SERDATR read
	btst	#13,d1
	beq.s	.waitSendSIDAddrLoop

	move.w	d0,(a1) ; data byte to SERDAT

.waitSendSIDDataLoop:
	move.w	(a0),d0 ; SERDATR read
	btst	#13,d0
	beq.s	.waitSendSIDDataLoop

.waitSendSIDDataLoop2:
	move.w	(a0),d0 ; SERDATR read
	btst	#14,d0
	beq.s	.waitSendSIDDataLoop2
	and.l	#$ff,d0
	rts
