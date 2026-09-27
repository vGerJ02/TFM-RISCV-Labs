# Four-digit passcode exercise using a 4x4 keypad and a 16x2 I2C LCD.
#
# The program masks each entered digit with '#', validates the sequence against
# the passcode 1234 stored in memory, displays the result, and then accepts a
# new attempt. Pressing '*' clears the current entry. This base implementation
# does not limit the number of attempts or enter a locked state.
#
# Required wrappers:
#   creator_keypad_wrapper.cpp
#   creator_liquidcrystal_i2c_wrapper.cpp
#
# Keypad wiring:
#   keypad pin 8 -> board GPIO 0   row 0
#   keypad pin 7 -> board GPIO 1   row 1
#   keypad pin 6 -> board GPIO 2   row 2
#   keypad pin 5 -> board GPIO 3   row 3
#   keypad pin 4 -> board GPIO 21  column 0
#   keypad pin 3 -> board GPIO 20  column 1
#   keypad pin 2 -> board GPIO 10  column 2
#   keypad pin 1 -> board GPIO 7   column 3
#
# LCD wiring:
#   SDA -> board GPIO 5
#   SCL -> board GPIO 6
#
# Register usage:
#   s0 = typed character count / cursor column on LCD line 1
#   s1 = last key ASCII code
#   s2 = valid_so_far flag, 1 means all typed chars still match 1234
#   s3 = address of the passcode stored in memory
#   t0 = temporary comparison value
#   t1 = address of the expected digit

.data                        # Stored passcode and LCD text.
passcode:
    .byte '1', '2', '3', '4'  # Four ASCII bytes, one per digit
enter_msg:
    .asciz "Enter code:"     # .asciz adds the zero byte that ends a string.
granted_msg:
    .asciz "Access granted"
denied_msg:
    .asciz "Denied"
hidden_char_msg:
    .asciz "#"               # Mask printed instead of each entered digit.

.text                        # Executable instructions start here.
# Initialize the board, LCD, and keypad once before accepting entries.
main:
    jal ra, initArduino      # Initialize the Arduino support used by wrappers.

    li a0, 200
    jal ra, delay            # delay takes a duration in milliseconds in a0.

    # LCD: SDA=5, SCL=6, default address 0x27, 16x2.
    li a0, 5
    li a1, 6
    jal ra, lcd_i2c_begin_default

    # Keypad: rows 0,1,2,3 and columns 21,20,10,7.
    li a0, 0
    li a1, 1
    li a2, 2
    li a3, 3
    li a4, 21
    li a5, 20
    li a6, 10
    li a7, 7
    jal ra, keypad_begin_4x4

    li a0, 50                # Keypad debounce interval in milliseconds.
    jal ra, keypad_set_debounce_time

# Start a fresh attempt, either after a result or after pressing '*'.
reset_entry:
    # Reset cursor column/count and valid flag.
    li s0, 0                 # No digits have been entered yet.
    li s2, 1                 # Assume correct until a digit fails to match.
    la s3, passcode          # Base address used to look up expected digits.

    jal ra, lcd_i2c_clear    # Remove the previous entry or result.

    li a0, 0                 # lcd_i2c_set_cursor: a0 = column, a1 = line.
    li a1, 0                 # First display line.
    jal ra, lcd_i2c_set_cursor
    la a0, enter_msg         # lcd_i2c_print takes a string address in a0.
    jal ra, lcd_i2c_print

    # Put cursor at beginning of second line.
    li a0, 0
    li a1, 1
    jal ra, lcd_i2c_set_cursor

# Poll until the keypad reports a key, then handle clear/digit/ignored keys.
read_key_loop:
    jal ra, keypad_get_key
    beqz a0, read_key_loop   # Zero means no new key is available.

    mv s1, a0                # Save the key code; wrapper calls may reuse a0.

    # '*' clears the current typed values.
    li t0, '*'
    beq s1, t0, clear_and_wait

    # Ignore non-digit keys for password checking and display.
    li t0, '0'
    blt s1, t0, wait_and_read # ASCII codes below '0' are not digits.
    li t0, '9'
    bgt s1, t0, wait_and_read # ASCII codes above '9' are not digits.

    # Compare this digit with the character stored at passcode[s0].
    add t1, s3, s0           # Each .byte is 1 byte: byte offset = digit index.
    lbu t0, 0(t1)            # Load the expected ASCII digit from that address.
    beq s1, t0, print_digit  # Matching digits leave valid_so_far unchanged.
    li s2, 0                 # A mismatch stays recorded until reset_entry.

# Display one mask character, even if this digit did not match the passcode.
print_digit:
    # Hide the actual typed digit by showing '#' on line 1 at column s0.
    mv a0, s0
    li a1, 1
    jal ra, lcd_i2c_set_cursor

    la a0, hidden_char_msg
    jal ra, lcd_i2c_print

    addi s0, s0, 1           # Advance the count and the next cursor column.

    # After 4 digits, show result.
    li t0, 4
    beq s0, t0, show_result  # Check the result before reading a fifth digit.

# Pause after a digit or an ignored key, then poll for another key.
wait_and_read:
    li a0, 250
    jal ra, delay
    j read_key_loop

# All four digits are entered; the saved flag selects the result message.
show_result:
    li a0, 700               # Keep the four mask characters visible briefly.
    jal ra, delay

    beqz s2, show_denied     # Zero means at least one digit was incorrect.
    j show_granted           # Otherwise all four digits matched 1234.

# Show success on the first line, then prepare another attempt.
show_granted:
    jal ra, lcd_i2c_clear
    li a0, 0
    li a1, 0
    jal ra, lcd_i2c_set_cursor
    la a0, granted_msg
    jal ra, lcd_i2c_print

    li a0, 1500              # Leave the result visible for 1.5 seconds.
    jal ra, delay
    j reset_entry

# Show failure for the same duration; attempts are unlimited.
show_denied:
    jal ra, lcd_i2c_clear
    li a0, 0
    li a1, 0
    jal ra, lcd_i2c_set_cursor
    la a0, denied_msg
    jal ra, lcd_i2c_print

    li a0, 1500
    jal ra, delay
    j reset_entry

# '*' discards the whole entry, including any recorded mismatch.
clear_and_wait:
    li a0, 250
    jal ra, delay
    j reset_entry
