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
#
# Register usage:
#   s0 = base address of the stored values array
#   s1 = number of stored values (0 to 8)
#   s2 = current input value (0 to 999)
#   s3 = number of entered digits (0 to 3)
#   t0 = temporary comparison value, array address, or arithmetic result
#   t1 = remaining array elements or arithmetic result
#   t2 = running sum, minimum, or maximum
#   t3 = current array value being examined
#   a0 = first function argument / return value, including the key ASCII code
#   a1 = second function argument, including the result to display or LCD row
#   a2-a7 = remaining keypad GPIO arguments during initialization
#   ra = return address, saved by display helpers before nested calls
#   sp = stack pointer for saved return addresses and display arguments

.data                           # Stored values and zero-terminated LCD strings.
values:
    .word 0, 0, 0, 0, 0, 0, 0, 0 # Eight 4-byte slots; s1 tracks how many are used.

prompt:       .asciz "Enter value:" # .asciz adds the zero byte ending a string.
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

.text                           # Executable instructions start here.
.globl main                     # Make the entry point visible to the loader.

# Initialize the entry state, board, LCD, and keypad once.
main:
    # Saved registers keep the program state across C++ wrapper calls.
    la   s0, values              # Base address of the array
    li   s1, 0                   # Number of stored values
    li   s2, 0                   # Current input value
    li   s3, 0                   # Number of entered digits

    # Initialize the Arduino environment and the LCD.
    jal  ra, initArduino
    li   a0, 200                 # delay takes a duration in milliseconds in a0.
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

    li   a0, 50                  # Keypad debounce interval in milliseconds.
    jal  ra, keypad_set_debounce_time

    jal  ra, display_prompt

# Poll for a key, then route it to digit entry or a command handler.
read_key:
    # keypad_get_key returns an ASCII code, or zero if no key was pressed.
    jal  ra, keypad_get_key
    beqz a0, read_key

    # Check first for a decimal digit ('0' to '9').
    li   t0, 48                  # ASCII '0': lower bound for decimal digits.
    blt  a0, t0, check_commands
    li   t0, 57                  # ASCII '9': upper bound for decimal digits.
    ble  a0, t0, add_digit

# Non-digit keys select storage, cancellation, or a statistic.
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
    j    read_key                # Ignore any unrecognized key.

# Append a digit without allowing more than three digits per entry.
add_digit:
    li   t0, 3
    bge  s3, t0, digit_limit

    # Convert ASCII to decimal and calculate value = value * 10 + digit.
    addi a0, a0, -48
    slli t0, s2, 3              # value * 8
    slli t1, s2, 1              # value * 2
    add  s2, t0, t1              # value * 8 + value * 2 = value * 10.
    add  s2, s2, a0
    addi s3, s3, 1               # Count digits, including any leading zeros.

    jal  ra, display_input
    j    read_key

# Reject the extra digit while keeping the current entry available to store.
digit_limit:
    la   a0, limit_text
    jal  ra, display_text
    j    read_key

# '#' appends the current entry if there is room in the eight-value array.
store_value:
    beqz s3, read_key            # Ignore '#' if the input is empty
    li   t0, 8
    bge  s1, t0, memory_full

    slli t0, s1, 2               # Each .word is 4 bytes: offset = count * 4.
    add  t0, s0, t0              # Address of the next unused array slot.
    sw   s2, 0(t0)               # Store the entered number as a full word.
    addi s1, s1, 1               # Include the new value in future statistics.

    mv   a1, s2                  # Keep the stored value for the result display.
    li   s2, 0
    li   s3, 0
    la   a0, stored_text
    jal  ra, display_result
    j    read_key

# A full array rejects this value and resets the pending entry.
memory_full:
    li   s2, 0
    li   s3, 0
    la   a0, full_text
    jal  ra, display_text
    j    read_key

# '*' cancels a pending entry; with no digits entered, it clears stored data.
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
    addi t0, t0, 4               # Advance to the next 4-byte array slot.
    addi t1, t1, -1              # One fewer slot remains to clear.
    bnez t1, clear_loop

    li   s1, 0                   # No array entries are now considered stored.
    la   a0, clear_text
    jal  ra, display_text
    j    read_key

