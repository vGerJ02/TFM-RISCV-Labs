# TFM RISC-V Labs

This repository is part of my master's thesis (TFM). It contains RV32I laboratory
programs, the support files needed to run them on an ESP32-C3, and two modified
CREATOR projects.

The activities propose an adaptation of the practical block of *Estructura de
Computadors II* (EC2) at the Universitat de Lleida. Activities 1--3 form the main
sequence; the passcode and Simon Says exercises are alternative or future
activities.

## Repository contents

| Path | Thesis activity | Purpose |
| --- | --- | --- |
| `lab1_ex1_creator.s` | Activity 1, Exercise 1 | Registers, immediates, and arithmetic; simulator version |
| `lab1_ex2_creator.s` | Activity 1, Exercise 2 | Variables, loads, stores, and addition; simulator version |
| `lab1_ex3_creator.s` | Activity 1, Exercise 3 | Multiplication by repeated addition; simulator version |
| `lab1_ex1.s`--`lab1_ex3.s` | Activity 1 | ESP32-C3 versions that display results on an I2C LCD |
| `lab2_ex.s` | Activity 2 | Halfword vectors, arithmetic, and loops |
| `lab3_ex.s` | Activity 3 | Keypad data entry and count/sum/minimum/maximum statistics |
| `keypad_passcode.s` | Alternative/future activity | Four-digit keypad access-control exercise |
| `simon_says.s` | Alternative/future activity | Five-level Simon Says game using LEDs and buttons |
| `creator_liquidcrystal_i2c_wrapper.cpp` | Hardware support | C bridge between assembly and `LiquidCrystal_I2C` |
| `creator_keypad_wrapper.cpp` | Hardware support | C bridge between assembly and `Keypad` |
| `LiquidCrystal_I2C-1.1.3.zip` | Hardware support | Arduino LCD library uploaded through CREATOR |
| `Keypad-3.1.1.zip` | Hardware support | Arduino keypad library uploaded through CREATOR |
| `creator/` | Git submodule | CREATOR fork with external Arduino-library upload support |
| `creator-gateway-esp32/` | Git submodule | Gateway fork that validates, builds, and flashes uploaded libraries and bridges |

The assembly files also contain exercise-specific usage, wiring, and expected
result comments.

## Download the repository and its submodules

The two forks are Git submodules pinned to the revisions used for the thesis.
Do not use GitHub's **Download ZIP** option: a ZIP of this repository does not
contain submodule contents.

To clone with SSH:

```sh
git clone --recurse-submodules git@github.com:vGerJ02/TFM-RISCV-Labs.git
cd TFM-RISCV-Labs
```

If this repository was already cloned and the submodule directories are
empty, run:

```sh
git submodule update --init --recursive
```

## Run CREATOR

