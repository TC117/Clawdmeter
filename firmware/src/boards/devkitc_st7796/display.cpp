#include "../../hal/display_hal.h"
#include "board.h"
#include <Arduino.h>
#include <Arduino_GFX_Library.h>

// ST7796S over plain 4-wire SPI, same shape as the LCD-1.54 port. The panel is
// portrait-native; Arduino_GFX's rotation 1 turns it into the 480x320 frame
// LVGL draws in, so the flush path needs no CPU remapping. Brightness is PWM
// on the LED pin (the ST7796 has no brightness command).

static Arduino_DataBus* bus = nullptr;
static Arduino_ST7796*  gfx = nullptr;

void display_hal_init(void) {
    bus = new Arduino_ESP32SPI(LCD_DC, LCD_CS, LCD_SCLK, LCD_MOSI,
                               GFX_NOT_DEFINED /* MISO unused */);
    // ips=false: the usage-lcd LovyanGFX config ran this panel with invert=false.
    gfx = new Arduino_ST7796(bus, LCD_RST, LCD_ROTATION, false /* ips */,
                             LCD_NATIVE_W, LCD_NATIVE_H);
}

void display_hal_begin(void) {
    gfx->begin(LCD_SPI_HZ);
    gfx->fillScreen(0x0000);
    ledcAttach(LCD_BL, 12000 /* Hz */, 8 /* bits */);
    ledcWrite(LCD_BL, 200);
}

void display_hal_set_brightness(uint8_t level) {
    ledcWrite(LCD_BL, level);
}

void display_hal_fill_screen(uint16_t color) {
    if (gfx) gfx->fillScreen(color);
}

void display_hal_draw_bitmap(int32_t x, int32_t y, int32_t w, int32_t h,
                             const uint16_t* pixels) {
    if (gfx) gfx->draw16bitRGBBitmap(x, y, (uint16_t*)pixels, w, h);
}

void display_hal_tick(void) {}

// SPI TFT: no flush-region alignment requirement.
void display_hal_round_area(int32_t* x1, int32_t* y1, int32_t* x2, int32_t* y2) {
    (void)x1; (void)y1; (void)x2; (void)y2;
}
