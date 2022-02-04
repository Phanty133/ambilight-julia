__precompile__()

module Led
	include("./Types.jl")

	using PyCall
	using .Types

	struct LedConfig
		uc::PyObject
		sectors::Vector{Int}
		ledCount::Int
		ledOffsets::Vector{Int}
		colorSimilarityThreshold::Int
	end

	function init_serial(port, sectors, colorSimilarityThreshold = 5)
		uc = pyimport("serial").Serial(port, 115200, timeout=0.2)
		ledOffsets = Array{Int}(undef, 4)

		for i in 1:4
			ledOffsets[i] = sum(sectors[2:i])
		end

		return LedConfig(
			uc,
			sectors,
			sum(sectors),
			ledOffsets,
			colorSimilarityThreshold
		)
	end

	function clear_frame(config::LedConfig)::Vector{RGB}
		for i in 1:config.ledCount
			config.uc.write([UInt8(i), 0xFF, 0xFF, 0xFF])
		end

		config.uc.write([0xFF])
		return fill((0xFF, 0xFF, 0xFF), config.ledCount)
	end

	function send_frame(config::LedConfig, data::Vector{RGB}, previousFrame=Vector{RGB}())::Vector{RGB}
		for i in 1:size(data, 1)
			p = data[i]

			if (length(previousFrame) >= i)
				if (isColorSimilar(p, previousFrame[i], config.colorSimilarityThreshold))
					continue
				end
			end

			config.uc.write(UInt8.([i - 1, p[1], p[2], p[3]]))
		end

		config.uc.write([0xFF])
		return data
	end

	function isColorSimilar(a::RGB, b::RGB, threshold = 5)
		return (
		   abs(convert(Int32, a[1]) - b[1]) <= threshold
		&& abs(convert(Int32, a[2]) - b[2]) <= threshold
		&& abs(convert(Int32, a[3]) - b[3]) <= threshold
		)
	end

	export init_serial, clear_frame, send_frame, LedConfig
end