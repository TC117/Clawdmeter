#pragma once

// ESP32-S3-DevKitC-1 N16R8 (YD clone) + MSP4031 4.0" TFT, hand-wired.
// ST7796S 320x480 over 4-wire SPI, used at rotation 1 (480x320 landscape), and
// an FT6336U capacitive touch controller on I2C. Pin map from the usage-lcd
// project that drove this exact wiring. No PMU, battery, IMU or codec.

#define BOARD_NAME           "DevKitC + ST7796 4.0"

// ---- Display geometry (after rotation) ----
#define LCD_WIDTH            480
#define LCD_HEIGHT           320
#define LCD_NATIVE_W         320        // ST7796 GRAM is portrait
#define LCD_NATIVE_H         480
#define LCD_ROTATION         1          // landscape; 3 if the image is upside down
#define LCD_SPI_HZ           40000000   // jumper wires: 40 MHz is the safe ceiling

// ---- SPI display pins (ST7796S) ----
#define LCD_CS               10
#define LCD_MOSI             11
#define LCD_SCLK             12
#define LCD_MISO             13         // wired, unused (write-only driver)
#define LCD_RST              14
#define LCD_DC               9
#define LCD_BL               16         // backlight, LEDC PWM
#define SD_CS                15         // MSP4031 SD slot, held HIGH (unused)

// ---- I2C bus (touch only) ----
#define IIC_SDA              4
#define IIC_SCL              5

// ---- Touch (FT6336U, minimal inline I2C reader) ----
#define TP_RST               6
#define TP_INT               7
#define FT6336_ADDR          0x38

// ---- Buttons ----
#define BTN_BOOT_GPIO        0          // BOOT — primary, screen off/on (see BOARD_PRIMARY_TOGGLES_SCREEN)

// ---- Capability flags ----
#define BOARD_HAS_SECONDARY_BUTTON 0
#define BOARD_HAS_ROTATION         0
#define BOARD_HAS_IMU              0
#define BOARD_HAS_BATTERY          0
#define BOARD_HAS_IO_EXPANDER      0
#define BOARD_HAS_SOUND            0
#define BOARD_PRIMARY_TOGGLES_SCREEN 1  // BOOT = screen off/on (no HID Space)
