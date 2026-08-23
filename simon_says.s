# Simon Says using CREATino.
#
# Colours and GPIO connections:
#   0 = red:    LED 0, button 5
#   1 = green:  LED 1, button 6
#   2 = blue:   LED 3, button 7
#   3 = yellow: LED 4, button 10
#
# Each button is connected between its GPIO pin and ground. The internal
# pull-up resistors make a pressed button read LOW.

.data
.align 2
led_pins:
    .word 0, 1, 3, 4
button_pins:
    .word 5, 6, 7, 10
sequence:
    .zero 20
random_state:
    .word 0x12345678

.text
.globl main
.globl setup
.globl loop

# CREATOR entry point.
main:
    jal  ra, setup

main_loop:
    jal  ra, loop
    j    main_loop

# Return a pseudo-random colour from 0 to 3 using Marsaglia's Xorshift32.
get_random_color:
    la   t0, random_state
    lw   t1, 0(t0)

    slli t2, t1, 13
    xor  t1, t1, t2
    srli t2, t1, 17
    xor  t1, t1, t2
    slli t2, t1, 5
    xor  t1, t1, t2

    sw   t1, 0(t0)
    andi a0, t1, 3
    ret

# Set all four LEDs to the state passed in a0.
set_all_leds:
    addi sp, sp, -16
    sw   ra, 12(sp)
    sw   s0, 8(sp)
    sw   s1, 4(sp)

    mv   s0, a0
    li   s1, 0

set_all_leds_loop:
    li   t0, 4
    bge  s1, t0, set_all_leds_done

    la   t0, led_pins
    slli t1, s1, 2
    add  t0, t0, t1
    lw   a0, 0(t0)
    mv   a1, s0
    jal  ra, digitalWrite

    addi s1, s1, 1
    j    set_all_leds_loop

set_all_leds_done:
    lw   s1, 4(sp)
    lw   s0, 8(sp)
    lw   ra, 12(sp)
    addi sp, sp, 16
    ret

# Flash colour a0 for a1 milliseconds.
flash_led:
    addi sp, sp, -16
    sw   ra, 12(sp)
    sw   s0, 8(sp)
    sw   s1, 4(sp)

    mv   s0, a0
    mv   s1, a1

    la   t0, led_pins
    slli t1, s0, 2
    add  t0, t0, t1
    lw   a0, 0(t0)
    li   a1, 1                   # HIGH
    jal  ra, digitalWrite

    mv   a0, s1
    jal  ra, delay

    la   t0, led_pins
    slli t1, s0, 2
    add  t0, t0, t1
    lw   a0, 0(t0)
    li   a1, 0                   # LOW
    jal  ra, digitalWrite

    lw   s1, 4(sp)
    lw   s0, 8(sp)
    lw   ra, 12(sp)
    addi sp, sp, 16
    ret

# Wait for a debounced button press and return its colour in a0.
read_button:
    addi sp, sp, -16
    sw   ra, 12(sp)
    sw   s0, 8(sp)
    sw   s1, 4(sp)
    sw   s2, 0(sp)

read_button_scan:
    li   s0, 0

read_button_next:
    li   t0, 4
    bge  s0, t0, read_button_scan

    la   t0, button_pins
    slli t1, s0, 2
    add  t0, t0, t1
    lw   s1, 0(t0)

    mv   a0, s1
    jal  ra, digitalRead
    bnez a0, read_button_not_pressed

    li   a0, 20
    jal  ra, delay

    mv   a0, s1
    jal  ra, digitalRead
    bnez a0, read_button_not_pressed

    la   t0, led_pins
    slli t1, s0, 2
    add  t0, t0, t1
    lw   s2, 0(t0)

    mv   a0, s2
    li   a1, 1                   # HIGH
    jal  ra, digitalWrite

read_button_wait_release:
    mv   a0, s1
    jal  ra, digitalRead
    beqz a0, read_button_wait_release

    mv   a0, s2
    li   a1, 0                   # LOW
    jal  ra, digitalWrite

    li   a0, 20
    jal  ra, delay

    mv   a0, s0
    j    read_button_done

read_button_not_pressed:
    addi s0, s0, 1
    j    read_button_next

read_button_done:
    lw   s2, 0(sp)
    lw   s1, 4(sp)
    lw   s0, 8(sp)
    lw   ra, 12(sp)
    addi sp, sp, 16
    ret

# Wait for the red button to be pressed and released.
wait_for_start:
    addi sp, sp, -16
    sw   ra, 12(sp)

wait_for_start_press:
    li   a0, 5
    jal  ra, digitalRead
    bnez a0, wait_for_start_press

    li   a0, 20
    jal  ra, delay

wait_for_start_release:
    li   a0, 5
    jal  ra, digitalRead
    beqz a0, wait_for_start_release

    li   a0, 20
    jal  ra, delay

    lw   ra, 12(sp)
    addi sp, sp, 16
    ret

# Display the first a0 elements of the sequence.
show_sequence:
    addi sp, sp, -16
    sw   ra, 12(sp)
    sw   s0, 8(sp)
    sw   s1, 4(sp)

    mv   s1, a0
    li   a0, 500
    jal  ra, delay
    li   s0, 0

