# Keypad-based data entry and statistics using a 4x4 keypad and a 16x2 I2C LCD.
#
# Store up to eight values from 0 to 999 and use:
#   A -> count, B -> sum, C -> minimum, D -> maximum
#   # -> store value, * -> cancel entry or clear all values
#
# Required wrappers:
#   creator_keypad_wrapper.cpp
#   creator_liquidcrystal_i2c_wrapper.cpp
#
# LCD wiring:
#   SDA -> GPIO 5
#   SCL -> GPIO 6
#
# Keypad wiring:
#   Pin 8 -> GPIO 0     row 0
#   Pin 7 -> GPIO 1     row 1
#   Pin 6 -> GPIO 2     row 2
#   Pin 5 -> GPIO 3     row 3
#   Pin 4 -> GPIO 21    column 0
#   Pin 3 -> GPIO 20    column 1
#   Pin 2 -> GPIO 10    column 2
#   Pin 1 -> GPIO 7     column 3

.data
values:
    .word 0, 0, 0, 0, 0, 0, 0, 0

prompt:       .asciz "Enter value:"
stored_text:  .asciz "Stored:"
count_text:   .asciz "Count:"
sum_text:     .asciz "Sum:"
min_text:     .asciz "Minimum:"
max_text:     .asciz "Maximum:"
no_data_text: .asciz "No data"
full_text:    .asciz "Memory full"
limit_text:   .asciz "Max 3 digits"
cancel_text:  .asciz "Entry cancelled"
clear_text:   .asciz "Data cleared"

.text
.globl main

main:
    # Saved registers keep the program state across C++ wrapper calls.
    la   s0, values              # Base address of the array
    li   s1, 0                   # Number of stored values
    li   s2, 0                   # Current input value
    li   s3, 0                   # Number of entered digits

    # Initialize the Arduino environment and the LCD.
    jal  ra, initArduino
    li   a0, 200
    jal  ra, delay

    li   a0, 5                   # SDA
    li   a1, 6                   # SCL
    jal  ra, lcd_i2c_begin_default

    # Initialize the keypad: a0-a3 are rows and a4-a7 are columns.
    li   a0, 0
    li   a1, 1
    li   a2, 2
    li   a3, 3
    li   a4, 21
    li   a5, 20
    li   a6, 10
    li   a7, 7
    jal  ra, keypad_begin_4x4

    li   a0, 50
    jal  ra, keypad_set_debounce_time

    jal  ra, display_prompt

read_key:
    # keypad_get_key returns an ASCII code, or zero if no key was pressed.
    jal  ra, keypad_get_key
    beqz a0, read_key

    # Check first for a decimal digit ('0' to '9').
    li   t0, 48
    blt  a0, t0, check_commands
    li   t0, 57
    ble  a0, t0, add_digit

check_commands:
    li   t0, 35                  # '#'
    beq  a0, t0, store_value
    li   t0, 42                  # '*'
    beq  a0, t0, cancel_or_clear
    li   t0, 65                  # 'A'
    beq  a0, t0, display_count
    li   t0, 66                  # 'B'
    beq  a0, t0, display_sum
    li   t0, 67                  # 'C'
    beq  a0, t0, display_minimum
    li   t0, 68                  # 'D'
    beq  a0, t0, display_maximum
    j    read_key

add_digit:
    li   t0, 3
    bge  s3, t0, digit_limit

    # Convert ASCII to decimal and calculate value = value * 10 + digit.
    addi a0, a0, -48
    slli t0, s2, 3              # value * 8
    slli t1, s2, 1              # value * 2
    add  s2, t0, t1
    add  s2, s2, a0
    addi s3, s3, 1

    jal  ra, display_input
    j    read_key

digit_limit:
    la   a0, limit_text
    jal  ra, display_text
    j    read_key

store_value:
    beqz s3, read_key            # Ignore '#' if the input is empty
    li   t0, 8
    bge  s1, t0, memory_full

    slli t0, s1, 2
    add  t0, s0, t0
    sw   s2, 0(t0)
    addi s1, s1, 1

    mv   a1, s2
    li   s2, 0
    li   s3, 0
    la   a0, stored_text
    jal  ra, display_result
    j    read_key

