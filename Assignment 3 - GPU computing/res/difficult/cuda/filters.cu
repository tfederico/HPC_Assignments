#include <Timer.hpp>
#include <iostream>
#include <iomanip>

using LOFAR::NSTimer;
using std::cout;
using std::cerr;
using std::endl;
using std::fixed;
using std::setprecision;

const long nrThreads = 1000000;
const int filterHeight = 5;
const int filterWidth = 5;

__global__ void rgb2grayCUDA(unsigned char *inputImage, unsigned char *grayImage, const int width, const int height) {
	unsigned int y = blockIdx.y;
	unsigned int x = (blockIdx.x * blockDim.x) + threadIdx.x;
	float grayPix = 0.0f;
	float r = 0.0f;
	float g = 0.0f;
	float b = 0.0f;

	if ( x < width && y < height) {
		r = static_cast< float >(inputImage[(y * width) + x]);
		grayPix = (0.3f * r);
		g = static_cast< float >(inputImage[(width * height) + (y * width) + x]);
		grayPix	+= (0.59f * g);
		b = static_cast< float >(inputImage[(2 * width * height) + (y * width) + x]);
		grayPix += (0.11f * b);

		grayImage[(y * width) + x] = static_cast< unsigned char >(grayPix);
	}
}

__global__ void histogram1DCUDA(unsigned char *grayImage, const int width, const int height, unsigned int *histogram) {
	unsigned int y = blockIdx.y;
	unsigned int x = (blockIdx.x * blockDim.x) + threadIdx.x;

	if(x < width && y < height){
		histogram[static_cast< unsigned int >(grayImage[(y * width) + x])] += 1;
	}
}

__global__ void contrast1DCUDA(unsigned char *grayImage, const int width, const int height, const int max, const int min){

	const float diff = max - min;

	unsigned int y = blockIdx.y;
	unsigned int x = (blockIdx.x * blockDim.x) + threadIdx.x;

	if(x < width && y < height){
			unsigned char pixel = grayImage[(y * width) + x];

			if ( pixel < min ) {
				pixel = 0;
			}
			else if ( pixel > max ) {
				pixel = 255;
			}
			else {
				pixel = static_cast< unsigned char >(255.0f * (pixel - min) / diff);
			}

			grayImage[(y * width) + x] = pixel;
	}
}

__global__ void triangularSmoothCUDA(unsigned char *grayImage, unsigned char *smoothImage, const int width, const int height, float *filter) {
		unsigned int y = blockIdx.y;
		unsigned int x = (blockIdx.x * blockDim.x) + threadIdx.x;

		if(x < width && y < height){
				unsigned int filterItem = 0;
				float filterSum = 0.0f;
				float smoothPix = 0.0f;

				for ( int fy = y - 2; fy < y + 3; fy++ ) {
					for ( int fx = x - 2; fx < x + 3; fx++ ) {

						if ( ((fy >= 0) && (fy < height)) && ((fx >= 0) && (fx < width)) ) {
							smoothPix += grayImage[(fy * width) + fx] * filter[filterItem];
							filterSum += filter[filterItem];
						}

						filterItem++;

					}
				}

				smoothPix /= filterSum;
				smoothImage[(y * width) + x] = static_cast< unsigned char >(smoothPix);
		}
}

