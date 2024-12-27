# This file contains the implementation of the Adaptive Notch Filter (ANF)
# with a fixed rho. The ANF is used to remove a sinusoidal interference from
# a signal.

import numpy as np
import matplotlib.pyplot as plt
import soundfile as sf


write_to_file_flag = True  # Flag to write input signal to file

##############################################################################
# Input signal creation
##############################################################################
# fs = 8000  # Sampling frequency
# freqs = [1000, 1600]  # Frequencies to filter out

# t = np.arange(0, fs) / fs  # Time vector
# amplitude = 0.5  # Amplitude of input signal

# # Create input signal
# signal = amplitude * np.concatenate(
#     ((np.sin(2 * np.pi * freqs[0] * t), np.sin(2 * np.pi * freqs[1] * t))))

# N = len(signal)  # Number of samples in signal

# # Add noise to input signal
# stdev = 0.05
# noise = np.random.normal(0, stdev, N)  # Noise vector
# signal = signal + noise  # Noisy signal

audio_file = "audio/rain.wav"
audio_data, fs = sf.read(audio_file)
signal = 0.5*audio_data[:, 0] #select the left channel
N = len(signal) #number of samples in signal

##############################################################################
# Simulation of adaptive notch filter (ANF) with fixed rho
##############################################################################

# Initializations
e = np.zeros(N)  # ANF output signal vector
s = np.zeros(3)  # ANF state vector
a = np.zeros(N)  # ANF coefficient vector (for debugging only)

a_i = 1  # initialization of ANF parameter
rho = 0.8  # fixed rho
mu = 2 * 100 / (2 ** 15)  # 2 * mu

# Simulation loop (iterations over time)
for i in range(N):
    s[2] = s[1]
    s[1] = s[0]
    s[0] = signal[i] + rho * a_i * s[1] - (rho ** 2) * s[2]
    e[i] = s[0] - a_i * s[1] + s[2]
    a_i = a_i + 2 * mu * s[1] * e[i]
    a[i] = a_i

# Plot results
plt.figure()
plt.plot(signal)
plt.plot(e)
plt.title('Second order ANF with fixed rho')
plt.xlabel('Sample')
plt.ylabel('Amplitude')
plt.legend(['Signal', 'ANF output'])

plt.figure(figsize=(6,4))
plt.specgram(signal, Fs=8000)
plt.xlabel("Time [s]")
plt.ylabel("Frequency [Hz]")
plt.title("Spectrogram before Filtering")

plt.figure(figsize=(6,4))
plt.specgram(e, Fs=8000)
plt.xlabel("Time [s]")
plt.ylabel("Frequency [Hz]")
plt.title("Spectrogram after Filtering")

# Plot convergence of ANF parameter
plt.figure()
plt.plot(a)
plt.title('Convergence of ANF parameter')
plt.xlabel('Sample')
plt.ylabel('ANF coefficient')
plt.show()

##############################################################################
# Write input signal to file
##############################################################################
if write_to_file_flag:
    import file_parser as fp
    q_factor = 15
    signal_q = np.round(signal * (2 ** q_factor)).astype(np.int16)
    datapath = '../CCS_StartFiles/Assignment_2/data/rain.pcm'
    fp.writes(signal_q, datapath)