show_sequence_loop:
    bge  s0, s1, show_sequence_done

    la   t0, sequence
    slli t1, s0, 2
    add  t0, t0, t1
    lw   a0, 0(t0)
    li   a1, 400
    jal  ra, flash_led

    li   a0, 200
    jal  ra, delay

    addi s0, s0, 1
    j    show_sequence_loop

show_sequence_done:
    lw   s1, 4(sp)
    lw   s0, 8(sp)
    lw   ra, 12(sp)
    addi sp, sp, 16
    ret

# Read a0 colours from the player. Return 1 if all are correct.
check_player:
    addi sp, sp, -16
    sw   ra, 12(sp)
    sw   s0, 8(sp)
    sw   s1, 4(sp)

    mv   s1, a0
    li   s0, 0

check_player_loop:
    bge  s0, s1, check_player_correct

    jal  ra, read_button
    mv   t2, a0

    la   t0, sequence
    slli t1, s0, 2
    add  t0, t0, t1
    lw   t0, 0(t0)
    bne  t2, t0, check_player_wrong

    addi s0, s0, 1
    j    check_player_loop

check_player_correct:
    li   a0, 1
    j    check_player_done

check_player_wrong:
    li   a0, 0

check_player_done:
    lw   s1, 4(sp)
    lw   s0, 8(sp)
    lw   ra, 12(sp)
    addi sp, sp, 16
    ret

# Flash every LED twice after a correct level.
correct_animation:
    addi sp, sp, -16
    sw   ra, 12(sp)
    sw   s0, 8(sp)

    li   s0, 2

correct_animation_loop:
    li   a0, 1                   # HIGH
    jal  ra, set_all_leds
    li   a0, 150
    jal  ra, delay

    li   a0, 0                   # LOW
    jal  ra, set_all_leds
    li   a0, 150
    jal  ra, delay

    addi s0, s0, -1
    bnez s0, correct_animation_loop

    lw   s0, 8(sp)
    lw   ra, 12(sp)
    addi sp, sp, 16
    ret

# Flash every LED three times after an incorrect sequence.
wrong_animation:
    addi sp, sp, -16
    sw   ra, 12(sp)
    sw   s0, 8(sp)

    li   s0, 3

wrong_animation_loop:
    li   a0, 1                   # HIGH
    jal  ra, set_all_leds
    li   a0, 350
    jal  ra, delay

    li   a0, 0                   # LOW
    jal  ra, set_all_leds
    li   a0, 350
    jal  ra, delay

    addi s0, s0, -1
    bnez s0, wrong_animation_loop

    lw   s0, 8(sp)
    lw   ra, 12(sp)
    addi sp, sp, 16
    ret

# Configure the four LED and button pairs.
setup:
    addi sp, sp, -16
    sw   ra, 12(sp)
    sw   s0, 8(sp)
    sw   s1, 4(sp)

    li   s0, 0

setup_loop:
    li   t0, 4
    bge  s0, t0, setup_done

    slli s1, s0, 2

    la   t0, led_pins
    add  t0, t0, s1
    lw   a0, 0(t0)
    li   a1, 0x03                # OUTPUT
    jal  ra, pinMode

    la   t0, button_pins
    add  t0, t0, s1
    lw   a0, 0(t0)
    li   a1, 0x05                # INPUT_PULLUP
    jal  ra, pinMode

    la   t0, led_pins
    add  t0, t0, s1
    lw   a0, 0(t0)
    li   a1, 0                   # LOW
    jal  ra, digitalWrite

    addi s0, s0, 1
    j    setup_loop

setup_done:
    lw   s1, 4(sp)
    lw   s0, 8(sp)
    lw   ra, 12(sp)
    addi sp, sp, 16
    ret

# Play one game. main calls this function repeatedly.
loop:
    addi sp, sp, -16
    sw   ra, 12(sp)
    sw   s0, 8(sp)
    sw   s1, 4(sp)

    jal  ra, wait_for_start
    li   s0, 1                  # Current level
    li   s1, 1                  # Correct so far

game_loop:
    li   t0, 5                   # MAX_LEVEL
    bgt  s0, t0, game_won
    beqz s1, game_lost

    # Add one colour at sequence[level - 1].
    jal  ra, get_random_color
    la   t0, sequence
    addi t1, s0, -1
    slli t1, t1, 2
    add  t0, t0, t1
    sw   a0, 0(t0)

    mv   a0, s0
    jal  ra, show_sequence

    mv   a0, s0
    jal  ra, check_player
    mv   s1, a0
    beqz s1, game_lost

    jal  ra, correct_animation
    addi s0, s0, 1
    li   a0, 500
    jal  ra, delay
    j    game_loop

game_lost:
    jal  ra, wrong_animation
    j    game_finished

game_won:
    jal  ra, correct_animation
    jal  ra, correct_animation
    jal  ra, correct_animation

game_finished:
    li   a0, 0                   # LOW
    jal  ra, set_all_leds
    li   a0, 500
    jal  ra, delay

    lw   s1, 4(sp)
    lw   s0, 8(sp)
    lw   ra, 12(sp)
    addi sp, sp, 16
    ret
