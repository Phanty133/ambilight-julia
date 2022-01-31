include("modules/Screen.jl")
include("modules/Calc.jl")
include("modules/Led.jl")
include("modules/Processing.jl")

using BenchmarkTools
import .Processing
import .Screen
import .Led

checkHeight = 100
sectorCount = [22, 12, 22, 12] # Top, Right, Bottom, Left
serial = "/dev/ttyACM0"
monitor = 2

Processing.init(monitor, checkHeight, sectorCount, serial)

samples = 0
frameTimes = Array{Float64, 1}(undef, 1)

while true
	@btime Processing.updateCPU()
end
