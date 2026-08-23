#include <Arduino.h>
#include <Keypad.h>
#include <new>

// CREATOR/CREATino wrapper for the Arduino Keypad library.
//
// All exported functions use extern "C" so they can be called from assembly
// with jal. RISC-V argument registers map directly to function parameters:
// a0 -> first argument, a1 -> second argument, etc. Return values are in a0.
//
// KeyState numeric values from the Keypad library:
//   IDLE     = 0
//   PRESSED  = 1
//   HOLD     = 2
//   RELEASED = 3
//
// Most functions return -1 when the keypad has not been initialized.

alignas(Keypad) static uint8_t creator_keypad_storage[sizeof(Keypad)];
static Keypad *creator_keypad = nullptr;

static char creator_keymap_4x3[4][3] = {
    {'1', '2', '3'},
    {'4', '5', '6'},
    {'7', '8', '9'},
    {'*', '0', '#'},
};

static char creator_keymap_4x4[4][4] = {
    {'1', '2', '3', 'A'},
    {'4', '5', '6', 'B'},
    {'7', '8', '9', 'C'},
    {'*', '0', '#', 'D'},
};

static byte creator_row_pins[4] = {0, 0, 0, 0};
static byte creator_col_pins[4] = {0, 0, 0, 0};
static byte creator_rows = 0;
static byte creator_cols = 0;

static void creator_reset_keypad() {
    if (creator_keypad != nullptr) {
        creator_keypad->~Keypad();
        creator_keypad = nullptr;
    }
}

// Initialize a standard 4-row x 3-column keypad.
// Key map:
//   1 2 3
//   4 5 6
//   7 8 9
//   * 0 #
// Arguments:
//   a0-a3: row pins R1, R2, R3, R4.
//   a4-a6: column pins C1, C2, C3.
// Returns 0 on success.
extern "C" int keypad_begin_4x3(
    int row0,
    int row1,
    int row2,
    int row3,
    int col0,
    int col1,
    int col2
) {
    creator_reset_keypad();

    creator_row_pins[0] = (byte)row0;
    creator_row_pins[1] = (byte)row1;
    creator_row_pins[2] = (byte)row2;
    creator_row_pins[3] = (byte)row3;
    creator_col_pins[0] = (byte)col0;
    creator_col_pins[1] = (byte)col1;
    creator_col_pins[2] = (byte)col2;
    creator_rows = 4;
    creator_cols = 3;

    creator_keypad = new (creator_keypad_storage) Keypad(
        makeKeymap(creator_keymap_4x3),
        creator_row_pins,
        creator_col_pins,
        4,
        3
    );

    return 0;
}

// Initialize a standard 4-row x 4-column keypad.
// Key map:
//   1 2 3 A
//   4 5 6 B
//   7 8 9 C
//   * 0 # D
// Arguments:
//   a0-a3: row pins R1, R2, R3, R4.
//   a4-a7: column pins C1, C2, C3, C4.
// Returns 0 on success.
extern "C" int keypad_begin_4x4(
    int row0,
    int row1,
    int row2,
    int row3,
    int col0,
    int col1,
    int col2,
    int col3
) {
    creator_reset_keypad();

    creator_row_pins[0] = (byte)row0;
    creator_row_pins[1] = (byte)row1;
    creator_row_pins[2] = (byte)row2;
    creator_row_pins[3] = (byte)row3;
    creator_col_pins[0] = (byte)col0;
    creator_col_pins[1] = (byte)col1;
    creator_col_pins[2] = (byte)col2;
    creator_col_pins[3] = (byte)col3;
    creator_rows = 4;
    creator_cols = 4;

    creator_keypad = new (creator_keypad_storage) Keypad(
        makeKeymap(creator_keymap_4x4),
        creator_row_pins,
        creator_col_pins,
        4,
        4
    );

    return 0;
}

// Initialize a 4x4 keypad when the physical row/column groups are reversed.
// Use this if keypad_begin_4x4 builds but no key presses are detected.
// Arguments:
//   a0-a3: physical column pins C1, C2, C3, C4.
//   a4-a7: physical row pins R1, R2, R3, R4.
// Returns 0 on success.
extern "C" int keypad_begin_4x4_reversed(
    int col0,
    int col1,
    int col2,
    int col3,
    int row0,
    int row1,
    int row2,
    int row3
) {
    return keypad_begin_4x4(row0, row1, row2, row3, col0, col1, col2, col3);
}

// Return the currently pressed key as an ASCII code, or 0 when no key is pressed.
extern "C" int keypad_get_key() {
    if (creator_keypad == nullptr) {
        return -1;
    }

    return (int)creator_keypad->getKey();
}

