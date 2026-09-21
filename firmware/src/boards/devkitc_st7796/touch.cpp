#include "../../hal/touch_hal.h"
#include "board.h"
#include <Arduino.h>
#include <Wire.h>

// Minimal FT6336U reader — FocalTech register layout, same as the inline
// readers in the LCD-1.54 / AMOLED-1.8 ports (keeps the tree copyleft-free):
//   reg 0x02:        low nibble = active touch count
//   reg 0x03 / 0x04: X high (low nibble) + X low
//   reg 0x05 / 0x06: Y high (low nibble) + Y low
// Coordinates come in the panel's native portrait frame (x 0..319, y 0..479)
// and are mapped to the rotation-1 landscape frame below.

static volatile bool     touch_data_ready = false;
static volatile bool     touch_pressed = false;
static volatile uint16_t touch_x = 0;
static volatile uint16_t touch_y = 0;

static void IRAM_ATTR touch_isr(void) {
    touch_data_ready = true;
}

static void touch_read_into_shared_state(void) {
    Wire.beginTransmission(FT6336_ADDR);
    Wire.write(0x02);
    if (Wire.endTransmission(false) != 0) { touch_pressed = false; return; }
    if (Wire.requestFrom((uint8_t)FT6336_ADDR, (uint8_t)5) != 5) { touch_pressed = false; return; }
    uint8_t touches = Wire.read() & 0x0F;
    uint8_t xH = Wire.read();
    uint8_t xL = Wire.read();
    uint8_t yH = Wire.read();
    uint8_t yL = Wire.read();
    if (touches == 0 || touches > 2) {   // FT6336 tracks at most 2 points
        touch_pressed = false;
        return;
    }
    uint16_t rx = ((uint16_t)(xH & 0x0F) << 8) | xL;
    uint16_t ry = ((uint16_t)(yH & 0x0F) << 8) | yL;
    // Portrait (rx, ry) → rotation-1 landscape (x, y).
    touch_x = ry;
    touch_y = (rx < LCD_NATIVE_W) ? (LCD_NATIVE_W - 1 - rx) : 0;
    touch_pressed = true;
}

void touch_hal_init(void) {
    pinMode(TP_RST, OUTPUT);
    digitalWrite(TP_RST, LOW);
    delay(10);
    digitalWrite(TP_RST, HIGH);
    delay(300);   // FT6336U needs ~300 ms after reset before it answers

    // FocalTech vendor id lives at reg 0xA8.
    Wire.beginTransmission(FT6336_ADDR);
    Wire.write(0xA8);
    if (Wire.endTransmission(false) == 0 &&
        Wire.requestFrom((uint8_t)FT6336_ADDR, (uint8_t)1) == 1) {
        Serial.printf("Touch FT6336 vendor=0x%02X (addr 0x%02X)\n", Wire.read(), FT6336_ADDR);
    } else {
        Serial.printf("Touch ID read failed (addr 0x%02X)\n", FT6336_ADDR);
    }

    pinMode(TP_INT, INPUT_PULLUP);
    attachInterrupt(TP_INT, touch_isr, FALLING);
}

void touch_hal_read(uint16_t* x, uint16_t* y, bool* pressed) {
    if (touch_data_ready) {
        touch_data_ready = false;
        touch_read_into_shared_state();
    } else if (touch_pressed) {
        // Re-read while down so a missed release edge can't leave us stuck pressed.
        touch_read_into_shared_state();
    }
    *x = touch_x;
    *y = touch_y;
    *pressed = touch_pressed;
}
