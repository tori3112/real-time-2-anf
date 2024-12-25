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
LAMBDA .set 19661
LAMBDA2 .set 13107

; Functions callable from C code

	.sect	".text"
	.global	_anf

;*******************************************************************************
;* FUNCTION DEFINITION: _anf_asm		                                       *
;*******************************************************************************
; int anf(int y,				=> T0
;		  int *x,				=> AR0
;		  int *a,				=> AR1
; 		  int *rho,				=> AR2
;	      unsigned int* index	=> AR3
;		 );						=> T0
;

;_anf:

		PSH  mmap(ST0_55)	; Store original status register values on stack
		PSH  mmap(ST1_55)
		PSH  mmap(ST2_55)

		mov   #0,mmap(ST0_55)      		; Clear all fields (OVx, C, TCx)
		or    #4100h, mmap(ST1_55)  	; Set CPL (bit 14), SXMD (bit 8);
		and   #07940h, mmap(ST1_55)     ; Clear BRAF, M40, SATD, C16, 54CM, ASM
		bclr  ARMS                      ; Disable ARMS bit 15 in ST2_55

		; add your implementation here

		;setup circ state buffer
		mov   mmap(AR0), BSA01            ; base address for state register
    	mov   #3,  BK03             ; Set coefficient array size
		bset  AR0LC						  ; Set as circ buffer
		;calculating state s[0] = signal[i] + rho * a_i * s[1] - (rho ** 2) * s[2]
;		  int *s,				=> AR0
;		  int *a,				=> AR1
; 		  int *rho,				=> AR2
;	      un	signed int* index	=> AR3

		MOV *AR3,AR0


		;Update rho = lambda*rho(m-1)+(1-lambda)*rho(inf)
		; 			= lambda*rho[0]+lambda2*rho[1]
		MOV *AR2+<<#16, AC0 ; AC0 has rho 16Q15 in top 16 bits
		MPYK LAMBDA, AC0, AC1 ; 16Q15 x 16Q15 = 32Q30
		MOV *AR2-<<#16, AC0 ; rho inf in AC0 16Q15
		MPYK LAMBDA2, AC0, AC2; 16Q15 x 16Q15 = 32Q30
		MOV AC2, AC0 ;AC0 has 32Q30

		ADD AC1, AC0 ; 32Q30 + 32Q30 = 32Q30 (no overflow)
		MOV AC0<<#-15,*AR2 ; updated rho stored in AR2[0]
		MOV #0,AC0
		:: MOV #0,AC1

		SQSM *AR2, AC1, AC3 ; 16Q15 * 16Q15 = 32Q30 this has -rho^2 as 32Q30
		MOV AC3<<#-15,*AR5 ; AR5 has -rho^2 as 16Q15

;;;;;;;;;; Calculating s[0] ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

		;let AR0 point to the previous s[m-1]:
		ADD *AR0+, T3;
		ADD *AR0+, T3;
		;ADD #2, AR0;
		;AR0 now points to the previous s

		;multiply rho* s[m-1]
		MOV *AR0<<#16,AC0; //this moves rho to high of AC0
		; MYPM takes bits 32-16 of AC0 so it's still multiplying with 16Q12
		MPYM *AR2,AC0,AC1 ;16Q15*16Q12 = 32Q27
		;result of multiply rho* s[m-1] -> stored in AC1

		;AC1*a
		;MYM used again so AC1 is 16Q11
		MPYM *AR1,AC1,AC0; 16Q14*16Q11 = 32Q25
		;result of multiply AC1*a -> result in AC0

		; AC0 - (rho ** 2) * s[2]

		MOV *AR5<<#16,AC1 ; AC1 contains -rho**2 in high bytes

		;let AR0 point to s[m-2]:
		ADD *AR0+, T3;
		ADD *AR0+, T3;
		;ADD #2, AR0;
		;AR0 now points to s[m-2]

		; do -rho^2 *s[2]
		MPYM *AR0,AC1,AC2;16Q12*16Q15 = 32Q27
		SFTS AC2,#-2;32Q27->30Q25
		ADD AC2,AC0; 30Q25 + 32Q25 = 32Q25
		; AC0 +  (- (rho ** 2) * s[2]) -> stored in AC0


		;signal[i] + AC0
		MOV T0,HI(AC1); 16Q15 signal stored in AC1 (upper bits)
		SFTS AC1, #-6 ; 32Q31 -> 26Q25
		ADD AC1,AC0   ;29Q25 -> signal[i] + AC0 stored in AC0
		SFTS AC0,#3   ;29Q25 -> 32Q28

		;let AR0 point to the current s:
		ADD *AR0+, T3;
		ADD *AR0+, T3;
		;ADD #2, AR0;
		;AR0 now points to the current s
		MOV HI(AC0),*AR0 ;upper bits of AC0 to calc s[0] stored in *AR0
		; AR0 contains s[0]