void rgb2gray(unsigned char *inputImage, unsigned char *grayImage, const int width, const int height, NSTimer &timer) {
		cudaError_t devRetVal = cudaSuccess;
		void *inputImage_d = 0;
		void *grayImage_d = 0;
		NSTimer kernelTime = NSTimer("kernelTime", false, false);
		NSTimer memoryTime = NSTimer("memoryTime", false, false);

		// Allocate device memory
		if ( (devRetVal = cudaMalloc(reinterpret_cast< void ** >(&inputImage_d), width * height * 3 * sizeof(unsigned char))) != cudaSuccess ) {
			cerr << "Impossible to allocate device memory for inputImage_d." << endl;
			return;
		}
		if ( (devRetVal = cudaMalloc(reinterpret_cast< void ** >(&grayImage_d), width * height * sizeof(unsigned char))) != cudaSuccess ) {
			cerr << "Impossible to allocate device memory for grayImage_d." << endl;
			return;
		}
		// Copy input to device
		memoryTime.start();
		if ( (devRetVal = cudaMemcpy(inputImage_d, reinterpret_cast< void * >(inputImage), width * height * 3 * sizeof(unsigned char), cudaMemcpyHostToDevice)) != cudaSuccess ) {
			cerr << "Impossible to copy inputImage_d to device." << endl;
			return;
		}
		memoryTime.stop();
		timer.stop();
		if ( (devRetVal = cudaMemset(grayImage_d, 0, width * height * sizeof(unsigned char))) != cudaSuccess ) {
			cerr << "Impossible to clean grayImage_d." << endl;
			return;
		}
		timer.start();


		dim3 gridSize = dim3(static_cast< unsigned int >(ceil(width / static_cast< float >(nrThreads))), height);
		dim3 blockSize = dim3(nrThreads);
		kernelTime.start();
		rgb2grayCUDA<<< gridSize, blockSize >>>(reinterpret_cast< unsigned char * >(inputImage_d), reinterpret_cast< unsigned char * >(grayImage_d), width, height);
		cudaDeviceSynchronize();
		kernelTime.stop();

		// Copy back to host
		timer.stop();
		if ( (devRetVal = cudaMemcpy(reinterpret_cast< void * >(grayImage), grayImage_d, width * height * sizeof(unsigned char), cudaMemcpyDeviceToHost)) != cudaSuccess ) {
			cerr << "Impossible to copy grayImage_d to host." << endl;
			return;
		}
		cudaFree(inputImage_d);
		cudaFree(grayImage_d);
		timer.start();

		if(sizeof(grayImage) > sizeof(inputImage)){
			std::cerr << "Image too big!" << '\n';
		}
		cout << fixed << setprecision(6);
		cout << "rgb2gray (kernel): \t\t" << kernelTime.getElapsed() << " seconds." << endl;
		cout << "rgb2gray (memory): \t\t" << memoryTime.getElapsed() << " seconds." << endl;
}

