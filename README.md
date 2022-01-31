# ambilight-julia
A Philips Ambilight knockoff implemented in Julia + Arduino. Colors for each LED/sector are calculated with a weighted arithmentic mean, where the weight is the saturation of the pixel.

## Software:
Two processing algorithms are available:
1. GPU version (default) - Avg. frame time 8ms, Avg. Mem. consumption 7MiB (Tested on R9 Fury X + Pentium G4620, 68 LEDs, 1920x1080)
2. Multithreaded CPU version - Avg. frame time 35ms, Avg. Mem. consumption 55MiB (Tested on Pentium G4620, 68 LEDs, 1920x1080)

## Hardware:
An Arduino Pro Micro + WS2813 LED strip