The custom version of CREATOR with Arduino-library upload support is available
on [GitHub Pages](https://vgerj02.github.io/creator/). It can also be deployed
locally from the `creator/` submodule by following its
[local setup and build instructions](creator/docs/dev.md).

In CREATOR, select a 32-bit RISC-V architecture compatible with CREATino, such as
**RISC-V (RV32IMFD)**, and open the assembly editor. For exercises using CREATino
or external libraries, load the required support as described below before
compiling. The exercise assembly stays within RV32I and does not require the
`M` or `C` extensions.

## Start the modified CREATOR Gateway

An ESP32 RISC-V (the thesis uses an ESP-32 C3 SuperMini board) and Docker Engine or 
Docker Desktop are required for physical execution. The supplied 
`creator-gateway-esp32/compose.yml` builds the modified gateway fork and starts it with 
the required configuration. This ensures that the library-upload extension in the 
CREATOR fork has a matching backend.

After configuring the serial device as described below, start the gateway from
the repository root with:

```sh
cd creator-gateway-esp32
docker compose up --build
```

Press `Ctrl+C` to stop it. The gateway listens on port `8080`; port `5000` is
used by its debugging tools.

### Linux and macOS

Connect the ESP32-C3 and locate its serial device:

```sh
ls /dev/ttyUSB*          # Linux
ls /dev/cu.usbserial-*   # macOS
```

The Compose file uses `/dev/ttyUSB0` by default. If the detected path differs,
replace it under `services.creator-gateway-esp32.devices` in
`creator-gateway-esp32/compose.yml`, then run `docker compose up --build` as
shown above.

On Linux, the current user must have permission to access the serial device.

### Windows

Docker Desktop cannot pass the Windows serial port directly to this container.
Install `esptool`, identify the board's port with Device Manager or `mode`, and
start its RFC2217 server. Replace `COM3` below with the detected port:

```powershell
python -m pip install esptool
esp_rfc2217_server -v -p 4000 COM3
```

Leave that terminal running. Because Windows uses the RFC2217 connection
instead of direct device passthrough, remove or comment out the `devices`
section in `creator-gateway-esp32/compose.yml`. In a second terminal, start the
gateway:

```powershell
cd creator-gateway-esp32
docker compose up --build
```

In CREATOR's target-flash settings, select the ESP32-C3. On Windows, set the
target port to
`rfc2217://host.docker.internal:4000?ign_set_control`; on Linux or macOS, use
the serial-device path passed to Docker. Keep the gateway running for the
laboratory session.

## Use an exercise

Start Activity 1 with the simulator versions, inspecting registers and memory
step by step, then use the corresponding LCD versions on the ESP32-C3. Activity 2
uses the simulator's register and memory views. Activity 3 extends the sequence
with keypad input, stored values, subroutines, and LCD output.

### Simulation-only exercises

Use the `*_creator.s` form of Activity 1. These files print their results with
CREATOR `ecall`s and do not need CREATino, a gateway, or external libraries.
`lab2_ex.s` is likewise intended for inspection in the simulator's register
and memory views.

### ESP32-C3 exercises using the LCD or keypad

These programs require the custom CREATOR version (online or deployed locally)
and the modified gateway:

- `lab1_ex1.s`, `lab1_ex2.s`, and `lab1_ex3.s`: upload
  `LiquidCrystal_I2C-1.1.3.zip` with
  `creator_liquidcrystal_i2c_wrapper.cpp` as its bridge.
- `lab3_ex.s` and `keypad_passcode.s`: upload both ZIP libraries, pairing each
  ZIP with its corresponding `creator_*_wrapper.cpp` bridge.

In the CREATOR editor:

1. choose **Library → Add Arduino Library** to load CREATino;
2. enable **Arduino Support** in the target-flash view;
3. click **Arduino** in the assembly toolbar to open the external-library dialog
   and select an Arduino library ZIP;
4. import its matching `.cpp` bridge and review the detected `extern "C"`
   functions;
5. click **Add Library**, then repeat for the second library when the exercise
   uses both;
6. load and compile the assembly file; and
7. flash it through the gateway at <http://localhost:8080>.

Assembly passes arguments to a bridge function in `a0` through `a7` and
receives its return value in `a0`, following the RISC-V calling convention.
Uploaded libraries are accepted only when Arduino Support/CREATino mode is
enabled. The supplied `lcd_i2c_*` and `keypad_*` functions come from these bridges;
they are not built-in CREATino functions. The gateway compiles and links the
libraries and bridges with the assembly program into the board's firmware.

For Activity 3, the proposed simulator check uses a prepared sequence of key
codes to verify the array, count, and statistics before testing the physical
keypad and LCD. The supplied `lab3_ex.s` is the hardware implementation; this
repository does not include a separate simulator test harness. Such a test needs
simulated inputs and replacements for the hardware bridge calls. Uploading the
C++ libraries makes their symbols available to the assembler, but does not
simulate their hardware behaviour in the browser.

The LCD examples assume a 16-by-2 I2C module at address `0x27`, with SDA on
GPIO 5 and SCL on GPIO 6. The keypad programs use this mapping:

| Keypad pin | ESP32-C3 GPIO | Role |
| --- | --- | --- |
| 8, 7, 6, 5 | 0, 1, 2, 3 | Rows 0--3 |
| 4, 3, 2, 1 | 21, 20, 10, 7 | Columns 0--3 |

### ESP32-C3 exercise using only CREATino

`simon_says.s` calls `pinMode`, `digitalRead`, `digitalWrite`, and `delay`
directly. Load CREATino and enable **Arduino Support**, but do not upload an
external Arduino library or bridge.

| Colour | LED GPIO | Button GPIO |
| --- | ---: | ---: |
| Red | 0 | 5 |
| Green | 1 | 6 |
| Blue | 3 | 7 |
| Yellow | 4 | 10 |

Each button is connected between its GPIO and ground; the program enables the
internal pull-up, so a pressed button reads low. Use suitable current-limiting
resistors with the LEDs.

## Expected results

| Exercise | Check |
| --- | --- |
| Activity 1, Exercise 1 | `s0`--`s5` finish at `0x0002`, `0x1C1E`, `0x65DE`, `0x0014`, `0x0002`, and `0x1C20`. Compare the selected LCD values with the simulator. |
| Activity 1, Exercise 2 | `var1` and `var3` remain `1` and `3`; `res` becomes `4`. |
| Activity 1, Exercise 3 | Repeated addition of `20` three times leaves `60` (`0x003C`) in `s0` and the loop counter at zero. |
| Activity 2 | `resu` becomes `{11, 15, 19, 23, 27}`; each vector pointer advances 10 bytes and the loop counter reaches zero. |
| Activity 3 | Enter `12#`, `7#`, and `105#`. Keys `A`, `B`, `C`, and `D` show count `3`, sum `124`, minimum `7`, and maximum `105`. |
| Passcode | `1234` displays `Access granted`; `1235` displays `Denied`. Each attempt returns to the prompt, and `*` cancels an unfinished entry. Attempt limits and lockout are optional extensions. |
| Simon Says | Press and release the red button to start. Repeat the growing sequence from one to five colours. A wrong input ends the game; completing level five plays the success animation and returns to the start state. |

Activity 3 accepts up to eight values from `0` to `999`, with at most three
digits per entry. `#` stores a nonempty entry; `*` cancels an entry or clears all
stored values when no entry is in progress. Statistics remain available when
storage is full. Check the `No data` and `Memory full` cases as well.
