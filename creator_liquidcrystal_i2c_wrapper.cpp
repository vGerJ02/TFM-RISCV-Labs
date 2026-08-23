#include <Arduino.h>
#include <Wire.h>
#include "LiquidCrystal_I2C.h"

// CREATOR/CREATino wrapper for the LiquidCrystal_I2C Arduino library.
//
// All exported functions use extern "C" so they can be called from assembly
// with jal, for example:
//
//     li a0, 5      # SDA
//     li a1, 6      # SCL
//     jal ra, lcd_i2c_begin_default
//
// RISC-V argument registers map directly to function parameters:
// a0 -> first argument, a1 -> second argument, etc. Return values are in a0.
// Functions return 0 on success unless they naturally return a byte/print count.
// A return value of -1 means the LCD was not initialized or the operation failed.

static LiquidCrystal_I2C *creator_lcd_i2c = nullptr;

// Initialize an I2C LCD with explicit settings.
// Arguments:
//   a0/address: I2C address, commonly 0x27 or 0x3F.
//   a1/sda: ESP32 SDA GPIO pin.
//   a2/scl: ESP32 SCL GPIO pin.
//   a3/cols: number of LCD columns, commonly 16 or 20.
//   a4/rows: number of LCD rows, commonly 2 or 4.
// Returns:
//   0 on success, -1 on failure.
extern "C" int lcd_i2c_begin(
    int address,
    int sda,
    int scl,
    int cols,
    int rows
) {
    if (creator_lcd_i2c != nullptr) {
        delete creator_lcd_i2c;
        creator_lcd_i2c = nullptr;
    }

#if defined(ARDUINO_ARCH_ESP32)
    if (!Wire.setPins(sda, scl)) {
        return -1;
    }
#else
    (void)sda;
    (void)scl;
#endif

    creator_lcd_i2c = new LiquidCrystal_I2C((uint8_t)address, (uint8_t)cols, (uint8_t)rows);
    if (creator_lcd_i2c == nullptr) {
        return -1;
    }

    creator_lcd_i2c->init();
    creator_lcd_i2c->backlight();
    return 0;
}

// Initialize a common 16x2 LCD at I2C address 0x27.
// Arguments:
//   a0/sda: ESP32 SDA GPIO pin.
//   a1/scl: ESP32 SCL GPIO pin.
// Returns:
//   0 on success, -1 on failure.
extern "C" int lcd_i2c_begin_default(int sda, int scl) {
    return lcd_i2c_begin(0x27, sda, scl, 16, 2);
}

// Clear the display and move the cursor to the top-left position.
// Returns 0 on success, -1 if the LCD is not initialized.
extern "C" int lcd_i2c_clear() {
    if (creator_lcd_i2c == nullptr) {
        return -1;
    }

    creator_lcd_i2c->clear();
    return 0;
}

// Move the cursor to the top-left position without clearing the display.
// Returns 0 on success, -1 if the LCD is not initialized.
extern "C" int lcd_i2c_home() {
    if (creator_lcd_i2c == nullptr) {
        return -1;
    }

    creator_lcd_i2c->home();
    return 0;
}

// Set cursor position.
// Arguments:
//   a0/col: zero-based column.
//   a1/row: zero-based row.
// Returns 0 on success, -1 if the LCD is not initialized.
extern "C" int lcd_i2c_set_cursor(int col, int row) {
    if (creator_lcd_i2c == nullptr) {
        return -1;
    }

    creator_lcd_i2c->setCursor((uint8_t)col, (uint8_t)row);
    return 0;
}

// Print a null-terminated string from memory.
// Arguments:
//   a0/text: address of a .asciz string.
// Returns the number of characters printed, or -1 on failure.
extern "C" int lcd_i2c_print(const char *text) {
    if (creator_lcd_i2c == nullptr || text == nullptr) {
        return -1;
    }

    return (int)creator_lcd_i2c->print(text);
}

// Print a signed integer.
// Arguments:
//   a0/value: integer to print.
// Returns the number of characters printed, or -1 if the LCD is not initialized.
extern "C" int lcd_i2c_print_int(int value) {
    if (creator_lcd_i2c == nullptr) {
        return -1;
    }

    return (int)creator_lcd_i2c->print(value);
}

// Write one character byte to the LCD.
// Arguments:
//   a0/value: character code to write.
// Returns the number of bytes written, or -1 if the LCD is not initialized.
extern "C" int lcd_i2c_write_char(int value) {
    if (creator_lcd_i2c == nullptr) {
        return -1;
    }

    return (int)creator_lcd_i2c->write((uint8_t)value);
}

// Turn on the LCD backlight.
// Returns 0 on success, -1 if the LCD is not initialized.
extern "C" int lcd_i2c_backlight() {
    if (creator_lcd_i2c == nullptr) {
        return -1;
    }

    creator_lcd_i2c->backlight();
    return 0;
}

// Turn off the LCD backlight.
// Returns 0 on success, -1 if the LCD is not initialized.
extern "C" int lcd_i2c_no_backlight() {
    if (creator_lcd_i2c == nullptr) {
        return -1;
    }

    creator_lcd_i2c->noBacklight();
    return 0;
}

// Turn on the LCD display without changing its text buffer.
// Returns 0 on success, -1 if the LCD is not initialized.
extern "C" int lcd_i2c_display() {
    if (creator_lcd_i2c == nullptr) {
        return -1;
    }

    creator_lcd_i2c->display();
    return 0;
}

// Turn off the LCD display without clearing its text buffer.
// Returns 0 on success, -1 if the LCD is not initialized.
extern "C" int lcd_i2c_no_display() {
    if (creator_lcd_i2c == nullptr) {
        return -1;
    }

    creator_lcd_i2c->noDisplay();
    return 0;
}

// Show the cursor underline.
// Returns 0 on success, -1 if the LCD is not initialized.
extern "C" int lcd_i2c_cursor() {
    if (creator_lcd_i2c == nullptr) {
        return -1;
    }

    creator_lcd_i2c->cursor();
    return 0;
}

// Hide the cursor underline.
// Returns 0 on success, -1 if the LCD is not initialized.
extern "C" int lcd_i2c_no_cursor() {
    if (creator_lcd_i2c == nullptr) {
        return -1;
    }

    creator_lcd_i2c->noCursor();
    return 0;
}

// Enable blinking cursor block.
// Returns 0 on success, -1 if the LCD is not initialized.
extern "C" int lcd_i2c_blink() {
    if (creator_lcd_i2c == nullptr) {
        return -1;
    }

    creator_lcd_i2c->blink();
    return 0;
}

// Disable blinking cursor block.
// Returns 0 on success, -1 if the LCD is not initialized.
extern "C" int lcd_i2c_no_blink() {
    if (creator_lcd_i2c == nullptr) {
        return -1;
    }

    creator_lcd_i2c->noBlink();
    return 0;
}

// Scroll the full display one position left.
// Returns 0 on success, -1 if the LCD is not initialized.
extern "C" int lcd_i2c_scroll_left() {
    if (creator_lcd_i2c == nullptr) {
        return -1;
    }

    creator_lcd_i2c->scrollDisplayLeft();
    return 0;
}

// Scroll the full display one position right.
// Returns 0 on success, -1 if the LCD is not initialized.
extern "C" int lcd_i2c_scroll_right() {
    if (creator_lcd_i2c == nullptr) {
        return -1;
    }

    creator_lcd_i2c->scrollDisplayRight();
    return 0;
}
