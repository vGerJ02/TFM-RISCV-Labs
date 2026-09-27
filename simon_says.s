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
#
# Register usage:
#   s0 = current level in loop; helpers use it for an index, colour, LED state,
#        or remaining animation flashes
#   s1 = player result in loop; helpers use it for a colour count, GPIO pin,
#        flash duration, loop index, or byte offset
#   s2 = matching LED GPIO pin in read_button
#   t0 = temporary address, comparison limit, or expected colour
#   t1 = array byte offset or pseudo-random state
#   t2 = shifted pseudo-random bits or player's most recent colour
#   a0 = first function argument / return value
#   a1 = second function argument (LED state, pin mode, or flash duration)
#   ra = return address, saved on the stack by functions that call others
#   sp = stack pointer for saved registers and return addresses

.data                        # Stored values (arrays and random seed).
.align 2                     # Align word data to a 4-byte boundary.
led_pins:
    .word 0, 1, 3, 4         # LED GPIO pin for each colour index.
button_pins:
    .word 5, 6, 7, 10        # Matching button GPIO pins.
sequence:
    .zero 20                 # Space for five 4-byte colour indices (five levels).
random_state:
    .word 0x12345678         # Initial seed for the pseudo-random generator.

.text                        # Executable instructions start here.
.globl main
.globl setup
.globl loop

# CREATOR entry point.
main:
    jal  ra, setup

main_loop:
    jal  ra, loop            # Play one game, then wait for another.
    j    main_loop           # j is an unconditional jump.

# Return a pseudo-random colour from 0 to 3 using Marsaglia's Xorshift32.
# This updates a stored number by shifting and XORing its bits; the same seed
# produces the same series of colours each time the program starts.
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
    andi a0, t1, 3           # Keep the lowest two bits: a number from 0 to 3.
    ret

# Set all four LEDs to the state passed in a0.
# digitalWrite expects a0 = GPIO pin and a1 = 1 (on) or 0 (off).
set_all_leds:
    addi sp, sp, -16         # Reserve stack space for registers saved below.
    sw   ra, 12(sp)          # Save caller's return address before using jal.
    sw   s0, 8(sp)
    sw   s1, 4(sp)

    mv   s0, a0              # Keep desired LED state across digitalWrite calls.
    li   s1, 0               # s1 = colour index / loop counter.

set_all_leds_loop:
    li   t0, 4
    # Stop when index >= 4.
    bge  s1, t0, set_all_leds_done

    la   t0, led_pins
    slli t1, s1, 2           # Each .word is 4 bytes: byte offset = index * 4.
    add  t0, t0, t1          # Address of led_pins[index].
    lw   a0, 0(t0)           # Load GPIO pin into first function argument.
    mv   a1, s0
    jal  ra, digitalWrite

    addi s1, s1, 1
    j    set_all_leds_loop

set_all_leds_done:
    lw   s1, 4(sp)           # Restore saved registers before returning.
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

    mv   s0, a0              # Save colour and duration; API calls reuse a0/a1.
    mv   s1, a1

    la   t0, led_pins
    slli t1, s0, 2
    add  t0, t0, t1
    lw   a0, 0(t0)
    li   a1, 1                   # HIGH
    jal  ra, digitalWrite

    mv   a0, s1
    jal  ra, delay           # Leave the chosen LED on for s1 milliseconds.

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
# With pull-ups, digitalRead returns 0 while a button is pressed, 1 otherwise.
read_button:
    addi sp, sp, -16
    sw   ra, 12(sp)
    sw   s0, 8(sp)
    sw   s1, 4(sp)
    sw   s2, 0(sp)

read_button_scan:
    li   s0, 0               # Start checking at the red button.

read_button_next:
    li   t0, 4
    # None pressed? Scan all four again.
    bge  s0, t0, read_button_scan

    la   t0, button_pins
    slli t1, s0, 2
    add  t0, t0, t1
    lw   s1, 0(t0)           # Keep this button's GPIO pin across API calls.

    mv   a0, s1
    jal  ra, digitalRead
    bnez a0, read_button_not_pressed  # Nonzero means released.

    li   a0, 20              # Wait for electrical/mechanical bounce to settle.
    jal  ra, delay

    mv   a0, s1
    jal  ra, digitalRead
    bnez a0, read_button_not_pressed  # Ignore a brief false press.

    la   t0, led_pins
    slli t1, s0, 2
    add  t0, t0, t1
    lw   s2, 0(t0)           # Light the matching LED while button is held.

    mv   a0, s2
    li   a1, 1                   # HIGH
    jal  ra, digitalWrite

read_button_wait_release:
    mv   a0, s1
    jal  ra, digitalRead
    beqz a0, read_button_wait_release  # Stay here while input is LOW.

    mv   a0, s2
    li   a1, 0                   # LOW
    jal  ra, digitalWrite

    li   a0, 20
    jal  ra, delay

    mv   a0, s0              # Return the colour index, not the pin number.
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
    li   a0, 5               # Red button is on GPIO 5.
    jal  ra, digitalRead
    bnez a0, wait_for_start_press  # Wait until pressed (LOW).

    li   a0, 20
    jal  ra, delay

wait_for_start_release:
    li   a0, 5
    jal  ra, digitalRead
    beqz a0, wait_for_start_release  # Wait until released (HIGH).

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

    mv   s1, a0              # Number of colours to show this level.
    li   a0, 500
    jal  ra, delay
    li   s0, 0               # Current index into sequence[].

show_sequence_loop:
    bge  s0, s1, show_sequence_done

    la   t0, sequence
    slli t1, s0, 2           # Convert word index to byte offset.
    add  t0, t0, t1
    lw   a0, 0(t0)
    li   a1, 400
    jal  ra, flash_led       # a0 = colour, a1 = duration in ms.

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
    mv   t2, a0              # Player's most recent colour.

    la   t0, sequence
    slli t1, s0, 2
    add  t0, t0, t1
    lw   t0, 0(t0)
    bne  t2, t0, check_player_wrong  # Mismatch ends this round immediately.

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

    li   s0, 2               # Number of on/off flashes remaining.

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

    li   s0, 3               # Slower, longer flashes than the success signal.

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

    slli s1, s0, 2           # Byte offset shared by both GPIO pin arrays.

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
# Each round extends the stored sequence by one colour, plays it, then checks
# the player's input. A mistake ends the game; completing five rounds wins.
loop:
    addi sp, sp, -16
    sw   ra, 12(sp)
    sw   s0, 8(sp)
    sw   s1, 4(sp)

    jal  ra, wait_for_start
    li   s0, 1               # Current level (1 through 5).
    li   s1, 1               # 1 = player was correct; 0 = incorrect.

game_loop:
    li   t0, 5               # MAX_LEVEL
    bgt  s0, t0, game_won    # Level 6 means all five levels were completed.
    beqz s1, game_lost       # Branch if the saved result is zero.

    # Add one colour at sequence[level - 1].
    jal  ra, get_random_color
    la   t0, sequence
    addi t1, s0, -1
    slli t1, t1, 2           # sequence[level - 1] is 4 bytes per entry.
    add  t0, t0, t1
    sw   a0, 0(t0)

    mv   a0, s0
    jal  ra, show_sequence

    mv   a0, s0
    jal  ra, check_player
    mv   s1, a0              # Save check_player's 1/0 result.
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
    ret                      # main_loop will wait for the next start press.
