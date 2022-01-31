#include "FastLED.h"

#define NUM_LEDS 68 
#define FRAME_CAP 60

CRGB leds[NUM_LEDS];

void serial_flush(){
	while(Serial.available()) Serial.read();
}

void setup()
{
	Serial.begin(115200);
	FastLED.addLeds<NEOPIXEL, 6>(leds, NUM_LEDS);
	FastLED.setMaxRefreshRate(2000);
	FastLED.show();
	serial_flush(); // just in case
}

const float frameTime = 1 / FRAME_CAP * 1000; // in microseconds
unsigned long prevRefreshTime = 0;

void loop()
{
	if(Serial.available()){
		uint8_t id = Serial.read();

		if(id == 255){ // If the ID is 255, show the frame
			FastLED.show();
			serial_flush();
		}
		else if(id < NUM_LEDS){
			leds[id].red = Serial.read();
			leds[id].green = Serial.read();
			leds[id].blue = Serial.read();
		}
	}
}