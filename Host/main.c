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

static inline int8 sgn(double val) {
 if (val < 0) return -1;
 if (val==0) return 0;
 return 1;
}

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
  uint8 buffer[N];
  int8 prn1[N+1];
  int8 circBufferI1[32766] = {0}, circBufferQ1[32766] = {0};
  int8 circBufferI2[32766] = {0}, circBufferQ2[32766] = {0};
  double xcorrI1 = 0, xcorrQ1 = 0;
  double diff    = 0, meanDiff = 0;
  double k1 = 0, k2 = 0;

  int timeVal = 0, iteration = 0, lockCounter = 0 ;
  int circIndex = 0, bufferOffset = 0, sampleOffset = 0;
  bool lock = false;

  double meanI1Now = 0, meanI2Now = 0, meanQ1Now = 0, meanQ2Now = 0;
  double meanI1Old = 0, meanI2Old = 0, meanQ1Old = 0, meanQ2Old = 0;
  double slidingSum1 = 0, slidingSum2 = 0;
  double peak1 = 0, peak2 = 0;
  double pit1 = 0, pit2 = 0;

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
        fprintf(stderr, "FPGALink device did not renumerate properly as %s\n", vp);
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
        circBufferI1[i] = (double)( ( (buffer[i] >> 0) & 0x01) ) * 2 - 1;
        circBufferI2[i] = (double)( ( (buffer[i] >> 1) & 0x01) ) * 2 - 1;
        circBufferQ1[i] = (double)( ( (buffer[i] >> 4) & 0x01) ) * 2 - 1;
        circBufferQ2[i] = (double)( ( (buffer[i] >> 5) & 0x01) ) * 2 - 1;
      }
      //circIndex = (circIndex + 32766) % 98298;

      
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
            xcorrI1 += prn1[k] * circBufferI1[(circIndex + bufferOffset + k + N) % 32766];
            xcorrQ1 += prn1[k] * circBufferQ1[(circIndex + bufferOffset + k + N) % 32766];
          }
          //printf("%f\n",sqrt(cdpValI1 * cdpValI1 + cdpValQ1 * cdpValQ1) );
          if ( sqrt(xcorrI1 * xcorrI1 + xcorrQ1 * xcorrQ1) > INT_THRESHOLD ){
            lock = true; lockCounter = 0;
            printf("Locked @ %d (corr: %f)\n", bufferOffset, sqrt(xcorrI1 * xcorrI1 + xcorrQ1 * xcorrQ1));
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
        meanI1Now = 0; meanI2Now = 0;
        meanQ1Now = 0; meanQ2Now = 0;

        meanI1Old = 0; meanI2Old = 0;
        meanQ1Old = 0; meanQ2Old = 0;

        slidingSum1 = 0; slidingSum2 = 0;
        peak1 = 0; peak2 = 0;
        pit1  = 0; pit2  = 0;

        for (int k = 0 ; k < 32767; k++){
            meanI1Now = meanI1Now * 0.99 + 0.01 * prn1[k] * circBufferI1[(circIndex + bufferOffset + k + 32767) % 32766];
            meanQ1Now = meanQ1Now * 0.99 + 0.01 * prn1[k] * circBufferQ1[(circIndex + bufferOffset + k + 32767) % 32766];
            meanI2Now = meanI2Now * 0.99 + 0.01 * prn1[k] * circBufferI2[(circIndex + bufferOffset + k + 32767) % 32766];
            meanQ2Now = meanQ2Now * 0.99 + 0.01 * prn1[k] * circBufferQ2[(circIndex + bufferOffset + k + 32767) % 32766];
            slidingSum1 += meanI1Now * meanI1Now + meanQ1Now * meanQ1Now;
            slidingSum2 += meanI2Now * meanI2Now + meanQ2Now * meanQ2Now;

            meanI1Old = meanI1Old * 0.99 + 0.01 * prn1[k] * circBufferI1[(circIndex + bufferOffset + k) % 32766];
            meanQ1Old = meanQ1Old * 0.99 + 0.01 * prn1[k] * circBufferQ1[(circIndex + bufferOffset + k) % 32766];
            meanI2Old = meanI2Old * 0.99 + 0.01 * prn1[k] * circBufferI2[(circIndex + bufferOffset + k) % 32766];
            meanQ2Old = meanQ2Old * 0.99 + 0.01 * prn1[k] * circBufferQ2[(circIndex + bufferOffset + k) % 32766];
            slidingSum1 -= meanI1Old * meanI1Old + meanQ1Old * meanQ1Old;
            slidingSum2 -= meanI2Old * meanI2Old + meanQ2Old * meanQ2Old;

          if (slidingSum1 > peak1){
            peak1 = slidingSum1;
            k1 = k;
          }
          if (slidingSum2 > peak2){
            peak2 = slidingSum2;
            k2 = k;
          }

          if (slidingSum1 < pit1)
            pit1 = slidingSum1;
          if (slidingSum2 < pit2)
            pit2 = slidingSum2;
        }

        if ( (peak1-pit1) > 5000 || (peak2-pit2) > 5000 ){
          diff = k2 - k1;
          if (abs(diff - meanDiff) < 1900) // Remove outliers
            meanDiff = meanDiff * 0.99 + 0.01 * diff;

          lockCounter = 0;
          fprintf(fp_delay, "%d,%f,%f,%f,%f,%f\n", timeVal,
                                         (double)(k1 + sampleOffset) / 3276700.0 / 32767.0 * 299792458.0,
                                         (double)(k2 + sampleOffset) / 3276700.0 / 32767.0 * 299792458.0,
                                                  diff               / 3276700.0 / 32767.0 * 299792458.0 * 100.0,
                                                  meanDiff           / 3276700.0 / 32767.0 * 299792458.0 * 100.0,
                                                  (diff - meanDiff)  / 3276700.0 / 32767.0 * 299792458.0 * 100.0);

          if (k1 < 10 || k2 < 10){
            bufferOffset -= 1;
            sampleOffset -= 32767;
            //timeVal++;
          }else if (k1 == 32767 && k2 == 32767){
            bufferOffset += 1;
            sampleOffset += 32767;
            //timeVal--;
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

      /*  */
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
