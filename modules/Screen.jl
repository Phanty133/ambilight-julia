__precompile__()

module Screen
	include("./Types.jl")

	using PyCall
	using OpenCL
	using .Types

	mss = pyimport("mss")
	sct = mss.mss()

	checkHeight = 100
	monitorNr = 1
	sectorCount = Array{Int32}(undef, 4) # top, right, bottom, left
	totalSectors = 0
	minNonblack = 0

	monitorSize = [0, 0]
	areas = []

	gpuOpts = Vector{Int32}()
	device, ctx, queue = cl.create_compute_context()
	kernel = read("./kernel.c", String)
	p = cl.Program(ctx, source=kernel) |> cl.build!
	k = cl.Kernel(p, "avg")

	function configScreenGrab(monitor, height, sectors, minNonblackPixels=100)
		global checkHeight = height
		global monitorNr = monitor
		global sectorCount = sectors
		global totalSectors = sum(sectorCount)
		global minNonblack = minNonblackPixels

		# CPU Processing stuff
		global monitorSize = [ sct.monitors[monitorNr]["height"], sct.monitors[monitorNr]["width"] ]
		global areas = [
			Dict([("top", 0), ("left", 0), ("width", monitorSize[2]), ("height", checkHeight)]), # Top bar
			Dict([("top", checkHeight), ("left", monitorSize[2] - checkHeight), ("width", checkHeight), ("height", monitorSize[1] - 2 * checkHeight)]), # Right bar
			Dict([("top", monitorSize[1] - checkHeight), ("left", 0), ("width", monitorSize[2]), ("height", checkHeight)]), # Bottom bar
			Dict([("top", checkHeight), ("left", 0), ("width", checkHeight), ("height", monitorSize[1] - 2 * checkHeight)]), # Left bar
		]

		# GPU Processing stuff
		global gpuOpts = Vector{Int32}([
			monitorSize[2], # Screen width
			monitorSize[1], # Screen height
			checkHeight, # Ignore min vertical
			monitorSize[1] - checkHeight, # Ignore max vertical
			checkHeight, # Ignore min horizontal
			monitorSize[2] - checkHeight, # Ignore max horizontal
			Int32(floor(monitorSize[2] / sectorCount[1])), # Sector width top
			Int32(floor((monitorSize[1] - 2 * checkHeight) / sectorCount[2])), # Sector heigh right
			Int32(floor(monitorSize[2] / sectorCount[3])), # Sector width bottom
			Int32(floor((monitorSize[1] - 2 * checkHeight) / sectorCount[4])), # Sector height left
			sectorCount[1], # Sector offset right
			sum(sectorCount[1:2]), # Sector offset bottom
			sum(sectorCount[1:3]), # Sector offset left
			sectorCount[3], # Sector bottom count
			sectorCount[4], # Sector left count
			20 # Black threshold
		])
		global gpuSectorZeros = zeros(Int32, totalSectors * 5)
	end

	# GPU

	function processScreenGPU()
		screenshot = sct.grab(sct.monitors[monitorNr])

		opts_buff = cl.Buffer(Int32, ctx, (:r, :copy), hostbuf=gpuOpts)
		raw_buff = cl.Buffer(UInt8, ctx, (:r, :copy), hostbuf=screenshot.raw)
		out_buff = cl.Buffer(Int32, ctx, (:rw, :copy), hostbuf=gpuSectorZeros)

		queue(k, monitorSize[1] * monitorSize[2], nothing, opts_buff, raw_buff, out_buff)
		r = cl.read(queue, out_buff)
		
		avgColors = Vector{RGB}()

		for i in 1:5:size(r, 1)
			sat = r[i + 3]

			if r[i + 4] < minNonblack
				color = (0,0,0)
			elseif (sat == 0)
				color = (0,0,0)
			else
				color = UInt8.((
					round(Int, r[i] / sat),
					round(Int, r[i + 1] / sat),
					round(Int, r[i + 2] / sat)
				))
			end

			push!(avgColors, color)
		end

		return avgColors
	end

	# CPU

	function getAreaFromData(data, area)
		minRow = areas[area]["top"] + 1
		maxRow = areas[area]["top"] + areas[area]["height"]
		minCol = areas[area]["left"] + 1
		maxCol = areas[area]["left"] + areas[area]["width"]
	
		return data[minRow:maxRow,minCol:maxCol,:]
	end
	
	function getSectorsFromArea(data, area)
		sectorSize = Tuple{Int32, Int32}([1,1])
		
		if (area == 1 || area == 3) # Horizontal areas
			w::Int32 = floor(areas[area]["width"] / sectorCount[area])
			sectorSize = (areas[area]["height"], w)
		else # Vertical Areas
			h::Int32 = floor(areas[area]["height"] / sectorCount[area])
			sectorSize = (h, areas[area]["width"])
		end
	
		sectors = Matrix{UInt8}[]
	
		for i in 1:sectorCount[area]
			areaRowMin = 0
			areaRowMax = 0
			areaColMin = 0
			areaColMax = 0
			
			if (area == 1 || area == 3)
				areaRowMin = 1
				areaRowMax = sectorSize[1]
				areaColMin = (i - 1) * sectorSize[2] + 1
				areaColMax = i * sectorSize[2]
			else
				areaRowMin = (i - 1) * sectorSize[1] + 1
				areaRowMax = i * sectorSize[1]
				areaColMin = 1
				areaColMax = sectorSize[2]
			end
			
			dataArea = data[areaRowMin:areaRowMax, areaColMin:areaColMax, :]
			reshapedArea = reshape(dataArea, (sectorSize[1] * sectorSize[2], 4))
			push!(sectors, reshapedArea)
		end
	
		return sectors
	end
	
	function grabScreen()
		screenshot = sct.grab(sct.monitors[monitorNr])
		rawData = screenshot.raw # H * W * 4, BGRA
		data = permutedims(reshape(rawData, (4, monitorSize[2], monitorSize[1])), (3, 2, 1)) # 14 ms!!!!!!
		return data
	end

	export grabScreen, gerAreaFromData, getSectorsFromArea, processScreenGPU
end