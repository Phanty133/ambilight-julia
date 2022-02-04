#define ITER 4

__kernel void avg(__global const int *opts,
				  __global const uchar *raw,
				  __global int *out)
{
	int gid = get_global_id(0);
	int pixelIndex = gid + 1;
	int channelIndex = gid * ITER;
		
	uchar b = raw[channelIndex];
	uchar g = raw[channelIndex + 1];
	uchar r = raw[channelIndex + 2];
	int cMax = max(max(b, g), r);
		
	if (cMax <= 30) { // Skip black pixels
		// printf('black');
		return;
	}
		
	int col = pixelIndex % opts[0];
	int row = floor((float)pixelIndex / opts[0]);
	int sector = 0;
	int area = 0;

	if (row < opts[2]) { // Top area
		area = 0;
		sector = floor((float)col / opts[6]);
	} else if (row >= opts[3]) { // Bottom area
		area = 1;
		sector = opts[13] - floor((float)col / opts[8]) + opts[11];
	} else if (col < opts[4]) { // Left area
		area = 2;
		sector = opts[14] - floor((float)(row - opts[2]) / opts[9]) + opts[12];
	} else if (col >= opts[5]) { // Right area
		area = 3;
		sector = floor((float)(row - opts[2]) / opts[7]) + opts[10];
	} else {
		return;
	}

	int cMin = min(min(b, g), r);
	int sat = 1;
	int offset = sector * 4;

	// atom_add(&out[offset], 1);
	atom_add(&out[offset], area == 0 || area == 3 ? 255 : 0);
	atom_add(&out[offset + 1], area == 1 ? 255 : 0);
	atom_add(&out[offset + 2], area == 2 || area == 3 ? 255 : 0);
	atom_add(&out[offset + 3], sat);
}