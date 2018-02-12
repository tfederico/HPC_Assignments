import pandas as pd
import numpy as np
import matplotlib.pyplot as plt

filename = "res_cartesius"

colors = ['g','b','y','r','m','c','k','g','b','y']
lines = ['^','^','^','^','^','^','^','s','s','s']

data = pd.read_csv(filename+".csv",header=0)

length = data["length"].values
length = [float(l)/5000 for l in length]
steps = data["steps"].values
steps = [float(s) for s in steps]
ns = data["nanoseconds"].values
ns = [float(s) for s in ns]
threads = data["threads"].values
threads = [int(t) for t in threads]



for j in range(0,5):
	plt.figure(j*5)

	index = [i for i, x in enumerate(threads) if x == 2**(j+1)]
	#print(index)
	sublength = [length[i] for i in index]
	substeps = [steps[i] for i in index]
	subns = [ns[i] for i in index]

	for i in range(0,10):
		plt.semilogy(sublength[i::10],subns[i::10],linestyle='--', marker=lines[i], color=colors[i], label=str(substeps[i]))

	plt.xlabel('Array length (5x10^3)')
	plt.ylabel('Time (nanoseconds)')
	#plt.title('Execution time ('+str(2**(j+1))+' threads)')
	plt.xlim(10,100)
	plt.ylim(10**5,10**8)
	leg0 = plt.legend(title="Number of steps",loc='lower center',ncol=5, fancybox=True)
	leg0.get_frame().set_alpha(0.5)
	plt.savefig('array_thread_'+str(2**(j+1))+'_length_'+filename,bbox_inches='tight')

	plt.figure(j*5+1)

	for i in range(0,10):
		plt.semilogy(substeps[i*10:(i+1)*10],subns[i*10:(i+1)*10],linestyle='--', marker=lines[i], color=colors[i], label=str(sublength[10*i]))

	plt.xlabel('Steps')
	plt.ylabel('Time (nanoseconds)')
	#plt.title('Execution time ('+str(2**(j+1))+' threads)')
	plt.xlim(10,100)
	plt.ylim(10**5,10**8)
	leg1 = plt.legend(title="Array length (5x10^3)",loc='lower center',ncol=5, fancybox=True)
	leg1.get_frame().set_alpha(0.5)
	plt.savefig('array_thread_'+str(2**(j+1))+'_steps_'+filename,bbox_inches='tight')