;;;;;;;;;;NEXT STEP: Calculating e;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

		; e[i] = s[m] - a_i * s[m-1] + s[m-2]

		;let AR0 point to the s[m-1]:
		ADD *AR0+, T3;
		ADD *AR0+, T3;
		;ADD #2, AR0;
		; AR0 now points to s[m-1]

		; multiplying  - s[m-1] * a_i
		MOV *AR1<<#16,AC0
		MPYM *AR0,AC0,AC1 ; 16Q12*16Q14 = 32Q26
		NEG AC1, AC0
		; now AC0 has -s[m-1]*a_i

		;let AR0 point to the s[m]
		ADD *AR0+, T3;
		;ADD #1, AR0
		; AR0 now points to s[m]

		; do s[m] + AC0

		;AR0 is a 16Q12. I want it to be Q26
		MOV *AR0<<#14, AC1 ; 16Q12->30Q26
		ADD AC1, AC0 ; 32Q26 + 30Q26 -> 30Q26

		;let AR0 point to the s[m-2]
		ADD *AR0+, T3;
		;ADD #1, AR0;
		; AR0 now points to s[m-2] which is 16Q12

		; do e =  AC0 + s[2]
		MOV *AR0 << #14, AC1
		ADD AC1, AC0 ;AC0 now has 29Q26
		SFTS AC0, #-13 ; AC0 is 16Q13
		MOV AC0, T0 ; this takes the lower 16 bits and puts it into T0 which is a 16Q13

		; at this point, the output e is stored in T0

    	;;;;;;;;;;;;;;;;;      update a   ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    	;  a = a_i + 2 * mu * s[m-1] * e[m]


		;let AR0 point to the s[1]
		ADD *AR0+, T3;
		;ADD #2, AR0;
		; AR0 now points to s[1] which is a 16Q12
		MOV T0, HI(AC1) ;
		MPYM *AR0, AC1, AC0 ; 16Q12 x 16Q13 -> 32Q25

		; MU * AC0
		MPYK MU, AC0, AC1 ; 16Q15 x 16Q9 = 32Q24
		; result mpy AC1 = 2 * mu * s[1] * e[i]

		MOV *AR1<<#10, AC0 ;16Q14->26Q24
		ADD AC1, AC0 ; 32Q24 + 26Q24 = 32Q24

		SFTS AC0, #-10 ; 16Q14

		MOV AC0, *AR1
		MOV #32767, T2
		cmp T2 < AR1, TC1
		bcc branchpos, TC1
    	b nextcheck

branchpos:
		mov #32767, *AR1
		b continue

nextcheck:

		MOV #-32767, T2
		cmp T2 > AR1, TC1
		bcc branchneg, TC1
		b continue

branchneg:
		mov #-32767, *AR1
		b continue

continue:
		ADD *AR0+, T3
		ADD *AR0+, T3


		MOV AR0, *AR3


		POP mmap(ST2_55)				; Restore status registers
		POP	mmap(ST1_55)
		POP	mmap(ST0_55)

		RET								; Exit function call


;*******************************************************************************
;* End of anf.asm                                              				   *
;*******************************************************************************
