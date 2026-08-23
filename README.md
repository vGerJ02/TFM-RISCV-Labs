# TFM RISC-V Labs

This is the standalone companion-code repository for the thesis maintained in the
separate [TFM-RISCV report repository](https://github.com/vGerJ02/TFM-RISCV).

This repository contains the RV32I programs proposed in Chapter 7, the support
files needed to run them on an ESP32-C3, and the two modified CREATOR projects
described in Chapter 6.

## Repository contents

| Path | Thesis activity | Purpose |
| --- | --- | --- |
| `lab1_ex1_creator.s` | Activity 1, Exercise 1 | Registers, immediates, and arithmetic; simulator version |
| `lab1_ex2_creator.s` | Activity 1, Exercise 2 | Variables, loads, stores, and addition; simulator version |
| `lab1_ex3_creator.s` | Activity 1, Exercise 3 | Multiplication by repeated addition; simulator version |
| `lab1_ex1.s`--`lab1_ex3.s` | Activity 1 | ESP32-C3 versions that display results on an I2C LCD |
| `lab2_ex.s` | Activity 2 | Halfword vectors, arithmetic, and loops |
| `lab3_ex.s` | Activity 3 | Keypad data entry and count/sum/minimum/maximum statistics |
| `keypad_passcode.s` | Proposed activity | Keypad access-control exercise |
| `simon_says.s` | Proposed activity | Simon Says game using LEDs and buttons |
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

If the parent repository was already cloned and the submodule directories are
empty, run:

```sh
git submodule update --init --recursive
```

## Run CREATOR

The three `*_creator.s` files and `lab2_ex.s` can be opened in the public
CREATOR web simulator for simulation-only work. Use the local `creator`
submodule for the thesis hardware workflow because it includes the external
Arduino-library dialog.

The `creator` submodule includes a `flake.nix` that can be used to run CREATOR
with Nix:

```sh
cd creator
nix develop
bun install
bun dev:wasm
bun dev:web
```

Open the local URL printed by Vite, normally <http://localhost:5173>. In
CREATOR, select a RISC-V architecture, open the assembly editor, load or paste
an exercise, and compile it. The exercises themselves stay within RV32I.

## Start the modified CREATOR Gateway

An ESP32-C3 and Docker Engine or Docker Desktop are required for physical
execution. The supplied `creator-gateway-esp32/compose.yml` builds the modified
gateway fork and starts it with the required configuration. This ensures that
the library-upload extension in the CREATOR fork has a matching backend.

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
start its RFC2217 server. The thesis uses `COM3` as an example:

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

### Simulation-only exercises

Use the `*_creator.s` form of Activity 1. These files print their results with
CREATOR `ecall`s and do not need CREATino, a gateway, or external libraries.
`lab2_ex.s` is likewise intended for inspection in the simulator's register
and memory views.

### ESP32-C3 exercises using the LCD or keypad

These programs require the modified CREATOR and gateway submodules:

- `lab1_ex1.s`, `lab1_ex2.s`, and `lab1_ex3.s`: upload
  `LiquidCrystal_I2C-1.1.3.zip` with
  `creator_liquidcrystal_i2c_wrapper.cpp` as its bridge.
- `lab3_ex.s` and `keypad_passcode.s`: upload both ZIP libraries, pairing each
  ZIP with its corresponding `creator_*_wrapper.cpp` bridge.

In the CREATOR editor:

1. choose **Library → Load Arduino Library** to load CREATino;
2. enable **Arduino Support** in the target-flash view;
3. open the external-library dialog and select an Arduino library ZIP;
4. import its matching `.cpp` bridge and review the detected `extern "C"`
   functions;
5. repeat the upload for the second library when the exercise uses both;
6. load and compile the assembly file; and
7. flash it through the gateway at <http://localhost:8080>.

Assembly passes arguments to a bridge function in `a0` through `a7` and
receives its return value in `a0`, following the RISC-V calling convention.
Uploaded libraries are accepted only when Arduino Support/CREATino mode is
enabled.

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

## Relation to the separate thesis repository

- [Chapter 6 in TFM-RISCV](https://github.com/vGerJ02/TFM-RISCV/blob/main/chapters/6-proposal-for-integration-in-computer-structure-and-architecture-courses.tex)
  describes the course integration, CREATOR Gateway setup, CREATino, and the
  external Arduino-library extension implemented in the two submodules.
- [Chapter 7 in TFM-RISCV](https://github.com/vGerJ02/TFM-RISCV/blob/main/chapters/7-proposed-risc-v-practical-activities.tex)
  gives the exercise statements, expected results, hardware diagrams, and
  teaching sequence represented by the files in this repository.

For the complete wiring diagrams and learning objectives, consult those
chapters alongside this README.
