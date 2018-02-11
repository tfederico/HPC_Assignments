#include <stdio.h>
#include <unistd.h>
#include <stdlib.h>
#include <time.h>
#include <string.h>
#include "omp.h"

time_t extract_time_secs(struct timespec start, struct timespec stop){

  if(stop.tv_sec - start.tv_sec > 0 && stop.tv_nsec - start.tv_nsec < 0){
    return (stop.tv_sec - start.tv_sec - 1);
  }
  else{
    return (stop.tv_sec - start.tv_sec);
  }
}

time_t extract_time_nsecs(struct timespec start, struct timespec stop){
  if(stop.tv_sec - start.tv_sec > 0 && stop.tv_nsec - start.tv_nsec < 0){
    return (1000000000 - (start.tv_nsec - stop.tv_nsec));
  }
  else{
    return (stop.tv_nsec - start.tv_nsec);
  }

}

void get_time(struct timespec* clock_ref){
  if( clock_gettime(CLOCK_REALTIME, clock_ref) == -1 ) {
      perror( "clock gettime" );
      exit(-1);
  }
}

void vectors_init(double* a, double* a_seq, double* b, int len){
  for(int i = 0; i < len; i++){
    a[i] = 2;
    b[i] = 2;
    a_seq[i] = a[i];
  }
}

int powr(int base, int expo){
  if(expo == 0){
    return 1;
  }
  return base*powr(base, expo-1);
}

void multimult_seq(double *a, double *b, int len, int steps){
  double c;
  for (int t=0; t < steps; t++){
    for (int i=0; i < len; i++){
        c = a [i] * b [i];
        a[i] = c * (double) (t+1);
    }
  }
}

void multimult(double *a, double *b, int len, int steps, int n_threads){
  double c;

  for (int t=0; t < steps; t++){
      #pragma omp parallel for private(c) shared(a,b,len,steps,t) schedule(static, n_threads)
      for (int i=0; i < len; i++){
          c = a [i] * b [i];
          a[i] = c * (double) (t+1);
      }
  }
}


int main(){

  int step_iters = 10;
  int delta_steps = 10;
  int len_iters = 10;
  int delta_len = 10000;
  int thread_iters = 5;

  time_t results_seq_s[len_iters][step_iters];
  time_t results_seq_ns[len_iters][step_iters];
  time_t results_s[len_iters][step_iters][thread_iters];
  time_t results_ns[len_iters][step_iters][thread_iters];


    for(int k = 0; k < len_iters; k++){
      int len = delta_len*(k+1);
      double a[len], b[len], a_seq[len];
      for(int m = 0; m < step_iters; m++){
        int steps = delta_steps*(m+1);

        vectors_init(a,a_seq,b,len);

        struct timespec start_seq, stop_seq, start, stop;

        get_time(&start_seq);
        multimult_seq(a_seq,b,len,steps);
        get_time(&stop_seq);

        results_seq_s[k][m] = extract_time_secs(start_seq,stop_seq);
        results_seq_ns[k][m] = extract_time_nsecs(start_seq,stop_seq);

        for(int n = 0; n < thread_iters; n++){
          int n_threads = powr(2,n+1);
          omp_set_num_threads(n_threads);

          get_time(&start);
          multimult(a,b,len,steps,n_threads);
          get_time(&stop);

          results_s[k][m][n] = extract_time_secs(start,stop);
          results_ns[k][m][n] = extract_time_nsecs(start,stop);
        }
    }
  }

  FILE *fp;
  FILE *fp_par;

  fp=fopen("res_seq.csv", "w");
  if(fp == NULL)
      exit(-1);
  fprintf(fp, "length,steps,seconds,nanoseconds\n");

  fp_par=fopen("res.csv", "w");
  if(fp_par == NULL)
      exit(-1);
  fprintf(fp_par, "length,steps,threads,seconds,nanoseconds\n");

  for(int k = 0; k < len_iters; k++){
    for(int m=0; m < step_iters; m++){
      fprintf(fp,"%d,%d,%ld,%ld\n",delta_len*(k+1),delta_steps*(m+1),
              results_seq_s[k][m],results_seq_ns[k][m]);
      for(int n=0; n < thread_iters; n++){
        fprintf(fp_par,"%d,%d,%d,%ld,%ld\n",delta_len*(k+1),delta_steps*(m+1),
                powr(2,n+1),results_s[k][m][n],results_ns[k][m][n]);
      }
    }

  }


  fclose(fp);
  fclose(fp_par);

  return 0;
}
