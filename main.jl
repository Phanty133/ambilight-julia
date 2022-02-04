include("modules/Processing.jl")

using BenchmarkTools
using .Processing

checkHeight = 100
sectors = [22, 12, 21, 13] # Top, Right, Bottom, Left
serialPort = "/dev/ttyACM0"
monitor = 2
frameLimiter = 60

config = init_processing(monitor, checkHeight, sectors, serialPort)
start_processing(config, frameLimiter)