# Statistics use stored values only; any pending entry remains unchanged.
# 'A' shows the number of stored values, or "No data" when empty.
display_count:
    beqz s1, no_data
    la   a0, count_text
    mv   a1, s1
    jal  ra, display_result
    j    read_key

# 'B' adds the first s1 array entries; unused slots are not included.
display_sum:
    beqz s1, no_data
    mv   t0, s0
    mv   t1, s1                  # Number of stored values left to visit.
    li   t2, 0                   # Start the running sum at zero.
sum_loop:
    lw   t3, 0(t0)               # Read the current stored word.
    add  t2, t2, t3              # Include it in the running sum.
    addi t0, t0, 4               # Move to the next word.
    addi t1, t1, -1
    bnez t1, sum_loop

    la   a0, sum_text
    mv   a1, t2
    jal  ra, display_result
    j    read_key

# 'C' starts with the first stored value and checks the remaining values.
display_minimum:
    beqz s1, no_data
    mv   t0, s0
    lw   t2, 0(t0)               # Initial minimum is an actual stored value.
    addi t0, t0, 4
    addi t1, s1, -1              # The first value has already been considered.
min_loop:
    beqz t1, min_done            # Also handles an array with just one value.
    lw   t3, 0(t0)
    bge  t3, t2, min_next        # Keep the minimum if this value is not smaller.
    mv   t2, t3                  # Record the smaller value.
min_next:
    addi t0, t0, 4
    addi t1, t1, -1
    j    min_loop
min_done:
    la   a0, min_text
    mv   a1, t2
    jal  ra, display_result
    j    read_key

# 'D' uses the same scan, keeping the largest value seen instead.
display_maximum:
    beqz s1, no_data
    mv   t0, s0
    lw   t2, 0(t0)               # Initial maximum is the first stored value.
    addi t0, t0, 4
    addi t1, s1, -1
max_loop:
    beqz t1, max_done
    lw   t3, 0(t0)
    ble  t3, t2, max_next        # Keep the maximum if this value is not larger.
    mv   t2, t3                  # Record the larger value.
max_next:
    addi t0, t0, 4
    addi t1, t1, -1
    j    max_loop
max_done:
    la   a0, max_text
    mv   a1, t2
    jal  ra, display_result
    j    read_key

# All four statistics share this response when there are no stored values.
no_data:
    la   a0, no_data_text
    jal  ra, display_text
    j    read_key

# Clear the LCD and display the input prompt.
display_prompt:
    addi sp, sp, -16             # Reserve a 16-byte, aligned stack frame.
    sw   ra, 12(sp)              # Nested jal calls overwrite ra; save it first.
    jal  ra, lcd_i2c_clear
    la   a0, prompt
    jal  ra, lcd_i2c_print
    lw   ra, 12(sp)              # Recover this helper's caller return address.
    addi sp, sp, 16              # Release the stack frame before returning.
    ret

# Display the prompt and the current input value.
display_input:
    addi sp, sp, -16
    sw   ra, 12(sp)
    jal  ra, display_prompt
    li   a0, 0                   # lcd_i2c_set_cursor: a0 = column, a1 = row.
    li   a1, 1                   # Row 1 is the second LCD line.
    jal  ra, lcd_i2c_set_cursor
    mv   a0, s2                  # Print the numeric entry in decimal.
    jal  ra, lcd_i2c_print_int
    lw   ra, 12(sp)
    addi sp, sp, 16
    ret

# Clear the LCD and display the string whose address is passed in a0.
display_text:
    addi sp, sp, -16
    sw   ra, 12(sp)
    sw   a0, 8(sp)               # Preserve the string address across LCD calls.
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
    sw   a0, 8(sp)               # Save the label address before calling wrappers.
    sw   a1, 4(sp)               # Save the number; wrapper calls may reuse a1.
    jal  ra, lcd_i2c_clear
    lw   a0, 8(sp)
    jal  ra, lcd_i2c_print
    li   a0, 0
    li   a1, 1
    jal  ra, lcd_i2c_set_cursor
    lw   a0, 4(sp)               # Integer printing expects the number in a0.
    jal  ra, lcd_i2c_print_int
    lw   ra, 12(sp)
    addi sp, sp, 16
    ret
