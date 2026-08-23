# Vanilla CREATOR version of Activity 1, Exercise 1.
# The result registers are printed as decimal integers with CREATOR ecalls.

.data
s0_text: .asciz "s0 = "
s1_text: .asciz "s1 = "
s2_text: .asciz "s2 = "
s3_text: .asciz "s3 = "
s4_text: .asciz "s4 = "
s5_text: .asciz "s5 = "

.text
.globl main
main:
    li s0, 0x0002
    li s1, 0b0001110000011110
    li s2, ('e' << 8) | 0xDE
    li s3, 20
    mv s4, s0
    add s5, s1, s0

    la a0, s0_text
    mv a1, s0
    jal ra, print_labeled_int

    la a0, s1_text
    mv a1, s1
    jal ra, print_labeled_int

    la a0, s2_text
    mv a1, s2
    jal ra, print_labeled_int

    la a0, s3_text
    mv a1, s3
    jal ra, print_labeled_int

    la a0, s4_text
    mv a1, s4
    jal ra, print_labeled_int

    la a0, s5_text
    mv a1, s5
    jal ra, print_labeled_int

    li a7, 10                      # Exit
    ecall

# Print the label in a0, the integer in a1, and a newline.
print_labeled_int:
    addi sp, sp, -16
    sw a1, 12(sp)

    li a7, 4                       # Print_string
    ecall

    lw a0, 12(sp)
    li a7, 1                       # Print_int
    ecall

    li a0, 10                      # ASCII newline
    li a7, 11                      # Print_char
    ecall

    addi sp, sp, 16
    ret
