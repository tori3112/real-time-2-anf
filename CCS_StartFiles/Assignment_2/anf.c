#include "anf.h"

int anf(int y, int *s, int *a, int *rho, unsigned int* index)
{
    /*
     y in Q15 : newly captured sample
     s in Q12 : x[3] databuffer - Hint: Reserve a sufficiently number of integer bits such that summing intermediate values does not cause overflow (so no shift is needed after summing numbers)
     a in Q13 : the adaptive coefficient
     e in Q14 : output signal
     rho in Q15 : fixed {rho, rho^2} or variable {rho, rho_inf} pole radius
     index : points to (t-1) sample (t current time index) in s -> circular buffer
     */

    int e, k;
    long AC0, AC1;

    k = *index;

    // STEP 1: s[k] = y + (rho * a * s[k-1]) - (rho^2 * s[k-2])
	AC0 = ((long)rho[0]) * (*a);                        // Q15 * Q13 = Q28.
	AC0 = AC0 >> 13;                                    // Temporarily scale to Q15. 28-15 = 13
	AC0 = AC0 * s[(k + 2) % 3];                         // Q15 * Q12 = Q27

	AC1 = ((long)rho[1]) * s[(k + 1) % 3];              // Q15 * Q12 = Q27.
	AC0 = AC0 - AC1;                                    // Subtraction in Q27

	AC1 = (long)y << 12;                                // Scale to Q27. 15-27 = -12
	AC0 = AC0 + AC1;                                    // Addition in Q27

	AC0 = AC0 >> 15;                                    // Scale back to Q12. 27-12 = 15
	s[k] =(int)AC0;                                     // update s[k] in Q12.

	//STEP 2: e = s[k] - (a * s[k-1]) + s[k-2]
	AC1 = ((long)(*a)) * s[(k + 2) % 3];                // Q13 * Q12 = Q25.
	AC1 = AC1 >> 11;                                    // Scale to Q14. 25-14 = 11

	AC0 = (long)s[k] << 2;                              // Scale to Q14. 12-14 = -2
	AC0 = AC0 - AC1;                                    // Subtraction in Q14

	AC1 = (long)s[(k + 1) % 3] << 2;                    // Scale to Q14. 12-14 = -2
	AC0 = AC0 + AC1;                                    // Addition in Q14

	e = (int)AC0;                                       // update e in Q14

	//STEP 3: a = a + (2 * mu * s[k-1] * e)
	AC0 = (long)s[(k + 2) % 3] * e;                     // s[k-1] * e in Q12 * Q15 = Q27
	AC0 = AC0 >> 12;                                    // Temporarily scale to Q15. 27-15 = 12
	AC0 =  AC0 * mu;                                    // (s[k-1] * e) * 2* mu in Q15 * Q15 = Q30
	AC0 = AC0 >> 17;                                    // Scale to Q13. 30-13 = 17

	AC1 = ((long)(*a));                                 // Load previous a
	AC0 = AC0 + AC1;                                    // Addition in Q13


	// Check stability bounds (|a| < 2 in Q13)
    if (AC0 > (1 << 14) - 1) {
        AC0 = (1 << 14) - 1;                            // Clamp to maximum positive value in Q13
    }
    else if (AC0 < -(1 << 14)) {
        AC0 = -(1 << 14);                               // Clamp to maximum negative value in Q13
    }

    *a = (int)AC0;

    // STEP 4: Update and return
    *index = (k + 1)%3;

    return e;

}

