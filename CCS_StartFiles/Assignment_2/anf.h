#ifndef ANF_H
#define ANF_H

#define mu 2 * 100 // 2 * MU ( 2 * Step size )
#define lambda 19661 // LAMBDA = 0.6 (Q15)
#define minlambda 13107 // 1-LAMBDA = 0.4 (32768-19661) (Q15)

int anf(int y, int *s , int *a, int *rho, unsigned int* index);

#endif
