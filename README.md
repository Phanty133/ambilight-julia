# ambilight-julia
A Philips Ambilight knockoff implemented in Julia + Arduino

## Software:
Two processing algorithms are available:
1. GPU verion (default) - Avg. frame time 8ms, Avg. Mem. consumption 7MiB (Tested on R9 Fury X, 68 LEDs, 1920x1080)
2. Multithreaded CPU version - Avg. frame time 35ms, Avg. Mem. consumption 55MiB (Tested on Pentium G4620, 68 LEDs, 1920x1080)

## Hardware:
An Arduino Pro Micro + WS2813 LED strip
