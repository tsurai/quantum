ARCH ?= x86_64

ifeq ($(ARCH),x86_64)
	TRIPLE ?= x86_64-elf
else
	$(error Unsupported architecture $(ARCH))
endif

RUSTC ?= rustc
LD := $(TRIPLE)-ld
AS := $(TRIPLE)-as
OBJDUMP := $(TRIPLE)-objdump
OBJCOPY := $(TRIPLE)-objcopy

BUILD := build/$(ARCH)/
LINKSCRIPT := src/arch/$(ARCH)/link.ld
TARGETSPEC := src/arch/$(ARCH)/target.json

# compiler options
LINKFLAGS := -T $(LINKSCRIPT)
LINKFLAGS += -Map $(BUILD)map.txt
LINKFLAGS += --gc-sections
LINKFLAGS += -z max-page-size=0x1000

RUSTFLAGS := -g -O --target=$(TARGETSPEC) --out-dir $(BUILD) -Z no-landing-pads

# objects
LIBCORE := $(BUILD)libcore.rlib
SOURCES := $(shell find src -type f -name '*.rs')
OBJS := boot.o kernel.o libcore.rlib
OBJS := $(OBJS:%=$(BUILD)%)
GRUBCFG := src/arch/$(ARCH)/grub.cfg
ISO := quantum.iso
BIN := kernel.$(ARCH).bin

.PHONY: all clean

all: kernel.$(ARCH).bin

clean:
	$(RM) -rf $(BIN) $(BIN).dsm $(BIN).sym $(BUILD) $(ISO)

run: $(ISO)
	@qemu-system-$(ARCH) -serial stdio -cdrom $(ISO)

iso: $(ISO)

$(ISO): $(BIN) $(GRUBCFG)
	@mkdir -p $(BUILD)iso/boot/grub
	@cp $(BIN) $(BUILD)iso/boot/kernel.bin
	@cp $(GRUBCFG) $(BUILD)iso/boot/grub
	grub-mkrescue -o $(ISO) $(BUILD)iso 2> /dev/null
	@rm -r $(BUILD)iso

$(BIN): $(OBJS) src/arch/$(ARCH)/link.ld
	$(LD) -o $@ $(LINKFLAGS) $(OBJS)
	$(OBJDUMP) -S $@ > $@.dsm
	$(OBJCOPY) --only-keep-debug $@ $@.sym

$(BUILD)libcore.rlib: lib/rust/src/libcore/lib.rs $(TARGETSPEC)
	$(RUSTC) $(RUSTFLAGS) lib/rust/src/libcore/lib.rs

$(BUILD)kernel.o: src/main.rs $(SOURCES) $(LIBCORE) Makefile $(TARGETSPEC)
	@mkdir -p $(dir $@)
	$(RUSTC) $(RUSTFLAGS) --emit=obj,dep-info $< --extern core=$(LIBCORE)

$(BUILD)boot.o: src/arch/$(ARCH)/boot.S Makefile
	@mkdir -p $(dir $@)
	$(AS) $(ASFLAGS) -o $@ $<
