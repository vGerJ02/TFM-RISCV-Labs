# Feu programa que comenci en la posició 200h de la memòria, defineixi dues 
# constants CONSTANT1=14h (20 decimal) i CONSTANT2= 03h (3 decimal) i posi en
# el registre R0 el resultat de multiplicar CONSTANT1 x CONSTANT2 

# -----------------------------------------------------------------------------
# NOTE ON CONSTANTS IN CREATOR: 
# Standard RISC-V uses '.equ CONSTANT_NAME, value' to define constants, which
# can then be loaded directly using 'li register, CONSTANT_NAME'. However, 
# since the Creator simulator does not currently support '.equ' or '.set'
# directives, values must be passed as raw immediates (like below) or stored
# inside a '.data' block and read using 'la' and 'lw'.
# -----------------------------------------------------------------------------

# Multiplies CONSTANT1 by CONSTANT2 using repeated addition and displays the
# four relevant registers on a 16x2 I2C LCD.
#
# Required wrapper:
#   creator_liquidcrystal_i2c_wrapper.cpp
#
# LCD wiring:
#   SDA -> board GPIO 5
#   SCL -> board GPIO 6
#
# Displayed values after multiplication:
#   R0=003C  R1=0014
#   R2=0000  R3=0003

.data
# Constants are stored in memory because CREATOR does not support .equ or .set.
CONSTANT1:
    .word 20                       # 14h = 20 decimal
CONSTANT2:
    .word 3                        # 03h = 3 decimal

# lcd_show_register modifies this template before printing it.
register_text:
    .asciz "R0=0000"

.text
# Place the first program instruction at memory offset 0x200.
.org 0x200
.globl main
main:
    # Logical register usage:
    #   R0 / s0 = accumulated result
    #   R1 / s1 = CONSTANT1 (the value added on every iteration)
    #   R2 / s2 = loop counter, which finishes at zero
    #   R3 / s3 = original CONSTANT2 value for display
    #   s4      = address of CONSTANT1
    #   s5      = address of CONSTANT2
    # Saved registers are used because the C++ LCD calls preserve them.

    # Initialize R0 before beginning the repeated addition.
    li s0, 0

    # Load both constants from memory.
    la s4, CONSTANT1
    la s5, CONSTANT2
    lw s1, 0(s4)                   # R1 = 20
    lw s3, 0(s5)                   # R3 = 3, preserved for the LCD

    # Copy CONSTANT2 into R2 because R2 is changed by the loop.
    mv s2, s3

    # If CONSTANT2 is zero, the correct result is already zero.
    beqz s2, multiplication_done

multiplication_loop:
    # Add CONSTANT1 once for each unit in CONSTANT2.
    add s0, s0, s1                 # R0 = R0 + R1

    # Decrease the number of additions still required.
    addi s2, s2, -1                # R2 = R2 - 1

    # Continue until R2 reaches zero. After three iterations R0 is 60 (3Ch).
    bnez s2, multiplication_loop

multiplication_done:
    # Initialize the Arduino environment before using the LCD library.
    jal ra, initArduino

    # Wait briefly for the LCD controller to become ready.
    li a0, 200
    jal ra, delay

    # Initialize a 16x2 LCD at I2C address 0x27.
    # a0 = SDA GPIO, a1 = SCL GPIO.
    li a0, 5
    li a1, 6
    jal ra, lcd_i2c_begin_default

    # Remove any previous text from the LCD.
    jal ra, lcd_i2c_clear

    # Slots: 0 = top-left, 1 = top-right,
    #        2 = bottom-left, 3 = bottom-right.

    # Show R0, the final multiplication result (003Ch).
    li a0, 0
    mv a1, s0
    li a2, 0
    jal ra, lcd_show_register

    # Show R1, CONSTANT1 (0014h).
    li a0, 1
    mv a1, s1
    li a2, 1
    jal ra, lcd_show_register

    # Show R2, the loop counter after it reaches zero.
    li a0, 2
    mv a1, s2
    li a2, 2
    jal ra, lcd_show_register

    # Show R3, the original value of CONSTANT2 (0003h).
    li a0, 3
    mv a1, s3
    li a2, 3
    jal ra, lcd_show_register

# Keep the program active so the LCD contents remain visible.
finished:
    j finished

# Displays one register using the format "Rn=XXXX".
#
# Arguments:
#   a0 = register number from 0 to 9
#   a1 = register value
#   a2 = LCD slot from 0 to 3
lcd_show_register:
    # Preserve the return address and LCD slot. The slot is needed after the
    # register value has been converted into text.
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
