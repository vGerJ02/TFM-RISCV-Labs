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

.data
passcode:
    .byte '1', '2', '3', '4'
enter_msg:
    .asciz "Enter code:"
granted_msg:
    .asciz "Access granted"
denied_msg:
    .asciz "Denied"
hidden_char_msg:
    .asciz "#"

.text
main:
    jal ra, initArduino

    li a0, 200
    jal ra, delay

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

    li a0, 50
    jal ra, keypad_set_debounce_time

reset_entry:
    # Reset cursor column/count and valid flag.
    li s0, 0
    li s2, 1
    la s3, passcode

    jal ra, lcd_i2c_clear

    li a0, 0
    li a1, 0
    jal ra, lcd_i2c_set_cursor
    la a0, enter_msg
    jal ra, lcd_i2c_print

    # Put cursor at beginning of second line.
    li a0, 0
    li a1, 1
    jal ra, lcd_i2c_set_cursor

read_key_loop:
    jal ra, keypad_get_key
    beqz a0, read_key_loop

    mv s1, a0

    # '*' clears the current typed values.
    li t0, '*'
    beq s1, t0, clear_and_wait

    # Ignore non-digit keys for password checking and display.
    li t0, '0'
    blt s1, t0, wait_and_read
    li t0, '9'
    bgt s1, t0, wait_and_read

    # Compare this digit with the character stored at passcode[s0].
    add t1, s3, s0
    lbu t0, 0(t1)
    beq s1, t0, print_digit
    li s2, 0

print_digit:
    # Hide the actual typed digit by showing '#' on line 1 at column s0.
    mv a0, s0
    li a1, 1
    jal ra, lcd_i2c_set_cursor

    la a0, hidden_char_msg
    jal ra, lcd_i2c_print

    addi s0, s0, 1

    # After 4 digits, show result.
    li t0, 4
    beq s0, t0, show_result

wait_and_read:
    li a0, 250
    jal ra, delay
    j read_key_loop

show_result:
    li a0, 700
    jal ra, delay

    beqz s2, show_denied
    j show_granted

show_granted:
    jal ra, lcd_i2c_clear
    li a0, 0
    li a1, 0
    jal ra, lcd_i2c_set_cursor
    la a0, granted_msg
    jal ra, lcd_i2c_print

    li a0, 1500
    jal ra, delay
    j reset_entry

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

clear_and_wait:
    li a0, 250
    jal ra, delay
    j reset_entry
