__precompile__()

module Processing
	include("Screen.jl")
	include("Calc.jl")
	include("Led.jl")

	using Base.Iterators
	using BenchmarkTools
	import .Screen
	import .Led

	function init(monitorNr::Number, checkHeight::Number, sectorCount::Vector{Int64}, serial::String)
		Screen.configScreenGrab(monitorNr, checkHeight, sectorCount)
		Led.initSerial(serial, sectorCount)
		Led.clearFrame()
	end

	function updateGPU()  # 8ish ms frame time
		colors = Screen.processScreenGPU()
		Led.sendFrame(colors)
	end

	function update() # 35ish ms frame time
		screen = Screen.grabScreen()
		areas = [ Screen.getAreaFromData(screen, i) for i in 1:4 ]
		sectors = [ Screen.getSectorsFromArea(areas[i], i) for i in 1:4 ]

		# Reverse bottom and right as the LEDs go in the opposite direction of the sector numbering
		reverse!(sectors[3])
		reverse!(sectors[4])

		sectorsFlat = reduce(vcat, sectors)

		colors = Array{Tuple{UInt8, UInt8, UInt8}}(undef, size(sectorsFlat, 1))

		Threads.@threads for i = 1:size(sectorsFlat, 1)
			colors[i] = Calc.averageColor(sectorsFlat[i])
		end

		Led.sendFrame(colors)
	end

	export update, updateGPU
end