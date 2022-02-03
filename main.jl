include("modules/Screen.jl")
include("modules/Calc.jl")
include("modules/Led.jl")
include("modules/Processing.jl")

using BenchmarkTools
import .Processing
import .Screen
import .Led

checkHeight = 100
sectorCount = [22, 12, 21, 13] # Top, Right, Bottom, Left
serial = "/dev/ttyACM0"
monitor = 2
frameLimiter = 24

Processing.init(monitor, checkHeight, sectorCount, serial)
Processing.updateGPU()

frameTimes = Vector{Float32}(undef, 1)
maxFrametime = 1 / frameLimiter
avgTime = 0

function execute()
	start = time()
	Processing.updateGPU()
	
	push!(frameTimes, time() - start)

	if (size(frameTimes, 1) >= 10)
		deleteat!(frameTimes, 1)
	end

	avgTime = sum(frameTimes) / size(frameTimes, 1)

	if (avgTime < maxFrametime)
		println(maxFrametime - avgTime)
		sleep(maxFrametime - avgTime)
	end
end

function run()
	while true
		execute()
	end
end

run()
