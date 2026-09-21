// board_init.cpp
#include "board.h"
#include <Arduino.h>
#include <Wire.h>

// No expander or power-hold line: park the unused SD card's CS so it can't
// answer on the shared SPI pins, then bring up the touch I2C bus.
extern "C" void board_init(void) {
    pinMode(SD_CS, OUTPUT);
    digitalWrite(SD_CS, HIGH);
    Wire.begin(IIC_SDA, IIC_SCL, 400000);
}
