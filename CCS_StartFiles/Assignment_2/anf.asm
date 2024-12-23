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

	MU    .set 200					; Edit this value to the desired step-size

; Functions callable from C code

	.sect	".text"
	.global	_anf

;*******************************************************************************
;* FUNCTION DEFINITION: _anf_asm		                                       *
;*******************************************************************************
; int anf(int y,				=> T0
;		  int *s,				=> AR0
;		  int *a,				=> AR1
; 		  int *rho,				=> AR2
;	      unsigned int* index	=> AR3
;		 );						=> T1
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
		mov T0, AC0;

		; STEP 3: e = s[k] - (a * s[k-1]) + s[k-2]

		; STEP 4: a = a + (2 * mu * s[k-1] * e)

		; STEP 5: Update index and return e

		POP mmap(ST2_55)				; Restore status registers
		POP	mmap(ST1_55)
		POP	mmap(ST0_55)
                               
		RET								; Exit function call
    

;*******************************************************************************
;* End of anf.asm                                              				   *
;*******************************************************************************
