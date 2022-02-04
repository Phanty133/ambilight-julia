// raw
// B G R A * W * H

// out
// RSum GSum BSum SatSum NonBlackPixels * SectorCount

#define ITER 4

typedef struct __attribute__((packed)) _opts {
	int scr_width;
	int scr_height;
	int ignore_vertical_min;
	int ignore_vertical_max;
	int ignore_horizontal_min;
	int ignore_horizontal_max;
	int sector_width_top;
	int sector_width_right;
	int sector_width_bottom;
	int sector_width_left;
	int sector_offset_top;
	int sector_offset_right;
	int sector_offset_bottom;
	int sector_offset_left;
	int sector_count_bottom;
	int sector_count_left;
	int sector_total;
} opts;

__kernel void avg(__global const opts *opts,
				  __global const uchar *raw,
				  __global int *out)
{
	int gid = get_global_id(0);
	int channelIndex = gid * ITER;

	uchar b = raw[channelIndex];
	uchar g = raw[channelIndex + 1];
	uchar r = raw[channelIndex + 2];
	int cMax = max(max(b, g), r);

	int col = gid % opts->scr_width;
	int row = floor((float)gid / opts->scr_width);
	int sector = 0;

	if (row < opts->ignore_vertical_min) { // Top area
		sector = floor((float)col / opts->sector_width_top) + opts->sector_offset_top;
	} else if (row >= opts->ignore_vertical_max) { // Bottom area
		sector = opts->sector_count_bottom - floor((float)col / opts->sector_width_bottom) + opts->sector_offset_bottom;
	} else if (col >= opts->ignore_horizontal_max) { // Right area
		sector = floor((float)(row - opts->ignore_vertical_min) / opts->sector_width_right) + opts->sector_offset_right;
	} else if (col < opts->ignore_horizontal_min) { // Left area
		sector = opts->sector_count_left - floor((float)(row - opts->ignore_vertical_min) / opts->sector_width_left) + opts->sector_offset_left - 1;
	} else {
		return;
	}

	int cMin = min(min(b, g), r);
	int sat = ((cMax - cMin) / (float)cMax) * 100;
	int offset = sector * 5;

	// atom_add(&out[offset], 1);
	atom_add(&out[offset], r * sat);
	atom_add(&out[offset + 1], g * sat);
	atom_add(&out[offset + 2], b * sat);
	atom_add(&out[offset + 3], sat);
	atom_add(&out[offset + 4], 1);	
}