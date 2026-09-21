// input.cpp
#include "../../hal/input_hal.h"
#include "board.h"
#include <Arduino.h>

void input_hal_init(void) {
    pinMode(BTN_BOOT_GPIO, INPUT_PULLUP);
}

bool input_hal_is_held(InputButton btn) {
    return btn == INPUT_BTN_PRIMARY && digitalRead(BTN_BOOT_GPIO) == LOW;
}
