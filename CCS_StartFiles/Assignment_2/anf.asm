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
;		  int *s,				=> AR0
;		  int *a,				=> AR1
; 		  int *rho,				=> AR2
;	      unsigned int* index			=> AR3
;		 );					=> T1
;

_anf:
; Initialize
		PSH  mmap(ST0_55)	; Store original status register values on stack
		PSH  mmap(ST1_55)
		PSH  mmap(ST2_55)

		mov   #0,mmap(ST0_55)      	; Clear all fields (OVx, C, TCx)
		or    #4100h, mmap(ST1_55)  	; Set CPL (bit 14), SXMD (bit 8);
		and   #07940h, mmap(ST1_55)     ; Clear BRAF, M40, SATD, C16, 54CM, ASM
		bclr  ARMS                      ; Disable ARMS bit 15 in ST2_55

		;;; add your implementation here ;;;

; STEP 1: Setup
		bset AR0LC						; Set AR0 as circular buffer
		mov #3, BK03					; Set size of circular buffer to 3
		mov mmap(AR0), BSA01			; Set base address of circular buffer to address of register

		mov *AR3, AR0					; Set current value of the buffer to the content at index


; STEP 2: s[k] = y + (rho * a * s[k-1]) - (rho^2 * s[k-2])
		mov *AR0+, T2					; load s[0] into T2 (s[k]), AR0 now points to s[1]
		mov *AR0+, T3					; load s[1] into T3 (s[k-2]), AR0 now points to s[2]
		mov *AR0<<#16, AC0				; load s[2] into high part of AC0 (long)
		mpym *AR1, AC0					; multiply s[2] with a and store product in AC0 (Q13 * Q12 = Q26) --> HI(AC0): 25-16=9

		;sfts AC0, #-14					; shifts contents of AC0 by 14 bits to the right, back to Q12
		mpym *AR2, AC0	 				; multiply HI(AC0) with rho and store product in AC0 (Q9 * Q15 = Q24)
		sfts AC0, #-12					; shifts contents of AC0 by 12 bits to the right, back to Q12

		mpym *+AR2, T3, AC1 			; increment pointer to point to rho squared, dereference that value,
											; increment pointer to point to s[1], dereference that value
											; multiply s[1] with rho squared and store product in AC1
											; this is Q15 * Q12 = Q27
		sfts AC1, #-15					; shifts contents of AC1 by 15 bits to the right, back to Q12
		sub AC1, AC0 					; AC0 - AC1 = (rho * a * s[k-1]) - (rho^2 * s[k-2]), dst = AC0
		mov T0, AC1
		sfts AC1, #3					; shift y so that it is in Q12
		add AC1, AC0 					; add y shifted to Q12 to AC0
											; now we would want to shift contents of s, it's a circular buffer
											; remember AR0 points now to s[2]
		mov HI(AC0), T0					; T0 now contains s[k]

		;AR0 is pointing at s[k-1] (after update will be s[k-2])
		mov T2, *+AR0					; increment AR0 and previous s[k] into now s[k-1])
		mov T0, *+AR0					; increment AR0 and move new element into s[k]
		;AR0 is pointing at s[k]


; STEP 3: e = s[k] - (a * s[k-1]) + s[k-2]
		mov *AR0+, T1					; move s[k] to T1, AR0 now points to s[k-1]
		mov *AR0+<<#16, AC0				; move s[k-1] to MSB of AC0, AR0 now points to s[k]
		mov *AR0+, T2					; move s[k-2] to T2, AR0 now points at s[k]
		mpym *AR1, AC0	 				; multiply s[k-1] with a and store product in AC0
											; this is Q12 * Q14 = Q26
		sfts AC0, #5					; shifts contents of AC0 by 5 bits to the left, back to Q15 in higher bits
		mov T1, AC1;
		add T2, AC1						; add s[k] and s[k-2] into AC1
		sfts AC1, #19					; shift AC1 left by 16+3 to go from Q12 to Q15 in HI(AC1)
		sub AC0, AC1					; AC1 - AC0, store result in AC1
		mov HI(AC1), T1					; take high part of AC1 as e (Q15)

		; TO REVIEW
		; T1 stores e
		; AR0 now points at value from previous cycle s[k-1]
		; T2 stores value from before two cycles s[k-2]


; STEP 4: a = a + (2 * mu * s[k-1] * e)
		mov *AR0+<<#16, AC0				; store s[k-1] in HI(AC0)
		mpyk MU, AC0					; multiply s[k-1] with mu and store product in AC0 (Q12), AR0 now points at s[k]
		sfts AC0, #1, AC0 					; multiply by two is shift to the left by 2
		mpy T1, AC0		 				; multiply AC0 with e, store product in AC0 (Q12 * Q15 = Q27, MSB: 26-16 = Q11)
		sfts AC0, #2					; shifts contents of AC0 by 2 bits to the left to MSB Q13
		mov *AR1<<#16, AC1				; load a into AC1
		add AC1, AC0					; add a to AC0, Q13 + Q13 = Q13
		;;CHECK BOUNDARIES
		mov #1, AC1				; load 1 to represent 2 in Q13 in high of AC1
		sfts AC1, #30					; shift 1 to represent 2 in Q13
		sub #1, AC1						; subtract 1
		cmp AC0 < AC1, TC1				; check if AC0 exceeds maximum negative value
		bcc a_max, TC1					; go to branch a_max if AC0 exceeds maximum

		neg T3							; 2s complement of T3 (>-2 in Q13)
		cmp AC0 > AC1, TC1				; check if AC0 exceeds maximum negative value
		bcc a_max, TC1					; go to branch a_max if AC0 exceeds maximum
		b finish						; go to update branch (finish)

a_max:
		mov T3, AC0
		b finish

		;;UPDATE ADAPTIVE COEFFICIENT
finish:
		mov AC0, *AR1					; move the result back to AR1


; STEP 5: Update index
		;mov *AR0+, T3
		mov AR0, *AR3

;; Wrapping up
		POP mmap(ST2_55)				; Restore status registers
		POP	mmap(ST1_55)
		POP	mmap(ST0_55)

		RET						; Exit function call

; NOTE: MPYM multiplies bits 32-16!
;*******************************************************************************
;* End of anf.asm                                              				   *
;*******************************************************************************
