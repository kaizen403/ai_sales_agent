# Renode MCU Sample (DI / AI / DO / UART / LEDs)

Sample Cortex-M4 microcontroller project for **Renode** simulation with **Robot Framework** tests.

It exercises:

| Feature | Count | Notes |
|---------|------:|-------|
| Digital inputs (DI) | 8 | Renode `Button` devices → `gpio_in` |
| Analog inputs (AI) | 8 | 12-bit MMIO channels (0–4095) |
| Digital outputs (DO) | 8 | Renode `LED` devices on `gpio_out` |
| Status LEDs | 4 | Mode / activity indicators |
| UART | 1 | NS16550 CLI for config + monitor |

## Layout

```
renode-mcu-sample/
├── README.md
├── firmware/           # Bare-metal Cortex-M4 app (arm-none-eabi-gcc)
├── renode/             # Platform (.repl), script (.resc), AI Python peripheral
├── tests/              # Robot Framework suite (renode-test)
└── scripts/            # install_deps.sh, run_tests.sh
```

## Prerequisites

- Linux x86_64 (primary). macOS/Windows: install Renode from [releases](https://github.com/renode/renode/releases) and Robot via `pip`; build firmware with an ARM embedded GCC.
- Tools: `renode`, `renode-test`, `robot`, `arm-none-eabi-gcc`

### Install on Debian/Ubuntu (non-interactive)

```bash
cd renode-mcu-sample
./scripts/install_deps.sh
export PATH="$HOME/.local/bin:/usr/local/bin:/opt/renode:$PATH"
```

Exact steps used by that script:

1. `apt-get install` — `wget`, `python3`, `python3-pip`, `python3-dev`, `gcc-arm-none-eabi`, `binutils-arm-none-eabi`, `libnewlib-arm-none-eabi`
2. Download Renode **1.15.2** portable tarball from GitHub releases into `/opt/renode` (`.deb` may fail on missing GTK deps; portable is preferred for CI)
3. Symlink `renode` / `renode-test` into `/usr/local/bin`
4. `pip install --user 'robotframework==6.1' 'robotframework-retryfailed==0.2.0' 'psutil==5.9.3' 'pyyaml==6.0.1'` (pins match Renode’s `tests/requirements.txt`)

### Other OS (brief)

- **macOS**: install Renode `.dmg`, alias `renode` / `renode-test`, `pip3 install robotframework==6.1 …`, install `arm-none-eabi-gcc` (e.g. Homebrew `gcc-arm-embedded`).
- **Windows**: install Renode `.msi`, use `renode-test.bat`, same pip pins, ARM GNU toolchain for Windows.

## Build firmware

```bash
make -C firmware
# → firmware/build/sample_mcu.elf
```

## Run Renode interactively

```bash
export PATH="$HOME/.local/bin:/usr/local/bin:/opt/renode:$PATH"
cd renode-mcu-sample
renode --disable-xwt
```

In the Monitor:

```text
path add @/absolute/path/to/renode-mcu-sample/renode
$bin=@/absolute/path/to/renode-mcu-sample/firmware/build/sample_mcu.elf
include @/absolute/path/to/renode-mcu-sample/renode/sample_mcu.resc
start
```

UART analyzer shows the `READY` banner. Example:

```text
sysbus.gpio_in.di0 Press
sysbus WriteDoubleWord 0x40003000 3000
# type into UART: MODE THRESHOLD / PROCESS / STATUS
```

## Run Robot tests

```bash
./scripts/run_tests.sh
# or:
renode-test -r tests/results tests/sample_mcu.robot
```

A prebuilt `firmware/build/sample_mcu.elf` is included so you can run tests after installing Renode + Robot without rebuilding (rebuild still recommended after firmware edits).

**Pass criteria:** all cases in `tests/sample_mcu.robot` succeed (boot/PING, DI→DO mirror, threshold gating, UART STATUS/GETDI/GETDO, GETAI).

Note: the Robot suite feeds UART commands with Monitor `uart0 WriteChar` (see `Uart Command` keyword) because that path is reliable with polled NS16550 in Renode 1.15.2; assertions still use the Terminal Tester on UART output.
## Pin / address map

| Signal | Renode device | Firmware access |
|--------|---------------|-----------------|
| DI0..DI7 | `gpio_in.di0`..`di7` (`Button`) | `GPIO_IDR` @ `0x40001008` bits 0..7 |
| DO0..DO7 | `gpio_out.do0`..`do7` (`LED`) | MiV OUT @ `0x400020A0` bits 0..7 |
| LED0..LED3 | `gpio_out.led0`..`led3` | MiV OUT bits 8..11 |
| AI0..AI7 | `ai` Python peripheral | words @ `0x40003000 + 4*n` (0..4095) |
| UART | `uart0` (NS16550) | base `0x40000000` |

GPIO out pins must be configured as outputs (`CFG=0x5` per pin); firmware does this at boot.

### Status LED meaning

| LED | Meaning |
|-----|---------|
| LED0 | Any DI high |
| LED1 | Any DO high |
| LED2 | Mode is `THRESHOLD` |
| LED3 | Heartbeat (toggles each process cycle) |

## Application logic

- **`MODE MIRROR`** (default): `DO[i] = DI[i]`
- **`MODE THRESHOLD`**: `DO[i] = DI[i] AND (AI[i] > threshold)` (default threshold `2048`)

Firmware continuously refreshes outputs and also updates on UART commands / `PROCESS`.

## UART protocol

Line-oriented ASCII (`\n`). Responses start with `OK` or `ERR`.

| Command | Effect |
|---------|--------|
| `HELP` | List commands |
| `PING` | `OK PONG` |
| `STATUS` | mode, threshold, last DI/DO |
| `MODE MIRROR` / `MODE THRESHOLD` | Select mapping mode |
| `THRESHOLD <n>` | Set threshold (0..4095) |
| `GETDI` / `GETDO` | Report last DI/DO as hex |
| `GETAI` | Report eight AI values |
| `PROCESS` | Force one I/O update cycle |

Boot banner: `READY SampleMCU DI/AI/DO/LED/UART`

## Platform notes

- CPU: Cortex-M4 + NVIC (custom `.repl`, not a full STM32 SoC — keeps the sample self-contained)
- DI uses Renode’s `STM32F1GPIOPort` IDR model (reliable button → input)
- DO/LEDs use `MiV_CoreGPIO` output register `0xA0`
- AI uses a small Python peripheral (`renode/ai_regs.py`) so Robot can `sysbus WriteDoubleWord` channel values without a full ADC model
