import pandas as pd
import numpy as np
import matplotlib.pyplot as plt

filename = "res_seq"

colors = ['g','b','y','r','m','c','k','g','b','y']
lines = ['^','^','^','^','^','^','^','s','s','s']

data = pd.read_csv(filename+".csv",header=0)

length = data["length"].values
length = [float(l)/5000 for l in length]
steps = data["steps"].values
steps = [float(s) for s in steps]
ns = data["nanoseconds"].values
ns = [float(s) for s in ns]

plt.figure(0)

for i in range(0,10):
	plt.semilogy(length[i::10],ns[i::10],linestyle='--', marker=lines[i], color=colors[i], label=str(steps[i]))

plt.xlabel('Array length (5x10^3)')
plt.ylabel('Time (nanoseconds)')
#plt.title('Execution time')
plt.xlim(10,100)
plt.ylim(10**5,10**8)
leg0 = plt.legend(title="Number of steps",loc='lower center',ncol=5, fancybox=True)
leg0.get_frame().set_alpha(0.5)
plt.savefig('array_length_'+filename,bbox_inches='tight')

plt.figure(1)

for i in range(0,10):
	plt.semilogy(steps[i*10:(i+1)*10],ns[i*10:(i+1)*10],linestyle='--', marker=lines[i], color=colors[i], label=str(length[10*i]))

plt.xlabel('Steps')
plt.ylabel('Time (nanoseconds)')
#plt.title('Execution time')
plt.xlim(10,100)
plt.ylim(10**5,10**8)
leg1 = plt.legend(title="Array length (5x10^3)",loc='lower center',ncol=5, fancybox=True)
leg1.get_frame().set_alpha(0.5)
plt.savefig('array_steps_'+filename,bbox_inches='tight')