void histogram1D(unsigned char *grayImage, unsigned char *histogramImage, const int width, const int height, unsigned int *histogram, const unsigned int HISTOGRAM_SIZE, const unsigned int BAR_WIDTH, NSTimer &timer) {
		cudaError_t devRetVal = cudaSuccess;
		void *grayImage_d = 0;
		void *histogram_d = 0;
		NSTimer kernelTime = NSTimer("kernelTime", false, false);
		NSTimer memoryTime = NSTimer("memoryTime", false, false);

		// Allocate device memory
		if ( (devRetVal = cudaMalloc(reinterpret_cast< void ** >(&grayImage_d), width * height * sizeof(unsigned char))) != cudaSuccess ) {
			cerr << "Impossible to allocate device memory for grayImage_d." << endl;
			return;
		}
		if ( (devRetVal = cudaMalloc(reinterpret_cast< void ** >(&histogram_d), HISTOGRAM_SIZE * sizeof(unsigned int))) != cudaSuccess ) {
			cerr << "Impossible to allocate device memory for histogram_d." << endl;
			return;
		}

		// Copy input to device
		memoryTime.start();
		if ( (devRetVal = cudaMemcpy(grayImage_d, reinterpret_cast< void * >(grayImage), width * height * sizeof(unsigned char), cudaMemcpyHostToDevice)) != cudaSuccess ) {
			cerr << "Impossible to copy grayImage_d to device." << endl;
			return;
		}
		if ( (devRetVal = cudaMemcpy(histogram_d, reinterpret_cast< void * >(histogram), HISTOGRAM_SIZE * sizeof(unsigned int), cudaMemcpyHostToDevice)) != cudaSuccess ) {
			cerr << "Impossible to copy histogram_d to device." << endl;
			return;
		}
		memoryTime.stop();
		timer.stop();
		timer.start();

		dim3 gridSize = dim3(static_cast< unsigned int >(ceil(width / static_cast< float >(nrThreads))), height);
		dim3 blockSize = dim3(nrThreads);

		kernelTime.start();
		histogram1DCUDA<<< gridSize, blockSize >>>(reinterpret_cast< unsigned char * >(grayImage_d), width, height, reinterpret_cast< unsigned int * >(histogram_d));
		cudaDeviceSynchronize();
		kernelTime.stop();

		// Copy back to host
		timer.stop();
		if ( (devRetVal = cudaMemcpy(reinterpret_cast< void * >(histogram), histogram_d, HISTOGRAM_SIZE * sizeof(unsigned int), cudaMemcpyDeviceToHost)) != cudaSuccess ) {
			cerr << "Impossible to copy histogram_d to host." << endl;
			return;
		}

		cudaFree(grayImage_d);
		cudaFree(histogram_d);
		timer.start();

		unsigned int max = 0;

		for ( unsigned int i = 0; i < HISTOGRAM_SIZE; i++ ) {
			if ( histogram[i] > max ) {
				max = histogram[i];
			}
		}

		for ( int x = 0; x < HISTOGRAM_SIZE * BAR_WIDTH; x += BAR_WIDTH ) {
			unsigned int value = HISTOGRAM_SIZE - ((histogram[x / BAR_WIDTH] * HISTOGRAM_SIZE) / max);
			for ( unsigned int y = 0; y < value; y++ ) {
				for ( unsigned int i = 0; i < BAR_WIDTH; i++ ) {
					histogramImage[(y * HISTOGRAM_SIZE * BAR_WIDTH) + x + i] = 0;
				}
			}
			for ( unsigned int y = value; y < HISTOGRAM_SIZE; y++ ) {
				for ( unsigned int i = 0; i < BAR_WIDTH; i++ ) {
					histogramImage[(y * HISTOGRAM_SIZE * BAR_WIDTH) + x + i] = 255;
				}
			}
		}

		cout << fixed << setprecision(6);
		cout << "histogram1D (kernel): \t\t" << kernelTime.getElapsed() << " seconds." << endl;
		cout << "histogram1D (memory): \t\t" << memoryTime.getElapsed() << " seconds." << endl;


}

void contrast1D(unsigned char *grayImage, const int width, const int height, unsigned int *histogram, const unsigned int HISTOGRAM_SIZE, const unsigned int CONTRAST_THRESHOLD, NSTimer &timer) {
		cudaError_t devRetVal = cudaSuccess;
		void *grayImage_d = 0;
		NSTimer kernelTime = NSTimer("kernelTime", false, false);
		NSTimer memoryTime = NSTimer("memoryTime", false, false);

		// Allocate device memory
		if ( (devRetVal = cudaMalloc(reinterpret_cast< void ** >(&grayImage_d), width * height * sizeof(unsigned char))) != cudaSuccess ) {
			cerr << "Impossible to allocate device memory for grayImage_d." << endl;
			return;
		}

		// Copy input to device
		memoryTime.start();
		if ( (devRetVal = cudaMemcpy(grayImage_d, reinterpret_cast< void * >(grayImage), width * height * sizeof(unsigned char), cudaMemcpyHostToDevice)) != cudaSuccess ) {
			cerr << "Impossible to copy grayImage_d to device." << endl;
			return;
		}
		memoryTime.stop();
		timer.stop();
		timer.start();


		dim3 gridSize = dim3(static_cast< unsigned int >(ceil(width / static_cast< float >(nrThreads))), height);
		dim3 blockSize = dim3(nrThreads);

		unsigned int i = 0;

		while ( (i < HISTOGRAM_SIZE) && (histogram[i] < CONTRAST_THRESHOLD) ) {
			i++;
		}
		unsigned int min = i;

		i = HISTOGRAM_SIZE - 1;
		while ( (i > min) && (histogram[i] < CONTRAST_THRESHOLD) ) {
			i--;
		}
		unsigned int max = i;

		kernelTime.start();
		contrast1DCUDA<<< gridSize, blockSize >>>(reinterpret_cast< unsigned char * >(grayImage_d), width, height, max, min);
		cudaDeviceSynchronize();
		kernelTime.stop();

		if ( (devRetVal = cudaMemcpy(reinterpret_cast< void * >(grayImage), grayImage_d, height * width * sizeof(unsigned char), cudaMemcpyDeviceToHost)) != cudaSuccess ) {
			cerr << "Impossible to copy grayImage_d to host." << endl;
			return;
		}
		timer.stop();

		cudaFree(grayImage_d);

		timer.start();

		cout << fixed << setprecision(6);
		cout << "contrast1D (kernel): \t\t" << kernelTime.getElapsed() << " seconds." << endl;
		cout << "contrast1D (memory): \t\t" << memoryTime.getElapsed() << " seconds." << endl;
}

