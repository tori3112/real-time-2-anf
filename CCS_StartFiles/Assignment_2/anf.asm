;******************************************************************************
;* FILENAME                                                                   *
;*   anf.asm      				                                              *
;*                                                                            *
;*----------------------------------------------------------------------------*
;*                                                                            *
;*  The rate of convergence of the filter is determined by parameter MU       *
;*                                                                            * 
;******************************************************************************
;/*

	.mmregs

;	MU    .set 200					; Edit this value to the desired step-size

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

		mov   #0,mmap(ST0_55)      		; Clear all fields (OVx, C, TCx)
		or    #4100h, mmap(ST1_55)  	; Set CPL (bit 14), SXMD (bit 8);
		and   #07940h, mmap(ST1_55)     ; Clear BRAF, M40, SATD, C16, 54CM, ASM
		bclr  ARMS                      ; Disable ARMS bit 15 in ST2_55

		;;; add your implementation here ;;;

		; STEP 1: Variable setup
		bset AR0LC						; Set AR0 as circular buffer
		mov #3, BK03					; Set size of circular buffer to 3
		mov mmap(@AR0), BSA01			; Set base address of circular buffer to address of register

		mov *AR3, AR0					; Set current value of the buffer to the content at index

		; STEP 2: s[k] = y + (rho * a * s[k-1]) - (rho^2 * s[k-2])
		mov *AR0-, T2		; AR0 is decremented to point to s[k-1]
		mpy *AR1, T2, AC0 	; multiply a with s[k-1] and store product in AC0
		mpy AC0, *AR2, AC0 	; multiply AC0 with rho and store product in AC0
		mov *AR2+, T3 		; move rho squared to T3
		mpy *AR0--, T3, AC1 	; multiply s[k-2] with rho squares and store product in AC1
		sub AC0, AC1 		; AC0 - AC1 = (rho * a * s[k-1]) - (rho^2 * s[k-2])
		add T0, AC0 		; add y to AC0
		; now we would want to shift contents of s, it's a circular buffer
		mov *AR0+, T1     	; load s[0] into T1, AR0 now points to s[1]
    		mov *AR0+, T2     	; load s[1] into T2, AR0 now points to s[2]
		mov T1, *AR0-		; load T1 into s[1], AR0 now points to s[1]
		mov T2, *AR0-		; load T2 into s[2], AR0 now points to s[2]
		mov T0, *AR0		; move new element into s[0]
		

		; STEP 3: e = s[k] - (a * s[k-1]) + s[k-2]
		mov *AR0-, T2; AR0 is decremented to point to s[k-1]
		mpy *AR1, T2, AC0 ; multiply a with s[k-1] and store pruct in AC0
		sub *AR0, AC0 ; subtract AC0 from s[k]
		add *AR0--, AC0 ; add s[k-2] to s[k]
		mov AC0, T1
		

		; STEP 4: a = a + (2 * mu * s[k-1] * e)
		mov *AR0-, T2 ; AR0 is decremented to point to s[k-1]
		mpyk T2, MU, AC0 ; multiply s[k-1] with mu and store product in AC0
		sftl AC0, #1 ; multiply by two is shift to the left by 2
		mpy AC0, T1, AC0 ; multiply AC0 with e stored in T1
		add AC0,*AR1
		mov AC0, *AR1
		

		; STEP 5: Update index and return e

		POP mmap(ST2_55)				; Restore status registers
		POP	mmap(ST1_55)
		POP	mmap(ST0_55)
                               
		RET								; Exit function call
    

;*******************************************************************************
;* End of anf.asm                                              				   *
;*******************************************************************************
