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

	monitorSize = [0, 0]
	areas = []

	gpuOpts = Vector{Int32}()
	device, ctx, queue = cl.create_compute_context()
	kernel = "
		#define ITER 4

		__kernel void avg(__global const int *opts,
						  __global const uchar *raw,
						  __global int *out)
		{
			int gid = get_global_id(0);
			int pixelIndex = gid + 1;
			int channelIndex = gid * ITER;
		
			uchar b = raw[channelIndex];
			uchar g = raw[channelIndex + 1];
			uchar r = raw[channelIndex + 2];
			int cMax = max(max(b, g), r);
		
			if (cMax == 0) { // Skip black pixels
				return;
			}
		
			int col = pixelIndex % opts[0];
			int row = floor((float)pixelIndex / opts[0]);
			int sector = 0;
		
			if (row < opts[2]) { // Top area
				sector = floor((float)col / opts[6]);
			} else if (row >= opts[3]) { // Bottom area
				sector = opts[13] - floor((float)col / opts[8]) + opts[11];
			} else if (col < opts[4]) { // Left area
				sector = opts[14] - floor((float)(row - opts[2]) / opts[9]) + opts[12];
			} else if (col >= opts[5]) { // Right area
				sector = floor((float)(row - opts[2]) / opts[7]) + opts[10];
			} else {
				return;
			}

			int cMin = min(min(b, g), r);
			int sat = ((cMax - cMin) / (float)cMax) * 100;
			int offset = sector * 4;

			// atom_add(&out[offset], 1);
			atom_add(&out[offset], r * sat);
			atom_add(&out[offset + 1], g * sat);
			atom_add(&out[offset + 2], b * sat);
			atom_add(&out[offset + 3], sat);
		}
	"

	p = cl.Program(ctx, source=kernel) |> cl.build!
	k = cl.Kernel(p, "avg")

	function configScreenGrab(monitor, height, sectors)
		global checkHeight = height
		global monitorNr = monitor
		global sectorCount = sectors
		global totalSectors = sum(sectorCount)

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
			monitorSize[2],
			monitorSize[1],
			checkHeight,
			monitorSize[1] - checkHeight,
			checkHeight,
			monitorSize[2] - checkHeight,
			Int32(floor(monitorSize[2] / sectorCount[1])),
			Int32(floor((monitorSize[1] - 2 * checkHeight) / sectorCount[2])),
			Int32(floor(monitorSize[2] / sectorCount[3])),
			Int32(floor((monitorSize[1] - 2 * checkHeight) / sectorCount[4])),
			sectorCount[1],
			sum(sectorCount[1:2]),
			sum(sectorCount[1:3]),
			sectorCount[3],
			sectorCount[4]
		])
		global gpuSectorZeros = zeros(Int32, totalSectors * 4)
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

		for i in 1:4:size(r, 1)
			sat = r[i + 3]

			if (sat == 0)
				continue
			end

			color = UInt8.((
				round(Int, r[i] / sat),
				round(Int, r[i + 1] / sat),
				round(Int, r[i + 2] / sat)
			))

			push!(avgColors, color)
		end

		return avgColors
	end

	# CPU

	function processScreenCPU()
		raw = sct.grab(sct.monitors[monitorNr]).raw
		output = zeros(Float32, totalSectors)

		Threads.@threads for i in 1:(monitorSize[1] * monitorSize[2] - 1)
			channelIndex = i * 4
			b = raw[channelIndex]
			g = raw[channelIndex + 1]
			r = raw[channelIndex + 2]

			cMax = max(r, g, b)

			if (cMax == 0)
				continue
			end

			col = i % monitorSize[2]
			row = floor(i / monitorSize[2])
			sector = 0

			if (row < gpuOpts[2])
				sector = floor(col / gpuOpts[6])
			elseif (row >= gpuOpts[3])
				sector = gpuOpts[13] - floor(col / gpuOpts[8]) + gpuOpts[11]
			elseif (col < gpuOpts[4])
				sector = gpuOpts[14] - floor((row - gpuOpts[2]) / gpuOpts[9]) + gpuOpts[12]
			elseif (col >= gpuOpts[5])
				sector = floor((row - gpuOpts[2]) / gpuOpts[7]) + gpuOpts[10]
			else
				continue
			end

			cMin = min(r, g, b)
			sat = (cMax - cMin) / cMax
			offset = trunc(Int, (sector + 1) * 4)

			output[offset] += r * sat
			output[offset + 1] += g * sat
			output[offset + 2] += b * sat
			output[offset + 3] += sat
		end

		avgColors = Vector{RGB}()

		for i in 1:4:size(output, 1)
			sat = output[i + 3]

			if (sat == 0)
				continue
			end

			color = UInt8.((
				round(Int, output[i] / sat),
				round(Int, output[i + 1] / sat),
				round(Int, output[i + 2] / sat)
			))

			push!(avgColors, color)
		end

		return avgColors
	end

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