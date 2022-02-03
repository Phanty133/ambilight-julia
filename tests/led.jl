using PyCall
using Test

function testSerial(port)
	serial = pyimport("serial")

	try
		uc = serial.Serial(port, 115200, timeout=0.2)
		return true
	catch e
		return false
	end
end

function testLEDs(port, leds)
	serial = pyimport("serial")
	uc::PyObject = undef

	try
		uc = serial.Serial(port, 115200, timeout=0.2)
	catch e
		return false
	end

	for i in 1:(leds + 1)
		uc.write([UInt8(i - 1), 0x00, 0x00, 0x00])
	end

	uc.write([0x00, 0xFF, 0x00, 0x00, 0xFF])

	for i in 1:(leds + 1)
		if (i != 1)
			uc.write([UInt8(i - 2), 0x00, 0x00, 0x00])
		end

		uc.write([UInt8(i - 1), 0xFF, 0x00, 0x00, 0xFF])
		sleep(0.1)
	end

	return true
end

@test testSerial("/dev/ttyACM0")
@test testLEDs("/dev/ttyACM0", 68)