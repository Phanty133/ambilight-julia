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
			Int32(floor((monitorSize["height"] - 2 * height) / sectors[2])), # Sector heigh right
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

		gpuContext = init_kernel()

		return ScreenConfig(
			sct,
			height,
			monitor,
			sectors,
			gpuContext,
			gpuOpts
		)
	end

	function parse_data(r::Array{Int32, 1})
		avgColors = Vector{RGB}()

		for i in 1:5:size(r, 1)
			sat = r[i + 3]

			if (sat == 0)
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

	function process_screen_gpu(config::ScreenConfig)
		screenshot = config.sct.grab(config.sct.monitors[config.monitor])
		rawData = process_data(config.gpuContext, config.gpuOpts, screenshot.raw)
		return parse_data(rawData)
	end

	export ScreenConfig, config_screen, process_screen_gpu
end