// Raw active-low scan that bypasses the Keypad library state machine.
// Returns the first detected key ASCII code, 0 if no key is pressed, or -1 if not initialized.
// Use this for debugging wiring/pin-order problems.
extern "C" int keypad_raw_get_key() {
    if (creator_keypad == nullptr || creator_rows == 0 || creator_cols == 0) {
        return -1;
    }

    for (byte row = 0; row < creator_rows; row++) {
        pinMode(creator_row_pins[row], INPUT_PULLUP);
    }

    for (byte col = 0; col < creator_cols; col++) {
        pinMode(creator_col_pins[col], OUTPUT);
        digitalWrite(creator_col_pins[col], LOW);

        delayMicroseconds(5);

        for (byte row = 0; row < creator_rows; row++) {
            if (digitalRead(creator_row_pins[row]) == LOW) {
                digitalWrite(creator_col_pins[col], HIGH);
                pinMode(creator_col_pins[col], INPUT);

                if (creator_cols == 3) {
                    return (int)creator_keymap_4x3[row][col];
                }

                return (int)creator_keymap_4x4[row][col];
            }
        }

        digitalWrite(creator_col_pins[col], HIGH);
        pinMode(creator_col_pins[col], INPUT);
    }

    return 0;
}

// Scan the keypad and update the internal multi-key list.
// Returns 1 if any key state changed, 0 if not, or -1 if not initialized.
extern "C" int keypad_get_keys() {
    if (creator_keypad == nullptr) {
        return -1;
    }

    return creator_keypad->getKeys() ? 1 : 0;
}

// Return the state of the first active key: 0 IDLE, 1 PRESSED, 2 HOLD, 3 RELEASED.
extern "C" int keypad_get_state() {
    if (creator_keypad == nullptr) {
        return -1;
    }

    return (int)creator_keypad->getState();
}

// Test whether a specific key is currently pressed.
// Argument:
//   a0/key_char: ASCII code, for example '1' is 49.
// Returns 1 if pressed, 0 if not pressed, or -1 if not initialized.
extern "C" int keypad_is_pressed(int key_char) {
    if (creator_keypad == nullptr) {
        return -1;
    }

    return creator_keypad->isPressed((char)key_char) ? 1 : 0;
}

// Set debounce time in milliseconds.
// Argument:
//   a0/time_ms: debounce time.
// Returns 0 on success, -1 if not initialized.
extern "C" int keypad_set_debounce_time(int time_ms) {
    if (creator_keypad == nullptr) {
        return -1;
    }

    creator_keypad->setDebounceTime((uint)time_ms);
    return 0;
}

// Set hold time in milliseconds.
// Argument:
//   a0/time_ms: time before PRESSED becomes HOLD.
// Returns 0 on success, -1 if not initialized.
extern "C" int keypad_set_hold_time(int time_ms) {
    if (creator_keypad == nullptr) {
        return -1;
    }

    creator_keypad->setHoldTime((uint)time_ms);
    return 0;
}

// Return 1 if any key state changed after the last scan, 0 if not.
extern "C" int keypad_key_state_changed() {
    if (creator_keypad == nullptr) {
        return -1;
    }

    return creator_keypad->keyStateChanged() ? 1 : 0;
}

// Return the number of active keys in the multi-key list.
// Call keypad_get_keys first to refresh the list.
extern "C" int keypad_num_keys() {
    if (creator_keypad == nullptr) {
        return -1;
    }

    return (int)creator_keypad->numKeys();
}

// Return the ASCII code for an active key by index, or -1 if out of range.
// Call keypad_get_keys first to refresh the list.
extern "C" int keypad_key_char(int index) {
    if (creator_keypad == nullptr || index < 0 || index >= LIST_MAX) {
        return -1;
    }

    return (int)creator_keypad->key[index].kchar;
}

// Return the state for an active key by index: 0 IDLE, 1 PRESSED, 2 HOLD, 3 RELEASED.
// Call keypad_get_keys first to refresh the list.
extern "C" int keypad_key_state(int index) {
    if (creator_keypad == nullptr || index < 0 || index >= LIST_MAX) {
        return -1;
    }

    return (int)creator_keypad->key[index].kstate;
}

// Return 1 if an active key by index changed state, 0 if not.
// Call keypad_get_keys first to refresh the list.
extern "C" int keypad_key_changed(int index) {
    if (creator_keypad == nullptr || index < 0 || index >= LIST_MAX) {
        return -1;
    }

    return creator_keypad->key[index].stateChanged ? 1 : 0;
}
