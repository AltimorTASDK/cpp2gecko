ifndef DEVKITPRO
$(error Specify devkitPro install path with $$DEVKITPRO)
endif
ifndef MAPFILE
$(error Specify game's Dolphin .map file with $$MAPFILE)
endif
ifndef SRCDIR
$(error Specify input source directories with $$SRCDIR)
endif
ifndef BUILDDIR
$(error Specify build artifact directory with $$BUILDDIR)
endif

DEVKITPATH=$(shell echo "$(DEVKITPRO)" | sed -e 's/^\([a-zA-Z]\):/\/\1/')
PATH := $(DEVKITPATH)/devkitPPC/bin:$(PATH)

CC      := powerpc-eabi-gcc
CXX     := powerpc-eabi-g++
OBJCOPY := powerpc-eabi-objcopy
OBJDUMP := powerpc-eabi-objdump

ROOT   := $(patsubst %/, %, $(strip $(dir $(lastword $(MAKEFILE_LIST)))))
TOOLS  := $(ROOT)/tools
ASMDIR := $(BUILDDIR)/asm
BINDIR := $(BUILDDIR)/bin
OBJDIR := $(BUILDDIR)/obj
DEPDIR := $(BUILDDIR)/dep

GAMELD  := $(BUILDDIR)/game.ld
GAMEH   := $(BUILDDIR)/game.h
GECKOLD := $(ROOT)/gecko.ld
LDFLAGS := -Wl,--gc-sections -nostdlib -T$(GECKOLD) -T$(GAMELD)

PPFLAGS := -I"$(DEVKITPATH)/libogc/include" \
           -DGEKKO -DGECKO $(EXTRA_PPFLAGS)

# Access all globals through PIC register
CFLAGS := -msdata=eabi -G 4096 \
          -mogc -mcpu=750 -meabi -Os -g \
          -Wall -Wno-switch -Wno-unused-value -Wconversion -Warith-conversion -Wno-multichar \
          -Wno-pointer-arith -Wno-volatile-register-var -Wno-unused-variable \
          -ffunction-sections -fdata-sections \
          -fno-builtin-sqrt -fno-builtin-sqrtf -fno-builtin-memcpy \
          -include $(ROOT)/src/defines.h \
          $(PPFLAGS) $(EXTRA_CFLAGS)


CXXFLAGS := $(CFLAGS) -std=c++2b -fno-rtti -fno-exceptions $(EXTRA_CXXFLAGS)
ASFLAGS  := $(PPFLAGS) -Wa,-mregnames -Wa,-mgekko -include $(GAMEH) $(EXTRA_ASFLAGS)

SRCFILES := $(foreach dir, $(SRCDIR), $(shell find $(dir) -type f -name '*.c'   2> /dev/null)) \
            $(foreach dir, $(SRCDIR), $(shell find $(dir) -type f -name '*.cpp' 2> /dev/null)) \
            $(foreach dir, $(SRCDIR), $(shell find $(dir) -type f -name '*.S'   2> /dev/null))

OBJFILES := $(patsubst %, $(OBJDIR)/%.o, $(SRCFILES))
ASMFILES := $(patsubst %, $(ASMDIR)/%.s, $(filter-out %.S, $(SRCFILES)))
DEPFILES := $(patsubst %, $(DEPDIR)/%.d, $(filter-out %.S, $(SRCFILES)))

ASMFIXED := $(ASMFILES:.s=.out.s)

ELFFILE  := $(BINDIR)/gecko.elf
BINFILE  := $(BINDIR)/gecko.bin
NOTEFILE := $(BINDIR)/notes.bin
INIFILE  := $(BINDIR)/gecko.ini
DUMPS    := $(patsubst %, %.asm, $(ELFFILE) $(OBJFILES))

.PHONY: gecko
gecko: $(INIFILE) $(DUMPS) | clean-unused

%.asm: %
	@$(OBJDUMP) -dr --source-comment="/// " $< > $@

$(INIFILE): $(BINFILE) $(NOTEFILE)
#   Convert to 2 columns of hex words
#   Remove unnecessary b __end if present
#   Set C2 code type and make last word null
	@data=$$(od --endian=big -v -An -w4 -t u4 $< | \
	         xargs printf '%08X' | \
	         sed -r 's/4800000460000000(00000000)?$$/60000000\1/' | \
	         sed -r 's/(.{8})(.{8})/\1 \2\n/g'); \
	 printf "%s" "C2$${data:2:-8}00000000" > $@

$(BINFILE): $(ELFFILE)
	$(OBJCOPY) -O binary -R .note.* $< $@

$(NOTEFILE): $(ELFFILE)
	$(OBJCOPY) -O binary -j .note.gecko $< $@

$(ELFFILE): $(OBJFILES) $(ASMFIXED) $(ASMFILES) $(GECKOLD) $(GAMELD)
	@[ -d $(@D) ] || mkdir -p $(@D)
	$(CC) $(LDFLAGS) $(OBJFILES) -o $@

$(OBJDIR)/%.o: $(ASMDIR)/%.out.s
	@[ -d $(@D) ] || mkdir -p $(@D)
	$(CC) $(ASFLAGS) -c $< -o $@

$(OBJDIR)/%.S.o: %.S $(GAMEH)
	@[ -d $(@D) ] || mkdir -p $(@D)
	$(CC) $(ASFLAGS) -c $< -o $@

$(ASMDIR)/%.out.s: $(ASMDIR)/%.s $(TOOLS)/process_asm.py $(GAMELD)
	python $(TOOLS)/process_asm.py $< $@ $(GAMELD)

$(ASMDIR)/%.c.s: %.c
	@[ -d $(@D) ] || mkdir -p $(@D)
	@[ -d $(subst $(OBJDIR), $(DEPDIR), $(@D)) ] || mkdir -p $(subst $(OBJDIR), $(DEPDIR), $(@D))
	$(CC) -MMD -MP -MF $(patsubst $(ASMDIR)/%.s, $(DEPDIR)/%.d, $@) $(CFLAGS) -c $< -S -fverbose-asm -o $@

$(ASMDIR)/%.cpp.s: %.cpp
	@[ -d $(@D) ] || mkdir -p $(@D)
	@[ -d $(subst $(ASMDIR), $(DEPDIR), $(@D)) ] || mkdir -p $(subst $(ASMDIR), $(DEPDIR), $(@D))
	$(CXX) -MMD -MP -MF $(patsubst $(ASMDIR)/%.s, $(DEPDIR)/%.d, $@) $(CXXFLAGS) -c $< -S -fverbose-asm -o $@

$(GAMELD): $(MAPFILE) $(TOOLS)/map_to_linker_script.py
	@[ -d $(@D) ] || mkdir -p $(@D)
	python $(TOOLS)/map_to_linker_script.py $< $@

$(GAMEH): $(MAPFILE) $(TOOLS)/map_to_asm_header.py
	@[ -d $(@D) ] || mkdir -p $(@D)
	python $(TOOLS)/map_to_asm_header.py $< $@

.PHONY: clean
clean:
	rm -rf $(BUILDDIR)

# Remove unused build artifacts
USED := $(ASMFILES) $(ASMFIXED) $(OBJFILES) $(DEPFILES) \
        $(GAMELD) $(GAMEH) \
        $(ELFFILE) $(BINFILE) $(NOTEFILE) $(INIFILE) $(DUMPS)

ARTIFACTS := $(shell find $(BUILDDIR) -type f 2> /dev/null)
UNUSED    := $(filter-out $(USED), $(ARTIFACTS))

.PHONY: clean-unused
clean-unused:
ifneq ($(UNUSED),)
	rm $(UNUSED)
endif

-include $(DEPFILES)