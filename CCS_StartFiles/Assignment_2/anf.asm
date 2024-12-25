;******************************************************************************
;* FILENAME                                                                   *
;*   anf.asm      				                              *
;*                                                                            *
;*----------------------------------------------------------------------------*
;*                                                                            *
;*  The rate of convergence of the filter is determined by parameter MU       *
;*                                                                            *
;******************************************************************************
;/*

	.mmregs

MU    .set 200		; Edit this value to the desired step-size

; Functions callable from C code

	.sect	".text"
	.global	_anf

;*******************************************************************************
;* FUNCTION DEFINITION: _anf_asm		                                       *
;*******************************************************************************
; int anf(int y,					=> T0
;		  int *s,					=> AR0
;		  int *a,					=> AR1
; 		  int *rho,					=> AR2
;	      unsigned int* index		=> AR3
;		 );							=> T1
;

_anf:
; Initialize
		PSH  mmap(ST0_55)				; Store original status register values on stack
		PSH  mmap(ST1_55)
		PSH  mmap(ST2_55)

		mov   #0,mmap(ST0_55)      		; Clear all fields (OVx, C, TCx)
		or    #4100h, mmap(ST1_55)  	; Set CPL (bit 14), SXMD (bit 8);
		and   #07940h, mmap(ST1_55)     ; Clear BRAF, M40, SATD, C16, 54CM, ASM
		bclr  ARMS                      ; Disable ARMS bit 15 in ST2_55


; STEP 1: Setup
;********************************************************************************
		bset AR0LC						; Set AR0 as circular buffer
		mov #3, BK03					; Set size of circular buffer to 3
		mov mmap(AR0), BSA01			; Set base address of circular buffer to address of register

		mov *AR3, AR0					; Set current value of the buffer to the content at index


; STEP 2: s[k] = y + (rho * a * s[k-1]) - (rho^2 * s[k-2])
;********************************************************************************
		mov *AR0+, T2					; load s[k] into T2 (s[k]), AR0 now points to s[k-2]
		mov *AR0+<<#16, AC1				; load s[k-2] into HI(AC1), AR0 now points to s[k-1]
		mov *AR0+<<#16, AC0				; load s[k-1] into HI(AC0), AR0 now points to s[k]

		mpym *AR1, AC0					; a * s[k-1] in AC0 (Q12 * Q13 = Q25) --> HI(AC0): Q9
		sfts AC0, #3					; shift AC0 left by 3 to Q12 in HI
		mpym *AR2, AC0	 				; (a * s[k-1]) * rho in AC0 (Q12 * Q15 = Q27)

		mpym *+AR2, AC1 				; inc pointer to rho^2, rho^2 * s[k-2] in AC1 (Q15 * Q12 = Q27)
		sub AC1, AC0 					; AC0 - AC1 = (rho * a * s[k-1]) - (rho^2 * s[k-2]) in AC0
		sfts AC0, #1					; shift AC0 left by 1 to Q12 in HI

		mov T0, AC1						; load y into AC1
		sfts AC1, #13					; shift AC1 left by 13 to Q12 in HI
		add AC1, AC0 					; AC0 + AC1 = y + ((rho * a * s[k-1]) - (rho^2 * s[k-2])) in AC0

		mov HI(AC0), T0					; load s[k] into T0

		; AR0 is already pointing at s[k]
		mov T0, *AR0					; load T0 (s[k]) into buffer


; STEP 3: e = s[k] - (a * s[k-1]) + s[k-2]
;********************************************************************************
		mov *AR0+<<#19, AC1				; load s[k] into HI(AC1) in Q15, AR0 now points to s[k-2]
		mov *AR0+<<#19, AC2				; load s[k-2] into HI(AC2) in Q15, AR0 now points at s[k-1]
		mov *AR0<<#16, AC0				; load s[k-1] into HI(AC0), AR0 still points to s[k-1]

		mpym *AR1, AC0	 				; a * s[k-1] in AC0 (Q13 * Q12 = Q25) --> HI(AC0): Q9
		sfts AC0, #6					; shift AC0 left by 6 to Q15 in HI
		add AC2, AC1					; s[k] + s[k-2] in AC1 (Q15)
		sub AC0, AC1					; AC1 - AC0 = (s[k] + s[k-2]) - (a * s[k-1]) in AC1
		mov HI(AC1), T0					; load e into T0

		; AR0 still points at s[k-1]


; STEP 4: a = a + (2 * mu * s[k-1] * e)
;********************************************************************************
		mov *AR0-<<#16, AC0				; load s[k-1] into HI(AC0), AR0 now points to s[k-2]
		mpyk MU, AC0					; s[k-1] * mu in AC0 (Q12 * Q15 = Q27)--> HI(AC0): Q11
		mpy T0, AC0		 				; (s[k-1] * mu) * e in AC0 (Q11 * Q15 = Q26)
		sfts AC0, #-12					; shift AC0 right by 13 to Q13 in LO + shift left by 1 to multiply by 2

		add *AR1, AC0					; add a to (2 * mu * s[k-1] * e) in AC0 (Q13)

		;;CHECK BOUNDARIES;;
		mov #1, AC1						; load 1 into LO(AC1)
		sfts AC1, #14					; shift AC1 left by 14 to represent 2 in Q13
		sub #1, AC1						; subtract 1 to get max value

		cmp AC0 > AC1, TC1				; check if AC0 exceeds maximum positive value
		bcc a_max, TC1					; go to branch a_max if true

		neg AC1							; 2s complement of AC1 (negative)
		cmp AC0 < AC1, TC1				; check if AC0 exceeds maximum negative value
		bcc a_max, TC1					; go to branch a_max if AC0 true

		b finish						; go to finish branch

a_max:
		mov AC1, AC0					; clamp a value to (+/- 1<<14)
		b finish						; go to finish branch

		;;UPDATE ADAPTIVE COEFFICIENT;;
finish:
		mov AC0, *AR1					; load a into AR1


; STEP 5: Update index
;********************************************************************************

		; AR0 is pointing at s[k-2]
		mov AR0, *AR3					; load new index value to AR3

;; Wrapping up
		POP mmap(ST2_55)				; Restore status registers
		POP	mmap(ST1_55)
		POP	mmap(ST0_55)

		RET						; Exit function call

; NOTE: MPYM multiplies bits 32-16!
;*******************************************************************************
;* End of anf.asm                                              				   *
;*******************************************************************************