//#include "anf.h"
//
//int anf(int y, int *s, int *a, int *rho, unsigned int* index)
//{
//    /*
//     y in Q15 : newly captured sample
//     s in Q12 : x[3] databuffer - Hint: Reserve a sufficiently number of integer bits such that summing intermediate values does not cause overflow (so no shift is needed after summing numbers)
//     a in Q14 : the adaptive coefficient
//     e in Q13 : output signal
//     rho in Q15 : fixed {rho, rho^2} or variable {rho, rho_inf} pole radius
//     index : points to (t-1) sample (t current time index) in s -> circular buffer
//     */
//
//    int e, k;
//    long AC0, AC1;
//
//    k = *index;
//
//    //Update rho = lambda*rho(m-1)+(1-lambda)*rho(inf)
//    // rho      - 16Q15
//    // lambda   - 16Q15
//
////    AC0 = ((long)lambda)*rho[0];      //16Q15*16Q15 = 32Q30
////    AC1 = ((long)lambda2)*rho[1];     //16Q15*16Q15 = 32Q30
////    AC0 = AC1 + AC0;                  //32Q30
////    rho[0] = (short) (AC0 >> 15);     //16Q15
//
//    //Calculate rho**2 = rho[0]*rho[0]
//
//    int rho2;
//    AC0 = ((long)rho[0])*rho[0];      //16Q15*16Q15 = 32Q30
//    rho2 = (short) (AC0 >> 15);       //16Q15
//
//
//
//    //calculating state s[0] = signal[i] + rho * a_i * s[1] - (rho ** 2) * s[2]
//
//    AC1 = ((long)rho2)*s[(k+1)%3];    // 16Q15*16Q12 = 32Q27
//    AC1 = AC1 >> 2;                   // 30Q25
//
//    AC0 = ((long)rho[0])*(*a);        // 16Q15*16Q14 = 32Q29
//    AC0 = AC0 >> 16;                  // 16Q13
//    AC0 = AC0*s[(k+2)%3];             // 16Q13*16Q12 = 32Q25
//    AC0 = AC0 - AC1;                  // 32Q25-30Q25 = 32Q25
//
//    AC1 = ((long)y )<< 10;            // 16Q15 -> 26Q25
//    AC0 = AC0 + AC1;                  // 32Q25+26Q25 = 29Q25 -> sufficient integer bits chosen so no overflow
//    s[k] = (short) (AC0 >> 13);       // 28Q25 -> 16Q12
//
//
//    //calculating output signal    e[i] = s[0] - a_i * s[1] + s[2]
//
//    AC0 = ((long)(*a))*s[(k+2)%3];    // 16Q14*16Q12 = 32Q26
//    AC1 = ((long)s[k]) << 14;         // 30Q26
//    AC1 = AC1 - AC0;                  // 30Q26 - 32Q26 = 32Q26
//    AC0 = ((long)s[(k+1)%3]) <<14;    // 30Q26
//    AC0 = AC0 + AC1;                  // 30Q26+30Q26 =  29Q26
//    e = (short)(AC0 >>13);            // 16Q13
//
//
//    //filter update a = a_i + 2 * mu * s[1] * e[i]
//
//    AC0 = ((long)s[(k+2)%3])*e;       //16Q12 * 16Q13 = 32Q25
//    AC0 =  AC0 >> 16;                 //16Q9
//    AC0 = AC0*(mu);                   //16Q9*16Q15 = 32Q24
//    AC1 = ((long)(*a)) << 10;         //16Q14 -> 26Q24
//    AC0 = AC0 + AC1;                  //32Q24 + 26Q24 = 26Q24
//    AC0 = AC0 >> 10;                  // 16Q14
//
//
//    //    AC0 = ((long)s[(k+2)%3])*e;       //16Q12*16Q12 = 32Q24
//    //    AC0 = AC0 >> 13; //17Q11
//    //    AC0 = AC0*(mu>>1); //17Q11*15Q14=32Q25
//    //    AC1 = ((long)(*a)) <<11; //16Q14 -> 28Q25
//    //    AC0 = AC0 + AC1; // 32Q25 + 28Q25 = 31Q25
//    //
//    //    AC0 = AC0 >> 11; // 20Q14
//
//    //check that |a| < 2
//    if (AC0 < -32767 )
//    {
//        AC0 = -32767;
//    }
//
//    if (AC0 > 32767)
//    {
//        AC0 = 32767;
//    }
//
//     *a = (short)(AC0); //16Q14
//
//    *index = (k+1)%3;
//
//
//    return e;
//}
//
//
//
//
