#include "anf.h"

int anf(int y, int *s, int *a, int *rho, unsigned int* index)
{
    /*
     y in Q15 : newly captured sample
     s in Q12 : x[3] databuffer - Hint: Reserve a sufficiently number of integer bits such that summing intermediate values does not cause overflow (so no shift is needed after summing numbers)
     a in Q13 : the adaptive coefficient
     e in Q15 : output signal
     rho in Q15 : fixed {rho, rho^2} or variable {rho, rho_inf} pole radius
     index : points to (t-1) sample (t current time index) in s -> circular buffer
     */

    int e, k;
    long AC0, AC1;

    k = *index;

    // STEP 1: rho = lambda * rho(k-1)+ rho(inf) * (1-lambda)
    AC0 = ((long)rho[0]) * lambda;                      // Q15 * Q15 = Q30
    AC1 = ((long)rho[1]) * (32768-lambda);              // Q15 * Q15 = Q30
    AC0 = AC0 + AC1;                                    // Subtraction in Q30
    AC0 = AC0 >> 15;                                    // Scale to Q15
    rho[0] = (int)AC0;                                  // Update rho in Q15

    AC1 = (long)rho[0] * rho[0];                        // Q15 * Q15 = Q30
    AC1 = AC1 >> 15;                                    // Scale to Q15


    // STEP 2: s[k] = y + (rho * a * s[k-1]) - (rho^2 * s[k-2])
	AC0 = ((long)rho[0]) * (*a);                    // Q15 * Q13 = Q28.
	AC0 = AC0 >> 13;                                // Temporarily scale to Q15. 28-15 = 13
	AC0 = AC0 * s[(k + 2) % 3];                     // Q15 * Q12 = Q27

	AC1 = AC1 * s[(k + 1) % 3];              	// Q15 * Q12 = Q27.
	AC0 = AC0 - AC1;                                // Subtraction in Q27

	AC1 = (long)y << 12;                            // Scale to Q27. 15-27 = -12
	AC0 = AC0 + AC1;                                // Addition in Q27

	AC0 = AC0 >> 15;                                // Scale back to Q12. 27-12 = 15
	s[k] =(int)AC0;                                 // Update s[k] in Q12.

	//STEP 3: e = s[k] - (a * s[k-1]) + s[k-2]
	AC1 = ((long)(*a)) * s[(k + 2) % 3];            // Q13 * Q12 = Q25.
	AC1 = AC1 >> 10;                                // Scale to Q15. 25-15 = 10

	AC0 = (long)s[k] << 3;                          // Scale to Q15. 12-15 = -3
	AC0 = AC0 - AC1;                                // Subtraction in Q15

	AC1 = (long)s[(k + 1) % 3] << 3;                // Scale to Q14. 12-15 = -3
	AC0 = AC0 + AC1;                                // Addition in Q15

	e = (int)AC0;                                   // Update e in Q15

	//STEP 4: a = a + (2 * mu * s[k-1] * e)
	AC0 = (long)s[(k + 2) % 3] * e;                 // Q12 * Q15 = Q27
	AC0 = AC0 >> 12;                                // Temporarily scale to Q15. 27-15 = 12
	AC0 =  AC0 * 2 * mu;                            // Q15 * Q15 = Q30
	AC0 = AC0 >> 17;                                // Scale to Q13. 30-13 = 17

	AC1 = ((long)(*a));                             // Load previous a
	AC0 = AC0 + AC1;                                // Addition in Q13

	// Check stability bounds (|a| < 2 in Q13)
    if (AC0 > (1 << 14) - 1) {
        AC0 = (1 << 14) - 1;                            // Max positive value in Q13
    }
    else if (AC0 < -(1 << 14)) {
        AC0 = -(1 << 14);                               // Maximum negative value in Q13
    }

    *a = (int)AC0;                                      // Update a in Q13

    // STEP 5: Update index and return
    *index = (k + 1)%3;                                 // Update index

    return e;

}
