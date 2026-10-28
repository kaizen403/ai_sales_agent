CROSS ?= arm-none-eabi-
CC := $(CROSS)gcc
OBJCOPY := $(CROSS)objcopy
SIZE := $(CROSS)size

BUILD := build
TARGET := $(BUILD)/sample_mcu

CFLAGS := -mcpu=cortex-m4 -mthumb -Os -ffunction-sections -fdata-sections \
	-Wall -Wextra -nostdlib -ffreestanding
LDFLAGS := -T linker.ld -Wl,--gc-sections -nostdlib

SRCS := src/startup.c src/main.c
OBJS := $(SRCS:%.c=$(BUILD)/%.o)

.PHONY: all clean

all: $(TARGET).elf $(TARGET).bin
	$(SIZE) $(TARGET).elf

$(BUILD)/%.o: %.c
	@mkdir -p $(dir $@)
	$(CC) $(CFLAGS) -c $< -o $@

$(TARGET).elf: $(OBJS) linker.ld
	@mkdir -p $(dir $@)
	$(CC) $(CFLAGS) $(OBJS) $(LDFLAGS) -o $@

$(TARGET).bin: $(TARGET).elf
	$(OBJCOPY) -O binary $< $@

clean:
	rm -rf $(BUILD)
