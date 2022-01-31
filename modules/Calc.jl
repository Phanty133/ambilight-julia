__precompile__()

module Calc
	include("Types.jl")

	using .Types

	function valueFromRGB(rgb::RGB)::UInt8 # Gets the V of HSV from RGB
		return max(rgb[1], rgb[2], rgb[3])
	end

	function saturationFromRGB(rgb::RGB)
		cMin = min(rgb[1], rgb[2], rgb[3])
		cMax = max(rgb[1], rgb[2], rgb[3])
		
		return cMax == 0 ? 0 : ((cMax - cMin) / cMax)
	end

	function averageColor(sector::Matrix{UInt8})::RGB
		# 1. Sum each color component inidividually * V weight
		# 2. Divide each color component's sum by the sum of V weights

		vSum = 0
		rSum = 0
		gSum = 0
		bSum = 0

		for i in 1:size(sector, 1)
			p = sector[i,:]
			v = saturationFromRGB((p[3], p[2], p[1]))
			vSum += v
			rSum += p[3] * v
			gSum += p[2] * v
			bSum += p[1] * v
		end

		if vSum == 0
			return (0, 0, 0)
		end

		return round.((rSum, gSum, bSum) ./ vSum)
	end
end