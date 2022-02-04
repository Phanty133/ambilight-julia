__precompile__()

module Processing
	include("./Screen.jl")
	include("./Led.jl")
	include("./Types.jl")

	using .Screen
	using .Led
	using .Types

	struct ProcessingConfig
		screenConfig::ScreenConfig
		ledConfig::LedConfig
	end

	function init_processing(monitorNr::Int, checkHeight::Int, sectorCount::Vector{Int}, serial::String)
		scrConfig = config_screen(monitorNr, checkHeight, sectorCount)
		ledConfig = init_serial(serial, sectorCount)
		clear_frame(ledConfig)

		return ProcessingConfig(scrConfig, ledConfig)
	end

	function update_frame(config::ProcessingConfig, prevFrame = Vector{RGB}())::Vector{RGB}
		frameData = process_screen_gpu(config.screenConfig)
		send_frame(config.ledConfig, frameData, prevFrame)
	end

	function start_processing(config::ProcessingConfig, maxFps::Int)
		prevFrame = Vector{RGB}()
		frameTimes = Vector{Float32}()
		maxFrametime = 1 / maxFps
		avgTime = 0

		while true
			start = time()

			prevFrame = update_frame(config, prevFrame)

			push!(frameTimes, time() - start)

			if (length(frameTimes) >= 10)
				deleteat!(frameTimes, 1)
			end

			avgTime = sum(frameTimes) / size(frameTimes, 1)

			if (avgTime < maxFrametime)
				sleep(maxFrametime - avgTime)
			end
		end
	end

	export init_processing, start_processing
end