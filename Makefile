DERIVED_DATA := build/DerivedData
APP := $(DERIVED_DATA)/Build/Products/Release/ImpactCapture.app
INSTALL_DIR := $(HOME)/Applications
XCODEBUILD := xcodebuild -project ImpactCapture.xcodeproj -scheme ImpactCapture -derivedDataPath $(DERIVED_DATA) -quiet

.PHONY: project build test install uninstall clean icon snapshots release brew-release

project:
	xcodegen generate --quiet

build: project
	$(XCODEBUILD) -configuration Release build

test: project
	$(XCODEBUILD) -configuration Debug test

install: build
	-pkill -x ImpactCapture
	mkdir -p "$(INSTALL_DIR)"
	rm -rf "$(INSTALL_DIR)/ImpactCapture.app"
	cp -R "$(APP)" "$(INSTALL_DIR)/"
	open "$(INSTALL_DIR)/ImpactCapture.app"

uninstall:
	-pkill -x ImpactCapture
	rm -rf "$(INSTALL_DIR)/ImpactCapture.app"

clean:
	rm -rf build ImpactCapture.xcodeproj

icon:
	swift scripts/generate-icon.swift

# Renders every screen (light and dark) with sample data to build/snapshots for design review.
snapshots: project
	$(XCODEBUILD) -configuration Debug build
	$(DERIVED_DATA)/Build/Products/Debug/ImpactCapture.app/Contents/MacOS/ImpactCapture -snapshot build/snapshots
	$(DERIVED_DATA)/Build/Products/Debug/ImpactCapture.app/Contents/MacOS/ImpactCapture -snapshot build/snapshots -dark

release:
	scripts/release.sh

# GitHub release + Homebrew cask update in frugoman/homebrew-tap.
brew-release:
	scripts/brew-release.sh
