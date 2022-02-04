using OpenCL

function compile(input, output)
	device, ctx, queue = cl.create_compute_context()
	kernel = read(input, String)
	p = cl.Program(ctx, source=kernel) |> cl.build!
	bin = cl.info(p, Symbol("binaries"))

	write(output, bin[device])
end

compile("./kernel/kernel.cl", "./bin/kernel.bin")