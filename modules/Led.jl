__precompile__()

module Led
	include("Types.jl")

	using PyCall
	using .Types

	serial = pyimport("serial")
	sectorCount = Array{Int32}(undef, 4)
	ledOffsets = Array{Int32}(undef, 4)
	previousFrame = Vector{RGB}(undef, 1)
	colorThreshold = 5
	ledCount = 0

	function initSerial(port, sectors)
		global uc = serial.Serial(port, 115200, timeout=0.2)
		global sectorCount = sectors
		global ledCount = sum(sectorCount)

		for i in 1:4
			ledOffsets[i] = sum(sectorCount[2:i])
		end

		defaultColor::RGB = (0, 0, 0)
		global previousFrame = fill(defaultColor, ledCount)
	end

	function clearFrame()
		for i in 1:ledCount
			uc.write([UInt8(i), 0xFF, 0xFF, 0xFF])
		end

		uc.write([0xFF])
	end

	function sendFrame(data::Vector{RGB})
		ucData = Array{UInt8}(undef, size(data, 1))

		for i in 1:size(data, 1)
			p = data[i]

			if (i <= size(previousFrame, 1))
				if (isColorSimilar(p, previousFrame[i]))
					continue
				end
			end

			# append!(ucData, UInt8.([i - 1, p[1], p[2], p[3]]))
			uc.write(UInt8.([i - 1, p[1], p[2], p[3]]))
		end

		# append!(ucData, 0xFF)
		# uc.write(ucData)
		uc.write([0xFF])
		global previousFrame = data
	end

	function isColorSimilar(a::RGB, b::RGB)
		return !(abs(a[1] - b[1]) > colorThreshold
		|| abs(a[2] - b[2]) > colorThreshold
		|| abs(a[3] - b[3]) > colorThreshold)
	end

	export sendFrame, initSerial
end