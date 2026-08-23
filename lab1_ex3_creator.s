# Vanilla CREATOR version of Activity 1, Exercise 3.
# The multiplication state is printed with CREATOR ecalls.

.data
# CREATOR does not currently support .equ, so these constants are stored
# in memory like normal variables.
CONSTANT1:
    .word 20
CONSTANT2:
    .word 3

result_text:    .asciz "result = "
constant1_text: .asciz "CONSTANT1 = "
counter_text:   .asciz "final counter = "
constant2_text: .asciz "CONSTANT2 = "

.text
.globl main
main:
    li s0, 0

    la s4, CONSTANT1
    la s5, CONSTANT2
    lw s1, 0(s4)
    lw s3, 0(s5)
    mv s2, s3

    beqz s2, multiplication_done

multiplication_loop:
    add s0, s0, s1
    addi s2, s2, -1
    bnez s2, multiplication_loop

multiplication_done:
    la a0, result_text
    mv a1, s0
    jal ra, print_labeled_int

    la a0, constant1_text
    mv a1, s1
    jal ra, print_labeled_int

    la a0, counter_text
    mv a1, s2
    jal ra, print_labeled_int

    la a0, constant2_text
    mv a1, s3
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
