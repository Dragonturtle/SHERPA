#include <stdio.h>
#include <stdlib.h>
#include <sys/time.h>
#include <time.h>
#include <errno.h>

#include <libfpgalink.h>

#include <math.h>

#define M_PI 3.14159265358979323846
#define INT_THRESHOLD 3000
#define FRAC_THRESHOLD 0.3

void PRNCode(int8 *array) {
  FILE* f = fopen("./PRNCode_1.txt", "r");
  int number = 0;
  int i = 0;
  while( fscanf(f, "%d\n", &number) > 0 )
  {
    array[i] = (int8)number;
    i++;
  }

  fclose(f);
  return;
}

int main(int argc, const char *argv[]) {
  const char* vp  = "1d50:602b";
  const char* ivp = "1443:0007"; //Nexys 3 ID
  const char* progConfig = "J:D0D2D3D4:../../sherpa_fpga/hdl/FPGA.xsvf";

  const char *error = NULL;
  struct FLContext *handle = NULL;
  uint8 flag; FLStatus status;
  bool isCommCapable, isNeroCapable;
  uint32 requestLength, actualLength;

  FILE *fp = NULL; FILE *fp_delay = NULL;

  const int N = 32766;
  const int8 *data;
  uint8 buffer[32766];
  int8 prn1[N+1];
  int8 bufferI1[32766] = {0}, bufferQ1[32766] = {0};
  int8 bufferI2[32766] = {0}, bufferQ2[32766] = {0};
  double pulseform1[32766*3] = {0}, pulseform2[32766*3] = {0};

  double meanI1 = 0, meanI2 = 0, meanQ1 = 0, meanQ2 = 0;
  double xcorrI1 = 0, xcorrQ1 = 0;
  double meanK1  = 0, meanK2 = 0;
  double k1r = 0, k2r = 0;
  double k1f = 0, k2f = 0;
  double k1 = 0, k2 = 0;

  int timeVal = 0, iteration = 0, lockCounter = 0 ;
  int bufferOffset = 0, sampleOffset = 0;
  bool lock = false;



  printf("\n\n");
  printf("****************************************\n");
  printf("*      S.H.E.R.P.A. Host Software      *\n");
  printf("*                v. 0.2                *\n");
  printf("*            (c) LAMC 2017             *\n");
  printf("****************************************\n\n");

  //Initialize FPGALink
  status = flInitialise(0, &error);
  if (status) goto cleanup;

  //Connect to USB device
  printf("Attempting to open connection to FPGALink device %s...\n", vp);
  status = flOpen(vp, &handle, NULL);

  if ( status ) {
    printf("Connection failed, attempting to load standard firmware...\n");
    status = flLoadStandardFirmware(ivp, vp, &error);

    if (status == FL_SUCCESS){
      printf("Loading complete, awaiting renumeration...\n");
      flSleep(1000);
      for (int i = 0 ; i < 60 ; i++){
        status = flIsDeviceAvailable(vp, &flag, &error);
        if (status) goto cleanup;
        if (flag) break;

        flSleep(250);
      }
      if ( !flag ) {
        fprintf(stderr, "Device did not renumerate properly as %s\n", vp);
        goto cleanup;
      }

      printf("Reattempting to open connection to FPGALink device %s...\n", vp);
      status = flOpen(vp, &handle, &error);
      if (status) goto cleanup;

      isNeroCapable = flIsNeroCapable(handle);
      if (isNeroCapable){
        if (status) goto cleanup;
        //Program FPGA
        printf("Programming FPGA...\n");
        status = flProgram(handle, progConfig, NULL, &error);

        if (status) goto cleanup;
        printf("Programming Succesful!\n");
      } else {
        printf("Device does not support NeroJTAG!\n");
        goto cleanup;
      }
    }
    else {
      goto cleanup;
    }
  }
  printf("Connection Succesful!\n");

  isCommCapable = flIsCommCapable(handle, 0x01);
  if (isCommCapable){
    //Set up conduit
    printf("Selecting conduit 0x01...\n");
    status = flSelectConduit(handle, 0x01, &error);
    if (status) goto cleanup;

    printf("Searching for lock...\n");
    fp = fopen("data.bin","wb");
    fp_delay = fopen("delay.txt","w");

    PRNCode(prn1);

    while (iteration < 501){
      status = flReadChannelAsyncSubmit(handle, 0x00, (uint32)N, buffer, &error);
      if (status) goto cleanup;
      status = flReadChannelAsyncAwait(handle, &data, &requestLength, &actualLength, &error);
      if (status) goto cleanup;

      for (int i = 0 ; i < N ; i++){
        bufferI1[i] = (double)( ( (buffer[i] >> 0) & 0x01) ) * 2 - 1;
        bufferI2[i] = (double)( ( (buffer[i] >> 1) & 0x01) ) * 2 - 1;
        bufferQ1[i] = (double)( ( (buffer[i] >> 4) & 0x01) ) * 2 - 1;
        bufferQ2[i] = (double)( ( (buffer[i] >> 5) & 0x01) ) * 2 - 1;
      }

      /* Uncommen this to save raw data
      if(iteration > 1)
        fwrite(buffer, 1, sizeof(buffer), fp);
      iteration++;
      /**/

      if (!lock){
        //==================================//
        //==  Find Initial Integer Delay  ==//
        //==================================//
        xcorrI1 = 0; xcorrQ1 = 0;
        for (int j = 0 ; j < 10 ; j++){
          for (int k = 0 ; k < 32767 ; k++){
            xcorrI1 += prn1[k] * bufferI1[(bufferOffset + k + N) % 32766];
            xcorrQ1 += prn1[k] * bufferQ1[(bufferOffset + k + N) % 32766];
          }

          if ( sqrt(xcorrI1 * xcorrI1 + xcorrQ1 * xcorrQ1) > INT_THRESHOLD ){
            lock = true; lockCounter = 0;
            printf("Locked @ %d (corr: %f)\n", bufferOffset,
            sqrt(xcorrI1 * xcorrI1 + xcorrQ1 * xcorrQ1));
            break;
          } else {
            if (bufferOffset % 1000 == 0)
            printf("%d\n", bufferOffset);

            bufferOffset++;
          }
        }
      } else {
        //=============================//
        //==  Find Fractional Delay  ==//
        //=============================//
        meanI1 = 0; meanI2 = 0;
        meanQ1 = 0; meanQ2 = 0;
        k1r = 0, k1f = 0;
        k2r = 0, k2f = 0;
        int prnOffset = 0, codeOffset = 0;
        for (int k = 0 ; k < 32766*3; k++){
          if (k + bufferOffset + prnOffset >= 32766)
          prnOffset -= 32766;
          if (k + codeOffset == 32767)
          prnOffset -= 32767;

          meanI1 = meanI1 * 0.9998 + 0.0002 * prn1[k + codeOffset] * bufferI1[bufferOffset + k + prnOffset];
          meanQ1 = meanQ1 * 0.9998 + 0.0002 * prn1[k + codeOffset] * bufferQ1[bufferOffset + k + prnOffset];
          meanI2 = meanI2 * 0.9998 + 0.0002 * prn1[k + codeOffset] * bufferI2[bufferOffset + k + prnOffset];
          meanQ2 = meanQ2 * 0.9998 + 0.0002 * prn1[k + codeOffset] * bufferQ2[bufferOffset + k + prnOffset];

          pulseform1[k] = pulseform1[k] * 0.95 + 0.05 * sqrt(meanI1 * meanI1 + meanQ1 * meanQ1);
          pulseform2[k] = pulseform2[k] * 0.95 + 0.05 * sqrt(meanI2 * meanI2 + meanQ2 * meanQ2);

          if (pulseform1[k] > 0.2 && k1r == 0){
            k1r = k;
          } else if (pulseform1[k] < 0.3 && k1f == 0 && k1r != 0 && k > k1r + 30000 ){
            k1f = k;
          }

          if (pulseform2[k] > 0.2 && k2r == 0){
            k2r = k;
          } else if (pulseform2[k] < 0.3 && k2f == 0 && k2r != 0 && k > k2r + 30000 ){
            k2f = k;
          }
        }


        if ( (k1r != 0 && k1f != 0) && (k2r != 0 && k2f != 0) ){
          k1 = (k1r + k1f) / 2;
          k2 = (k2r + k1f) / 2;
          meanK1 = meanK1 * 0.9 + 0.1 * (k1 + sampleOffset);
          meanK2 = meanK2 * 0.9 + 0.1 * (k2 + sampleOffset);

          lockCounter = 0;
          fprintf(fp_delay, "%d,%f,%f,%f,%f\n", timeVal,
          (k1 + sampleOffset) / 3276700.0 / 32766.0 * 299792458.0 * 100.0,
          (k2 + sampleOffset) / 3276700.0 / 32766.0 * 299792458.0 * 100.0,
           meanK1             / 3276700.0 / 32766.0 * 299792458.0 * 100.0,
           meanK2             / 3276700.0 / 32766.0 * 299792458.0 * 100.0);

          if (k1 < 16383 || k2 < 16383){
            bufferOffset -= 1;
            sampleOffset -= 32767;
            timeVal++;

            for (int k = 0 ; k < 32766*3; k++){
              pulseform1[k] = 0;
              pulseform2[k] = 0;
            }
          }else if (k1 == 81915 && k2 == 81915){
            bufferOffset += 1;
            sampleOffset += 32767;
            timeVal--;

            for (int k = 0 ; k < 32766*3; k++){
              pulseform1[k] = 0;
              pulseform2[k] = 0;
            }
          }

        } else {
          lockCounter++;
          if (lockCounter > 1000){
            printf("%d\n", bufferOffset);
            bufferOffset -= 2000;
            lock = false;
          }
        }
      }

      timeVal++;
      if (bufferOffset < 0){
        bufferOffset += 32766;
        sampleOffset += 2*32767;
      } else if (bufferOffset >= 32766){
        bufferOffset -= 32766;
        sampleOffset -= 2*32767;
      }
    }

    if (fp == NULL)	{
      printf("fopen failed, errno = %d\n", errno);
    } else {
      fclose(fp);
      fclose(fp_delay);
    }
  } else{
    printf("Device does not support CommFPGA!\n");
    goto cleanup;
  }

  //Clean up and handle errors
  cleanup:
  if ( error ) {
    fprintf(stderr, "%s\n", error);
    flFreeError(error);
  }
  flClose(handle);

  return 0;
}
