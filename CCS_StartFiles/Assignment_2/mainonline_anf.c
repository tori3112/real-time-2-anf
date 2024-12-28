//#include <aic3204.h>
//#include <dsplib.h>
//#include <stdio.h>
//#include <usbstk5515.h>
//
//#include "anf.h"
//#define SAMPLES_PER_SECOND 8000
//#define GAIN_IN_dB 10
//
//int main() {
//    // declare variables
//
//    short left, right;
//    int y, e, tmp1;
//    unsigned int index = 0;
//
//    FILE  *fpIn;
//    FILE  *fpOut;
//
//    char  tempc[2];
//
//    int s[3] = {0,0,0};
//    int a[1] = {8192};
//    int rho[2] = {0, 26214};
//
//
//    USBSTK5515_init(); // Initializing the Processor
//    aic3204_init();    // Initializing the Audio Codec
//
//    set_sampling_frequency_and_gain(SAMPLES_PER_SECOND, GAIN_IN_dB);
//
//
//    while (1) {
//    // Read from microphone
//    aic3204_codec_read(&left, &right);
//
//      //while (fread(tempc, sizeof(char), 2, fpIn) == 2) {
//    y = left;
//    tempc[0] = (y & 0xFF);
//    tempc[1] = (y >> 8) & 0xFF;
//
//    fwrite(tempc, sizeof(char), 2, fpIn);
//
//    e = anf(y ,&s[0], &a[0], &rho[0], &index); // Adaptive Notch Filter.
//
//
//    tempc[0] = (e & 0xFF);
//    tempc[1] = (e >> 8) & 0xFF;
//
//    fwrite(tempc, sizeof(char), 2, fpOut);
//      //}
//
//    // Write to line out
//    aic3204_codec_write(e, e);
//    }
//
//    //return 0;
//}
