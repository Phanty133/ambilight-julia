__precompile__()

module Led
	include("Types.jl")

	using PyCall
	using .Types

	serial = pyimport("serial")
	sectorCount = Array{Int32}(undef, 4)
	ledOffsets = Array{Int32}(undef, 4)
	previousFrame = undef
	colorThreshold = 5
	ledCount = 0

	function initSerial(port, sectors)
		global uc = serial.Serial(port, 115200, timeout=0.2)
		global sectorCount = sectors
		global ledCount = sum(sectorCount)

		for i in 1:4
			ledOffsets[i] = sum(sectorCount[2:i])
		end
	end

	function clearFrame()
		for i in 1:ledCount
			uc.write([UInt8(i), 0xFF, 0xFF, 0xFF])
		end

		uc.write([0xFF])
		global previousFrame = fill((0xFF, 0xFF, 0xFF), ledCount)
	end

	function sendFrame(data::Vector{RGB})
		for i in 1:size(data, 1)
			p = data[i]

			if (previousFrame != undef)
				if (isColorSimilar(p, previousFrame[i]))
					continue
				end
			end

			uc.write(UInt8.([i - 1, p[1], p[2], p[3]]))
		end

		uc.write([0xFF])
		global previousFrame = data
	end

	function isColorSimilar(a::RGB, b::RGB, threshold = 5)
		return (
		   abs(convert(Int32, a[1]) - b[1]) <= threshold
		&& abs(convert(Int32, a[2]) - b[2]) <= threshold
		&& abs(convert(Int32, a[3]) - b[3]) <= threshold
		)
	end

	export sendFrame, initSerial
end