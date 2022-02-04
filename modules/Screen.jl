__precompile__()

module Screen
	include("./Types.jl")
	include("./GPU.jl")

	using PyCall
	using OpenCL
	using .Types
	using .GPU
	
	struct ScreenConfig
		sct::PyObject
		checkHeight::Int
		monitor::Int
		sectors::Array{Int}
		gpuContext::GPUContext
		gpuOpts::GPUOpts
		sectorCount::Int
		sectorSize::Array{Int}
	end

	function config_screen(monitor, height, sectors)::ScreenConfig
		sct = pyimport("mss").mss()
		monitorSize = sct.monitors[monitor]

		gpuOpts = GPUOpts(
			Int32(monitorSize["width"]), # Screen width
			Int32(monitorSize["height"]), # Screen height
			Int32(height), # Ignore min vertical
			Int32(monitorSize["height"] - height), # Ignore max vertical
			Int32(height), # Ignore min horizontal
			Int32(monitorSize["width"] - height), # Ignore max horizontal
			Int32(floor(monitorSize["width"] / sectors[1])), # Sector width top
			Int32(floor((monitorSize["height"] - 2 * height) / sectors[2])), # Sector height right
			Int32(floor(monitorSize["width"] / sectors[3])), # Sector width bottom
			Int32(floor((monitorSize["height"] - 2 * height) / sectors[4])), # Sector height left
			0, # Sector offset top
			Int32(sectors[1]), # Sector offset right
			Int32(sum(sectors[1:2])), # Sector offset bottom
			Int32(sum(sectors[1:3])), # Sector offset left
			Int32(sectors[3]), # Sector bottom count
			Int32(sectors[4]), # Sector left count
			Int32(sum(sectors))
		)

		sectorSize = [
			gpuOpts.sector_width_top * height,
			gpuOpts.sector_width_right * height,
			gpuOpts.sector_width_bottom * height,
			gpuOpts.sector_width_left * height
		]

		gpuContext = init_kernel()

		return ScreenConfig(
			sct,
			height,
			monitor,
			sectors,
			gpuContext,
			gpuOpts,
			sum(sectors),
			sectorSize
		)
	end

	function get_sector(config::ScreenConfig, index::Int)
		if index > config.gpuOpts.sector_offset_left
			return 4
		elseif index > config.gpuOpts.sector_offset_bottom
			return 3
		elseif index > config.gpuOpts.sector_offset_right
			return 2	
		else
			return 1
		end
	end
	
	function hsv_to_rgb(h::Float64, s::Float64, v::Float64)::RGB
		c = v * s
		x = c * (1 - abs((h % 2) - 1))
		m = v - c
		col = [0, 0, 0]
		
		if h < 1
			col = (c, x, 0)
		elseif h < 2
			col = (x, c, 0)
		elseif h < 3
			col = (0, c, x)
		elseif h < 4
			col = (0, x, c)
		elseif h < 5
			col = (x, 0, c)
		else
			col = (c, 0, x)
		end

		return UInt8.(round.((col .+ m) .* 255))
	end

	function parse_data(config::ScreenConfig, raw::Array{Int32})
		avgColors = Array{RGB}(undef, config.sectorCount)

		@Threads.threads for i in 1:config.sectorCount
			offset = i * 4 - 3
			satWeight = raw[offset + 3]

			if satWeight == 0
				avgColors[i] = (0,0,0)
				continue
			end

			r = @fastmath(raw[offset] / satWeight / 255)
			g = @fastmath(raw[offset + 1] / satWeight / 255)
			b = @fastmath(raw[offset + 2] / satWeight / 255)

			cMin = min(r,g,b)
			cMax = max(r,g,b)
			delta = cMax - cMin
			sat = @fastmath((delta / cMax) ^ (1 / 2.5))

			hue = 0

			if cMax == r
				hue = @fastmath(((g - b) / delta) % 6)
			elseif cMax == g
				hue = @fastmath((b - r) / delta + 2)
			elseif cMax == b
				hue = @fastmath((r - g) / delta + 4)
			end

			avgColors[i] = hsv_to_rgb(abs(hue), sat, cMax)
		end

		return avgColors
	end

	function process_screen_gpu(config::ScreenConfig)
		screenshot = config.sct.grab(config.sct.monitors[config.monitor])
		rawData = process_data(config.gpuContext, config.gpuOpts, screenshot.raw)
		return parse_data(config, rawData)
	end

	export ScreenConfig, config_screen, process_screen_gpu
end