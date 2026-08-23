.data

operand1:
    .half 0x0001, 0x0002, 0x0003, 0x0004, 0x0005

operand2:
    .half 0x0005, 0x0005, 0x0005, 0x0005, 0x0005

resu:
    .half 0x0001, 0x0001, 0x0001, 0x0001, 0x0001


    .text
    .globl main

main:
    la   t0, operand1      # t0 = address of operand1[0]
    la   t1, operand2      # t1 = address of operand2[0]
    la   t2, resu          # t2 = address of resu[0]

    li   t3, 5             # loop counter: 5 elements

loop:
    lh   t4, 0(t0)         # t4 = operand1[i]
    lh   t5, 0(t1)         # t5 = operand2[i]

    slli t4, t4, 1         # t4 = 2 * operand1[i]
    add  t4, t4, t5        # t4 = 2 * operand1[i] + operand2[i]
    slli t4, t4, 1         # t4 = 2 * (2 * operand1[i] + operand2[i])
    addi t4, t4, -3        # t4 = 2 * (...) - 3

    sh   t4, 0(t2)         # resu[i] = result

    addi t0, t0, 2         # next operand1 element
    addi t1, t1, 2         # next operand2 element
    addi t2, t2, 2         # next resu element

    addi t3, t3, -1        # counter--
    bnez t3, loop          # repeat while counter != 0

end:
    li   a7, 10            # CREATOR Exit service
    ecall
