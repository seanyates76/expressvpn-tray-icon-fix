PROJECT_DIR := $(abspath .)
BUILD_DIR := $(PROJECT_DIR)/build

QT_CFLAGS := $(shell pkg-config --cflags Qt6Core Qt6Gui Qt6Qml)
EXPRESSVPN_QT_LIBDIR := /opt/expressvpn/lib
QT_PKG_LIBS := $(shell pkg-config --libs Qt6Core Qt6Gui Qt6Qml)

ifneq ($(wildcard $(EXPRESSVPN_QT_LIBDIR)),)
QT_LIBS := -L$(EXPRESSVPN_QT_LIBDIR) -Wl,-rpath,$(EXPRESSVPN_QT_LIBDIR) -lQt6Qml -lQt6Gui -lQt6Core -ldl
else
QT_LIBS := $(QT_PKG_LIBS) -ldl
endif

CXXFLAGS := -std=c++20 -fPIC -O2 -Wall -Wextra -Wpedantic -DQT_NO_VERSION_TAGGING $(QT_CFLAGS)
LDFLAGS := $(QT_LIBS)

PRELOAD := $(BUILD_DIR)/libexpressvpn-tray-dump.so
OVERRIDE_PRELOAD := $(BUILD_DIR)/libexpressvpn-tray-override.so
STYLE ?= colored
PREFIX ?= $(HOME)/.local
PACKAGE_RUNTIME_DIR ?= $(BUILD_DIR)/package-runtime/expressvpn-tray-icon-fix
ARCH_PKG_DIR ?= $(PROJECT_DIR)/packaging/arch

.PHONY: all clean extract override-preload install uninstall stage-package-runtime package-arch package-arch-install srcinfo

all: $(PRELOAD) $(OVERRIDE_PRELOAD)

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

$(PRELOAD): tools/src/dump_preload.cpp | $(BUILD_DIR)
	g++ $(CXXFLAGS) -shared -o $@ $< $(LDFLAGS)

$(OVERRIDE_PRELOAD): tools/src/resource_override.cpp | $(BUILD_DIR)
	g++ $(CXXFLAGS) -shared -o $@ $< $(LDFLAGS)

extract: $(PRELOAD)
	./scripts/extract-tray-resources.sh

override-preload: $(OVERRIDE_PRELOAD)

install: $(OVERRIDE_PRELOAD)
	./scripts/install-local.sh "$(STYLE)" "$(PREFIX)"

stage-package-runtime: $(OVERRIDE_PRELOAD)
	./scripts/stage-package-runtime.sh "$(PACKAGE_RUNTIME_DIR)"

package-arch:
	cd "$(ARCH_PKG_DIR)" && makepkg -f --nodeps

package-arch-install:
	cd "$(ARCH_PKG_DIR)" && makepkg -fsi

srcinfo:
	cd "$(ARCH_PKG_DIR)" && makepkg --printsrcinfo > .SRCINFO

uninstall:
	./scripts/uninstall-local.sh "$(PREFIX)"

clean:
	rm -rf $(BUILD_DIR)
