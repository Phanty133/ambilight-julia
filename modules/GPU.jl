module GPU
	using OpenCL

	struct GPUOpts
		scr_width::Int32
		scr_height::Int32
		ignore_vertical_min::Int32
		ignore_vertical_max::Int32
		ignore_horizontal_min::Int32
		ignore_horizontal_max::Int32
		sector_width_top::Int32
		sector_width_right::Int32
		sector_width_bottom::Int32
		sector_width_left::Int32
		sector_offset_top::Int32
		sector_offset_right::Int32
		sector_offset_bottom::Int32
		sector_offset_left::Int32
		sector_count_bottom::Int32
		sector_count_left::Int32
		sector_total::Int32
	end

	struct GPUContext
		device::cl.Device
		ctx::cl.Context
		queue::cl.CmdQueue
		kernel::cl.Kernel
	end

	export GPUOpts, GPUContext

	function init_kernel()
		bin = Array{UInt8, 1}(undef, filesize("./bin/kernel.bin"))

		open("./bin/kernel.bin", "r") do f
			read!(f, bin)
		end

		device, ctx, queue = cl.create_compute_context()
		binaries = Dict(device => bin)
		p = cl.Program(ctx, binaries=binaries) |> cl.build!
		k = cl.Kernel(p, "avg")

		return GPUContext(device, ctx, queue, k)
	end

	function process_data(context::GPUContext, opts::GPUOpts, data::Array{UInt8, 1})
		zerosArr = zeros(Int32, opts.sector_total * 5)

		opts_buff = cl.Buffer(GPUOpts, context.ctx, (:r, :copy), hostbuf=[opts])
		raw_buff = cl.Buffer(UInt8, context.ctx, (:r, :copy), hostbuf=data)
		out_buff = cl.Buffer(Int32, context.ctx, (:rw, :copy), hostbuf=zerosArr)

		context.queue(context.kernel, opts.scr_height * opts.scr_width, nothing, opts_buff, raw_buff, out_buff)
		return cl.read(context.queue, out_buff)
	end

	export init_kernel, process_data
end