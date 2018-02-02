
debug		:= 0
include		../Makefile.inc


all: clean cuda
 
cuda: filters main.cpp
	$(LINKER) -o $(PROJ_BASE)/bin/cuda main.cpp filters.o ../src/Timer.cpp $(INCLUDES) $(CUDA_LIBS) $(CFLAGS) $(CUDA_LDFLAGS) 

filters: filters.cu
	$(NVCC) -c filters.cu $(NVCCFLAGS) $(INCLUDES)

clean:
	rm -f ./filters.o
	rm -f $(PROJ_BASE)/bin/cuda

