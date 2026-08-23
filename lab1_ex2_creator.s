# Vanilla CREATOR version of Activity 1, Exercise 2.
# Addresses and values are printed as decimal integers with CREATOR ecalls.

.data
var1:
    .word 1
var3:
    .word 3
res:
    .word 0

var1_addr_text:  .asciz "var1 address = "
var3_addr_text:  .asciz "var3 address = "
res_addr_text:   .asciz "res address = "
var1_value_text: .asciz "var1 value = "
var3_value_text: .asciz "var3 value = "
res_value_text:  .asciz "res value = "

.text
.globl main
main:
    la s0, var1
    la s1, var3
    la s2, res

    lw s3, 0(s0)
    lw s4, 0(s1)
    add s5, s3, s4
    sw s5, 0(s2)

    la a0, var1_addr_text
    mv a1, s0
    jal ra, print_labeled_int

    la a0, var3_addr_text
    mv a1, s1
    jal ra, print_labeled_int

    la a0, res_addr_text
    mv a1, s2
    jal ra, print_labeled_int

    la a0, var1_value_text
    mv a1, s3
    jal ra, print_labeled_int

    la a0, var3_value_text
    mv a1, s4
    jal ra, print_labeled_int

    la a0, res_value_text
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
