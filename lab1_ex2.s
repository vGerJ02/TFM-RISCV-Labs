# Adds var1 and var3, stores the result in res, and displays the four most
# relevant registers on a 16x2 I2C LCD.
#
# Required wrapper:
#   creator_liquidcrystal_i2c_wrapper.cpp
#
# LCD wiring:
#   SDA -> board GPIO 5
#   SCL -> board GPIO 6
#
# Display layout:
#   R2=res address   R3=var1 value
#   R4=var3 value    R5=sum
#
# Values are displayed as four hexadecimal digits. For an address, this means
# that the LCD shows its lowest 16 bits.

.data
# Variables required by the exercise.
var1:
    .word 1
var3:
    .word 3
res:
    .word 0

# lcd_show_register modifies this template before printing it.
register_text:
    .asciz "R0=0000"

.text
# Place the first program instruction at memory offset 0x200.
# .org 0x200
.globl main
main:
    # Use saved registers because the C++ LCD wrapper preserves s0-s5.
    # They represent the exercise's logical registers R0-R5.

    # R0, R1, and R2 receive the addresses of the three variables.
    la s0, var1
    la s1, var3
    la s2, res

    # R3 receives var1 (1) and R4 receives var3 (3).
    lw s3, 0(s0)
    lw s4, 0(s1)

    # R5 receives the sum: 1 + 3 = 4.
    add s5, s3, s4

    # Store R5 in res. The variable changes from 0 to 4.
    sw s5, 0(s2)

    # Initialize the Arduino environment before using the LCD library.
    jal ra, initArduino

    # Wait briefly for the LCD controller to become ready.
    li a0, 200
    jal ra, delay

    # Initialize a 16x2 LCD at address 0x27.
    # a0 = SDA GPIO, a1 = SCL GPIO.
    li a0, 5
    li a1, 6
    jal ra, lcd_i2c_begin_default

    # Clear old text before writing the four selected registers.
    jal ra, lcd_i2c_clear

    # Slots: 0 = top-left, 1 = top-right,
    #        2 = bottom-left, 3 = bottom-right.

    # Show R2, the address where the result was stored.
    li a0, 2
    mv a1, s2
    li a2, 0
    jal ra, lcd_show_register

    # Show R3, the value loaded from var1.
    li a0, 3
    mv a1, s3
    li a2, 1
    jal ra, lcd_show_register

    # Show R4, the value loaded from var3.
    li a0, 4
    mv a1, s4
    li a2, 2
    jal ra, lcd_show_register

    # Show R5, the result of the addition.
    li a0, 5
    mv a1, s5
    li a2, 3
    jal ra, lcd_show_register

# CREATOR's Exit ecall is not available in ESP32 firmware. Stay here so the
# program does not fall through into the LCD helper below.
finished:
    j finished

# Displays one register using the format "Rn=XXXX".
#
# Arguments:
#   a0 = register number from 0 to 9
#   a1 = register value
#   a2 = LCD slot from 0 to 3
lcd_show_register:
    # Preserve the return address and LCD slot. The other argument registers
    # can be reused after their values have been formatted.
    addi sp, sp, -16
    sw ra, 12(sp)
    sw a2, 8(sp)

    # Change the register digit in the "R0=0000" template.
    la a2, register_text
    addi a0, a0, 48              # Number 0..9 -> ASCII '0'..'9'
    sb a0, 1(a2)

    # Point to the first value digit and begin with bits 15..12.
    addi a3, a2, 3
    li a4, 12

format_hex_digit:
    # Extract one four-bit hexadecimal digit from the register value.
    srl a5, a1, a4
    andi a5, a5, 0x0F

    # Convert values 0..9 to '0'..'9' and 10..15 to 'A'..'F'.
    li a6, 10
    blt a5, a6, decimal_digit
    addi a5, a5, 55
    j store_digit

decimal_digit:
    addi a5, a5, 48

store_digit:
    # Store this digit, then continue with shifts 8, 4, and 0.
    sb a5, 0(a3)
    addi a3, a3, 1
    addi a4, a4, -4
    bgez a4, format_hex_digit

    # Convert the slot into a cursor position. Odd slots start at column 8;
    # slots 2 and 3 are placed on the second row.
    lw a2, 8(sp)
    andi a0, a2, 1
    slli a0, a0, 3
    srli a1, a2, 1
    jal ra, lcd_i2c_set_cursor

    # Print the completed null-terminated string.
    la a0, register_text
    jal ra, lcd_i2c_print

    # Restore the return address and release the stack frame.
    lw ra, 12(sp)
    addi sp, sp, 16
    ret
