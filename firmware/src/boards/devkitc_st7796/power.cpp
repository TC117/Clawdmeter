// power.cpp
#include "../../hal/power_hal.h"

// USB-powered DevKit: no PMU, no battery, no PWR button (so no hold-to-pair
// gesture — re-pair by removing the device in Windows and adding it again).
void power_hal_init(void) {}
void power_hal_tick(void) {}
int  power_hal_battery_pct(void) { return -1; }
bool power_hal_is_charging(void) { return false; }
bool power_hal_is_vbus_in(void)  { return true; }
bool power_hal_pwr_pressed(void) { return false; }
bool power_hal_pwr_long_pressed(void) { return false; }
bool power_hal_pwr_released(void) { return false; }
