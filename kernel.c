// opts
// 0: Screen width
// 1: Screen height
// 2: Ignore min vertical
// 3: Ignore max vertical
// 4: Ignore min horizontal
// 5: Ignore max horizontal
// 6: Sector width top
// 7: Sector height right
// 8: Sector width bottom
// 9: Sector height left
// 10: Sector offset right
// 11: Sector offset bottom
// 12: Sector offset left
// 13: Sector bottom count
// 14: Sector left count
// 15: Black threshold	

// raw
// B G R A * W * H

// out
// RSum GSum BSum SatSum * SectorCount

#define ITER 4

__kernel void avg(__global const int *opts,
				  __global const uchar *raw,
				  __global int *out)
{
	int gid = get_global_id(0);
	int channelIndex = gid * ITER;
		
	uchar b = raw[channelIndex];
	uchar g = raw[channelIndex + 1];
	uchar r = raw[channelIndex + 2];
	int cMax = max(max(b, g), r);
		
	if (cMax <= opts[15]) { // Skip black pixels
		return;
	}
		
	int col = gid % opts[0];
	int row = floor((float)gid / opts[0]);
	int sector = 0;

	if (row < opts[2]) { // Top area
		// sector = floor(col / sector width top)
		sector = floor((float)col / opts[6]);
	} else if (row >= opts[3]) { // Bottom area
		// sector = sector bottom count - floor(col / width) + offset bottom
		sector = opts[13] - floor((float)col / opts[8]) + opts[11];
	} else if (col >= opts[5]) { // Right area
		// sector = floor((row - ignore min vertical) / height right) + offset right
		sector = floor((float)(row - opts[2]) / opts[7]) + opts[10];
	} else if (col < opts[4]) { // Left area
		// sector = left count - floor((row - ignore min vertical) / height left) + offset left
		sector = opts[14] - floor((float)(row - opts[2]) / opts[9]) + opts[12];
	} else {
		return;
	}

	int cMin = min(min(b, g), r);
	int sat = ((cMax - cMin) / (float)cMax) * 100;
	int offset = sector * 4;

	// atom_add(&out[offset], 1);
	atom_add(&out[offset], r * sat);
	atom_add(&out[offset + 1], g * sat);
	atom_add(&out[offset + 2], b * sat);
	atom_add(&out[offset + 3], sat);
}