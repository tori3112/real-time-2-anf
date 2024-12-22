import numpy as np
import matplotlib.pyplot as plt
import os

def reads(datapath):
    # check that file exists
    if not os.path.isfile(datapath):
        raise ValueError('file does not exist')

    # read data from file in Little-endian ordering
    with open(datapath, 'rb') as f:
        data = np.fromfile(f, dtype=np.int16)
    return data

def plot_signals(input_signal, output_signal, sampling_rate=16000):
    """
    Plots the input and output signals.
    Parameters:
    - input_signal: Array of input signal values.
    - output_signal: Array of output signal values.
    - sampling_rate: Sampling rate of the signal in Hz (default: 16kHz).
    """
    # Plot results
    plt.figure()
    #plt.plot(output_signal)
    plt.plot(input_signal)
    plt.plot(output_signal)
    plt.title('Second order ANF with fixed rho')
    plt.xlabel('Sample')
    plt.ylabel('Amplitude')
    plt.legend(['Signal', 'ANF output'])

    plt.show()


    
# Paths to PCM files
datapath = "CCS_StartFiles/Assignment_2/data/"
input_pcm_path = datapath+"input.pcm"
output_pcm_path = datapath+ "output.pcm"

# Read signals from PCM files
input_signal = reads(input_pcm_path)
output_signal = reads(output_pcm_path)

# Normalize signals to Q15 range (-1 to 1)
input_signal_normalized = input_signal / (2**15)
output_signal_normalized = output_signal / (2**15)

# Plot signals
plot_signals(input_signal_normalized, output_signal_normalized)