void triangularSmooth(unsigned char *grayImage, unsigned char *smoothImage, const int width, const int height, float *filter, NSTimer &timer) {
		cudaError_t devRetVal = cudaSuccess;
		void *grayImage_d = 0;
		void *smoothImage_d = 0;
		void *filter_d = 0;
		const int filterSize = sizeof(filter);
		NSTimer kernelTime = NSTimer("kernelTime", false, false);
		NSTimer memoryTime = NSTimer("memoryTime", false, false);

		// Allocate device memory
		if ( (devRetVal = cudaMalloc(reinterpret_cast< void ** >(&grayImage_d), width * height * sizeof(unsigned char))) != cudaSuccess ) {
			cerr << "Impossible to allocate device memory for grayImage_d." << endl;
			return;
		}
		if ( (devRetVal = cudaMalloc(reinterpret_cast< void ** >(&smoothImage_d), width * height * sizeof(unsigned char))) != cudaSuccess ) {
			cerr << "Impossible to allocate device memory for smoothImage_d." << endl;
			return;
		}
		if ( (devRetVal = cudaMalloc(reinterpret_cast<void ** >(&filter_d), filterHeight * filterWidth * sizeof(float))) != cudaSuccess ) {
			cerr << "Impossible to allocate device memory for filter_d." << endl;
			return;
		}
		// Copy input to device
		memoryTime.start();
		if ( (devRetVal = cudaMemcpy(grayImage_d, reinterpret_cast< void * >(grayImage), width * height * sizeof(unsigned char), cudaMemcpyHostToDevice)) != cudaSuccess ) {
			cerr << "Impossible to copy grayImage_d to device." << endl;
			return;
		}
		if ( (devRetVal = cudaMemcpy(filter_d, reinterpret_cast<void * >(filter), filterHeight * filterWidth *  sizeof(float), cudaMemcpyHostToDevice)) != cudaSuccess ) {
			cerr << "Impossible to copy filter_d to device." << endl;
			return;
		}
		memoryTime.stop();
		timer.stop();
		if ( (devRetVal = cudaMemset(smoothImage_d, 0, width * height * sizeof(unsigned char))) != cudaSuccess ) {
			cerr << "Impossible to clean smoothImage_d." << endl;
			return;
		}
		timer.start();


		dim3 gridSize = dim3(static_cast< unsigned int >(ceil(width / static_cast< float >(nrThreads))), height);
		dim3 blockSize = dim3(nrThreads);
		kernelTime.start();
		triangularSmoothCUDA<<< gridSize, blockSize >>>(reinterpret_cast< unsigned char * >(grayImage_d), reinterpret_cast< unsigned char * >(smoothImage_d), width, height, reinterpret_cast<float * >(filter_d));
		cudaDeviceSynchronize();
		kernelTime.stop();

		// Copy back to host
		timer.stop();
		if ( (devRetVal = cudaMemcpy(reinterpret_cast< void * >(smoothImage), smoothImage_d, width * height * sizeof(unsigned char), cudaMemcpyDeviceToHost)) != cudaSuccess ) {
			cerr << "Impossible to copy smoothImage_d to host." << endl;
			return;
		}

		cudaFree(grayImage_d);
		cudaFree(smoothImage_d);
		cudaFree(filter_d);
		timer.start();

		cout << fixed << setprecision(6);
		cout << "triangularSmooth (kernel): \t\t" << kernelTime.getElapsed() << " seconds." << endl;
		cout << "triangularSmooth (memory): \t\t" << memoryTime.getElapsed() << " seconds." << endl;

}
