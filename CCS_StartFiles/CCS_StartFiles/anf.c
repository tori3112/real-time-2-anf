#include "anf.h"

int anf(int y, int *s, int *a, int *rho, unsigned int* index)
{
    /*
     y in Q15 : newly captured sample
     s in Q14 : x[3] databuffer - Hint: Reserve a sufficiently number of integer bits such that summing intermediate values does not cause overflow (so no shift is needed after summing numbers)
     a in Q13 : the adaptive coefficient
     e in Q14 : output signal
     rho in Q15 : fixed {rho, rho^2} or variable {rho, rho_inf} pole radius
     index : points to (t-1) sample (t current time index) in s -> circular buffer
     */

    int e, k;
    long AC0, AC1;

    k = *index;

	// TODO: add your own code here
	s[k] = y;	// get current sample into data buffer
	rho = 0.8;
	
	for (int i=0; i<3; i++) {
	
		// ANF PROCESSING
		s[i] = y + rho*a[k-i-1]*s[k-i-1]-rho*rho*s[k-i-2]; // potential segmentation fault, make sure that k-i-2>0
		e = s[i] - a[k-i-1]*s[k-i-1] + s[k-i-2];
		a[i] += 2*mu*e*s[k-1];
		// END OF ANF PROCESSING
		
		k = k >= 3 ? 0 : k;	// simulate circular buffer
	}
	
	*index = (k == 0) ? 0 : k-1;	// update circular buffer index, however, not sure about ? 0 part
	
    return e;
}
