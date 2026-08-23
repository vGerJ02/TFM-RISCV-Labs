# Fes un programa que comenci en la posició 200h de la memòria i que carregui
# en el registres indicats els següents valors i/o operacions:
#
# R0 -> 0002h
# R1 -> 0001110000011110b
# Part alta R2 -> codi ascii de la lletra 'e'
# Part baixa R2 -> DEh
# R3 -> 20 decimal
# R4 -> R0
# R5 -> R1+R0 

# Required wrapper:
#   creator_liquidcrystal_i2c_wrapper.cpp
# LCD wiring:
#   SDA -> board GPIO 5
#   SCL -> board GPIO 6

.data
# This string is modified by lcd_show_register before it is printed.
register_text:
    .asciz "R0=0000"

.text
.globl main
main:
    # The exercise's R0-R5 values are stored in s0-s5. The C++ wrapper
    # preserves saved registers, so their values survive every LCD call.

    # R0 = 0002h
    li s0, 0x0002

    # R1 = 0001110000011110b = 1C1Eh
    li s1, 0b0001110000011110

    # R2 high byte = ASCII 'e' (65h), low byte = DEh; R2 = 65DEh
    li s2, ('e' << 8) | 0xDE

    # R3 = 20 decimal = 0014h
    li s3, 20

    # R4 receives a copy of R0.
    mv s4, s0

    # R5 receives R1 + R0 = 1C20h.
    add s5, s1, s0

    # Initialize the Arduino environment before calling Arduino libraries.
    jal ra, initArduino

    # Wait 200 ms to give the LCD controller time to become ready.
    li a0, 200
    jal ra, delay

    # Default LCD: I2C address 0x27, 16 columns, 2 rows.
    # The wrapper receives SDA in a0 and SCL in a1.
    li a0, 5
    li a1, 6
    jal ra, lcd_i2c_begin_default

    # Remove any old text and return the cursor to the first position.
    jal ra, lcd_i2c_clear

    # Choose up to four registers here. Slots are:
    #   0 = top-left, 1 = top-right, 2 = bottom-left, 3 = bottom-right.
    # Each call passes the register number, value, and destination slot.
    # Change or remove these calls to select which registers are displayed.

    # Show R0 in the top-left slot.
    li a0, 0                       # Register number
    mv a1, s0                      # Register value
    li a2, 0                       # LCD slot
    jal ra, lcd_show_register

    # Show R1 in the top-right slot.
    li a0, 1
    mv a1, s1
    li a2, 1
    jal ra, lcd_show_register

    # Show R2 in the bottom-left slot.
    li a0, 2
    mv a1, s2
    li a2, 2
    jal ra, lcd_show_register

    # Show R3 in the bottom-right slot.
    li a0, 3
    mv a1, s3
    li a2, 3
    jal ra, lcd_show_register

# CREATOR's Exit ecall is not available in ESP32 firmware. Stay here so the
# program does not fall through into the LCD helper below.
finished:
    j finished

# Displays one register as "Rn=XXXX".
# a0 = register number (0..9), a1 = value, a2 = LCD slot (0..3)
lcd_show_register:
    # Reserve stack space and preserve the return address. Save the slot
    # because a2 will be reused as a pointer while formatting the text.
    addi sp, sp, -16
    sw ra, 12(sp)
    sw a2, 8(sp)

    # Start with "R0=0000" and replace its register digit and value.
    la a2, register_text

    # Convert register number 0..9 into its ASCII character '0'..'9'.
    addi a0, a0, 48
    sb a0, 1(a2)

    # Point a3 at the first hexadecimal digit after "Rn=".
    addi a3, a2, 3

    # Begin with the highest nibble, bits 15..12.
    li a4, 12

format_hex_digit:
    # Move the selected nibble into the lowest four bits and isolate it.
    srl a5, a1, a4
    andi a5, a5, 0x0F

    # Convert nibble 0..9 to '0'..'9', or 10..15 to 'A'..'F'.
    li a6, 10
    blt a5, a6, decimal_digit
    addi a5, a5, 55             # 10..15 -> 'A'..'F'
    j store_digit

decimal_digit:
    addi a5, a5, 48             # 0..9 -> '0'..'9'

store_digit:
    # Write this character, advance the string pointer, and select the next
    # nibble. Shift values are 12, 8, 4, and 0.
    sb a5, 0(a3)
    addi a3, a3, 1
    addi a4, a4, -4
    bgez a4, format_hex_digit

    # Convert slot 0..3 into an LCD column and row.
    # Even slots use column 0 and odd slots use column 8.
    # Slots 0/1 use row 0; slots 2/3 use row 1.
    lw a2, 8(sp)
    andi a0, a2, 1
    slli a0, a0, 3
    srli a1, a2, 1
    jal ra, lcd_i2c_set_cursor

    # Print the completed null-terminated "Rn=XXXX" string.
    la a0, register_text
    jal ra, lcd_i2c_print

    # Restore the return address and release this function's stack space.
    lw ra, 12(sp)
    addi sp, sp, 16
    ret