memory_full:
    li   s2, 0
    li   s3, 0
    la   a0, full_text
    jal  ra, display_text
    j    read_key

cancel_or_clear:
    beqz s3, clear_values

    li   s2, 0
    li   s3, 0
    la   a0, cancel_text
    jal  ra, display_text
    j    read_key

clear_values:
    # Clear all eight array positions.
    mv   t0, s0
    li   t1, 8
clear_loop:
    sw   zero, 0(t0)
    addi t0, t0, 4
    addi t1, t1, -1
    bnez t1, clear_loop

    li   s1, 0
    la   a0, clear_text
    jal  ra, display_text
    j    read_key

display_count:
    beqz s1, no_data
    la   a0, count_text
    mv   a1, s1
    jal  ra, display_result
    j    read_key

display_sum:
    beqz s1, no_data
    mv   t0, s0
    mv   t1, s1
    li   t2, 0
sum_loop:
    lw   t3, 0(t0)
    add  t2, t2, t3
    addi t0, t0, 4
    addi t1, t1, -1
    bnez t1, sum_loop

    la   a0, sum_text
    mv   a1, t2
    jal  ra, display_result
    j    read_key

display_minimum:
    beqz s1, no_data
    mv   t0, s0
    lw   t2, 0(t0)
    addi t0, t0, 4
    addi t1, s1, -1
min_loop:
    beqz t1, min_done
    lw   t3, 0(t0)
    bge  t3, t2, min_next
    mv   t2, t3
min_next:
    addi t0, t0, 4
    addi t1, t1, -1
    j    min_loop
min_done:
    la   a0, min_text
    mv   a1, t2
    jal  ra, display_result
    j    read_key

display_maximum:
    beqz s1, no_data
    mv   t0, s0
    lw   t2, 0(t0)
    addi t0, t0, 4
    addi t1, s1, -1
max_loop:
    beqz t1, max_done
    lw   t3, 0(t0)
    ble  t3, t2, max_next
    mv   t2, t3
max_next:
    addi t0, t0, 4
    addi t1, t1, -1
    j    max_loop
max_done:
    la   a0, max_text
    mv   a1, t2
    jal  ra, display_result
    j    read_key

no_data:
    la   a0, no_data_text
    jal  ra, display_text
    j    read_key

# Clear the LCD and display the input prompt.
display_prompt:
    addi sp, sp, -16
    sw   ra, 12(sp)
    jal  ra, lcd_i2c_clear
    la   a0, prompt
    jal  ra, lcd_i2c_print
    lw   ra, 12(sp)
    addi sp, sp, 16
    ret

# Display the prompt and the current input value.
display_input:
    addi sp, sp, -16
    sw   ra, 12(sp)
    jal  ra, display_prompt
    li   a0, 0
    li   a1, 1
    jal  ra, lcd_i2c_set_cursor
    mv   a0, s2
    jal  ra, lcd_i2c_print_int
    lw   ra, 12(sp)
    addi sp, sp, 16
    ret

# Clear the LCD and display the string whose address is passed in a0.
display_text:
    addi sp, sp, -16
    sw   ra, 12(sp)
    sw   a0, 8(sp)
    jal  ra, lcd_i2c_clear
    lw   a0, 8(sp)
    jal  ra, lcd_i2c_print
    lw   ra, 12(sp)
    addi sp, sp, 16
    ret

# Display a label on row 0 and the integer passed in a1 on row 1.
display_result:
    addi sp, sp, -16
    sw   ra, 12(sp)
    sw   a0, 8(sp)
    sw   a1, 4(sp)
    jal  ra, lcd_i2c_clear
    lw   a0, 8(sp)
    jal  ra, lcd_i2c_print
    li   a0, 0
    li   a1, 1
    jal  ra, lcd_i2c_set_cursor
    lw   a0, 4(sp)
    jal  ra, lcd_i2c_print_int
    lw   ra, 12(sp)
    addi sp, sp, 16
    ret
