#include "anf.h"

int anf(int y, int *s, int *a, int *rho, unsigned int* index)
{
    /*
     y in Q15 : newly captured sample
     s in Q14 : x[3] databuffer - Hint: Reserve a sufficiently number of integer bits such that summing intermediate values does not cause overflow (so no shift is needed after summing numbers)
     a in Q14 : the adaptive coefficient
     e in Q14 : output signal
     rho in Q15 : fixed {rho, rho^2} or variable {rho, rho_inf} pole radius
     index : points to (t-1) sample (t current time index) in s -> circular buffer
     */

    int e, k;
    long AC0, AC1;

    k = *index;

    // STEP 1: s[k] = y + (rho * a * s[k-1] - rho^2 * s[k-2]) >> 1

	s[k] = y >> 1;	                                    // get current sample into data buffer in Q14

	AC0 = (long)rho[0] * (*a) * s[(k - 1 + 3) % 3];     // rho * a * s[k-1] in Q15 * Q14 * Q14 = Q43.
	AC0 = AC0 >> 29;                                    // Scale back to Q14. 43-14 = 29

	AC1 = (long)rho[1] * s[(k - 2 + 3) % 3];            // rho^2 * s_prev2 in Q15 * Q14 = Q29.
	AC1 = AC1 >> 15;                                    // Scale back to Q14. 29-14 = 15

	s[k] = s[k] + ((int)AC0 - (int)AC1);                // update s[k] in Q14.

	//STEP 2: e = s[k] - ((a * s[k-1]) >> 1) + s[k-2]
	AC0 = (long)(*a) * s[(k - 1 + 3) % 3];              // a * s[k-1] in Q14 * Q14 = Q28.
	AC0 = AC0 >> 14;                                    // Scale back to Q14. 27-14=14

	e = s[k] - (int)AC0 + s[(k - 2 + 3) % 3];           // update e in Q14.

	
	//STEP 3: a = a + ((2 * mu * s[k_prev1] * e) >> 1)
	AC1 = (long)s[(k - 1 + 3) % 3] * e * mu;            // s[k-1] * e * mu in Q14 * Q14 * Q15 = Q43.
	AC1 = AC1 >> 30;                                    // Scale to Q13. 43-13 = 30
	// Check stability bounds (|a| < 2 in Q13)
    if (AC1 > (1 << 13) - 1) {
        AC1 = (1 << 13) - 1;                            // Clamp to maximum positive value in Q13
    }
    else if (AC1 < -(1 << 13)) {
        AC1 = -(1 << 13);                               // Clamp to maximum negative value in Q13
    }

    AC1 = AC1 << 1;                                     // Scale back to Q14 (even if it really is still Q13)

    *a += (int)AC1;

    // STEP 4: Update and return
    *index = (k + 1) % 3;

    return e;


	
//	for (int i=0; i<3; i++) {
//
//		// ANF PROCESSING
//		s[i] = y + rho*a[k-i-1]*s[k-i-1]-rho*rho*s[k-i-2]; // potential segmentation fault, make sure that k-i-2>0
//		e = s[i] - a[k-i-1]*s[k-i-1] + s[k-i-2];
//		a[i] += 2*mu*e*s[k-1];
//		// END OF ANF PROCESSING
//
//		k = k >= 3 ? 0 : k;	// simulate circular buffer
//	}
//
//	*index = (k == 0) ? 0 : k-1;	// update circular buffer index, however, not sure about ? 0 part
//
//    return e;
}
