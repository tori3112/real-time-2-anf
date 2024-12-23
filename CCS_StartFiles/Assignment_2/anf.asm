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

;	MU    .set 200		; Edit this value to the desired step-size

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

		PSH  mmap(ST0_55)	; Store original status register values on stack
		PSH  mmap(ST1_55)
		PSH  mmap(ST2_55)

		mov   #0,mmap(ST0_55)      	; Clear all fields (OVx, C, TCx)
		or    #4100h, mmap(ST1_55)  	; Set CPL (bit 14), SXMD (bit 8);
		and   #07940h, mmap(ST1_55)     ; Clear BRAF, M40, SATD, C16, 54CM, ASM
		bclr  ARMS                      ; Disable ARMS bit 15 in ST2_55

		;;; add your implementation here ;;;

		; STEP 1: Variable setup
		bset AR0LC		; Set AR0 as circular buffer
		mov #3, BK03		; Set size of circular buffer to 3
		mov mmap(@AR0), BSA01	; Set base address of circular buffer to address of register

		mov *AR3, AR0		; Set current value of the buffer to the content at index

		; STEP 2: s[k] = y + (rho * a * s[k-1]) - (rho^2 * s[k-2])
		mov *AR0+, T2		; load s[0] into T2, AR0 now points to s[1]
		mov *AR0+, T3		; load s[1] into T3, AR0 now points to s[2]
		mpy *AR1, T3, AC0 	; multiply a with s[1] and store product in AC0
					; this is Q14 * Q12 = Q26
		sft AC0, #14		; shifts contents of AC0 by 14 bits to the right, back to Q12
		mpy AC0, *AR2, AC0 	; multiply AC0 with rho and store product in AC0
					; this is Q12 * Q15 = Q29
		stf AC0, #17		; shifts contents of AC0 by 17 bits to the right, back to Q12
		mpy *+AR2, *AR0, AC1 	; increment pointer to point to rho squared, dereference that value,
					; increment pointer to point to s[2], dereference that value
					; multiply s[2] with rho squared and store product in AC1
					; this is Q15 * Q12 = Q27
		sft AC1, #15		; shifts contents of AC1 by 15 bits to the right, back to Q12
		sub AC0, AC1 		; AC0 - AC1 = (rho * a * s[k-1]) - (rho^2 * s[k-2])
		sft T0, #3		; shift y so that it is in Q12
		add T0, AC0 		; add y to AC0
		; now we would want to shift contents of s, it's a circular buffer
		; remember AR0 points now to s[2]
		mov T3, *AR0-		; load T3 into s[2], AR0 now points to s[1]
		mov T2, *AR0-		; load T2 into s[1], AR0 now points to s[0]
		mov T0, *AR0		; move new element into s[0]
		
		; TO REVIEW
		; T2 stores value from previous cycle s[1]
		; T3 stores value from before two cycles s[2]

		; STEP 3: e = s[k] - (a * s[k-1]) + s[k-2]
		mov *AR0+, T1		; move s[0] to T1, AR0 now points to s[1]
		mpy *AR1, T2, AC0 	; multiply T2 with a and store product in AC0
					; this is Q12 * Q14 = Q26
		sft AC0, #14		; shifts contents of AC0 by 14 bits to the right, back to Q12
		sub T1, AC0, T1		; subtract AC0 from s[k], store result in T1
		add T3, T1		; add T3 and T1, result is stored in T1
		
		; TO REVIEW
		; T1 stores e
		; T2 stores value from previous cycle s[1]
		; T3 stores value from before two cycles s[2]

		; STEP 4: a = a + (2 * mu * s[k-1] * e)
		
		
		mpyk T2, MU, AC0 	; multiply s[k-1] with mu and store product in AC0
				; this is Q12 * ??
		; sft if needed
		sft AC0, #1 		; multiply by two is shift to the left by 2
		mpy AC0, T1, AC0 	; multiply AC0 with e, store product in AC0
				 	; this is Q12 * Q12 = Q24 ??
		stf AC0, #12		; shifts contents of AC0 by 12 bits to the right, back to Q12
		stf, *AR1, #2		; shift a by 2 bits so it is Q12
		add *AR1, AC0		; add a to AC0, Q12 + Q12 = Q12
		mov AC0, *AR1		; move the result back to AR1
		

		; STEP 5: Update index and return e

		POP mmap(ST2_55)				; Restore status registers
		POP	mmap(ST1_55)
		POP	mmap(ST0_55)
                               
		RET						; Exit function call
    

;*******************************************************************************
;* End of anf.asm                                              				   *
;*******************************************************************************
