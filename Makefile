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
BINDIR := $(BUILDDIR)/bin
OBJDIR := $(BUILDDIR)/obj
DEPDIR := $(BUILDDIR)/dep

GAMELD  := $(BUILDDIR)/game.ld
GECKOLD := $(ROOT)/gecko.ld
LDFLAGS := -Wl,--gc-sections -nostdlib -T$(GECKOLD) -T$(GAMELD)

DEFINES := $(foreach def, $(USERDEFS), -D$(def))
DEFINES += -DGEKKO -DGECKO

# Access all globals through r31
CFLAGS   := -g -ffixed-r31 -msdata=eabi -G 4096 \
			$(DEFINES) -mogc -mcpu=750 -meabi -Os \
            -Wall -Wno-switch -Wno-unused-value -Wconversion -Warith-conversion -Wno-multichar \
            -Wno-pointer-arith \
            -ffunction-sections -fdata-sections \
            -fno-builtin-sqrt -fno-builtin-sqrtf \
			$(foreach dir, $(INCLUDE), -I$(dir)) \
			-I"$(DEVKITPATH)/libogc/include" \
			-include $(ROOT)/src/defines.h
ASFLAGS  := $(DEFINES) -Wa,-mregnames -Wa,-mgekko
CXXFLAGS := $(CFLAGS) -std=c++2b -fconcepts -fno-rtti -fno-exceptions

SRCFILES := $(foreach dir, $(SRCDIR), $(shell find $(dir) -type f -name '*.c'   2> /dev/null)) \
            $(foreach dir, $(SRCDIR), $(shell find $(dir) -type f -name '*.cpp' 2> /dev/null)) \
            $(foreach dir, $(SRCDIR), $(shell find $(dir) -type f -name '*.S'   2> /dev/null))

OBJFILES := $(patsubst %, $(OBJDIR)/%.o, $(SRCFILES))
DEPFILES := $(patsubst %, $(DEPDIR)/%.d, $(filter-out %.S, $(SRCFILES)))

# Initializes r31 to .sdata address
OBJFILES += $(OBJDIR)/pic_init.S.o

# Use an intermediate relocatable file to apply fixups
RELFILE  := $(OBJDIR)/gecko.o
RELFIXED := $(OBJDIR)/gecko-fixed.o
ELFFILE  := $(BINDIR)/gecko.elf

DUMPS   := $(patsubst %, %.asm, $(OBJFILES) $(RELFILE) $(RELFIXED) $(ELFFILE))

TARGETS := $(ELFFILE)
ifdef ASMDUMP
TARGETS += $(DUMPS)
endif

.PHONY: gecko
gecko: $(TARGETS) | clean-unused

%.asm: %
	@$(OBJDUMP) -dr --source-comment="# " $< > $@

$(ELFFILE): $(RELFIXED) $(GECKOLD) $(GAMELD)
	@[ -d $(@D) ] || mkdir -p $(@D)
	$(CC) $(LDFLAGS) $< -o $@

$(RELFIXED): $(RELFILE) $(GAMELD)
	python $(TOOLS)/fix_relocations.py $< $@

$(RELFILE): $(OBJFILES) $(GECKOLD) $(GAMELD)
	@[ -d $(@D) ] || mkdir -p $(@D)
	$(CC) $(LDFLAGS) $(OBJFILES) -r -o $@

# PIC initialization
$(OBJDIR)/pic_init.S.o: $(ROOT)/src/pic_init.S
	@[ -d $(@D) ] || mkdir -p $(@D)
	$(CC) $(ASFLAGS) -c $< -o $@

$(OBJDIR)/%.c.o: %.c
	@[ -d $(@D) ] || mkdir -p $(@D)
	@[ -d $(subst $(OBJDIR), $(DEPDIR), $(@D)) ] || mkdir -p $(subst $(OBJDIR), $(DEPDIR), $(@D))
	$(CC) -MMD -MP -MF $(patsubst $(OBJDIR)/%.o, $(DEPDIR)/%.d, $@) $(CFLAGS) -c $< -o $@

$(OBJDIR)/%.cpp.o: %.cpp
	@[ -d $(@D) ] || mkdir -p $(@D)
	@[ -d $(subst $(OBJDIR), $(DEPDIR), $(@D)) ] || mkdir -p $(subst $(OBJDIR), $(DEPDIR), $(@D))
	$(CXX) -MMD -MP -MF $(patsubst $(OBJDIR)/%.o, $(DEPDIR)/%.d, $@) $(CXXFLAGS) -c $< -o $@

$(OBJDIR)/%.S.o: %.S
	@[ -d $(@D) ] || mkdir -p $(@D)
	$(CC) $(ASFLAGS) -c $< -o $@

$(GAMELD): $(MAPFILE) $(TOOLS)/map_to_linker_script.py
	python $(TOOLS)/map_to_linker_script.py $< $@

.PHONY: clean
clean:
	rm -rf $(BUILDDIR)

# Remove unused build artifacts
.PHONY: clean-unused
clean-unused:
	$(foreach file, $(shell find $(BUILDDIR) -type f 2> /dev/null), \
		$(if $(filter $(file), \
			$(OBJFILES) $(DEPFILES) $(DUMPS) $(RELFILE) $(RELFIXED) $(ELFFILE) $(GAMELD) \
		),, rm $(file);))

-include $(DEPFILES)