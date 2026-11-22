.PHONY: build test lint coverage app run install dmg appstore icon demo-pdfs ipad-simulator ipad-install ipad-uitest clean

build:
	swift build

test:
	swift test

lint:
	swiftlint --strict --quiet

coverage:
	scripts/coverage.sh

app:
	scripts/build-app.sh

run: app
	open "build/Scrollkeeper.app"

# Copies the built app into /Applications, replacing an earlier copy.
install: app
	rm -rf "/Applications/Scrollkeeper.app"
	ditto "build/Scrollkeeper.app" "/Applications/Scrollkeeper.app"

dmg: app
	scripts/make-dmg.sh

# Builds the Mac App Store package, build/appstore/Scrollkeeper.pkg (see scripts/build-app.sh for the variables).
appstore:
	CHANNEL=appstore scripts/build-app.sh

# Rewrites the demo library's PDFs from tabletop-kit's DemoLibraryTool (checkouts beside this one).
demo-pdfs:
	scripts/make-demo-pdfs.sh

# Redraws Resources/AppIcon.icns from scripts/make-icon.swift.
icon:
	swift scripts/make-icon.swift

# Builds the iPad app and starts it in a simulator. IPAD_SIMULATOR names the simulator.
ipad-simulator:
	scripts/run-ipad-simulator.sh

# Builds the iPad app and installs it on a connected iPad. IPAD names the iPad.
ipad-install:
	scripts/install-ipad.sh

# Runs the iPad UI tests in a simulator, against the app's built-in demo library.
ipad-uitest:
	scripts/run-ipad-uitests.sh

# Archives the app for the App Store and exports build/ipad/export/*.ipa, versioned from git. Upload it with
# `make testflight`.
.PHONY: ipad-archive testflight
ipad-archive:
	.build/checkouts/tabletop-kit/scripts/archive-ios.sh ios/Scrollkeeper.xcodeproj Scrollkeeper-iPad build/ipad

# Uploads the newest build (the .ipa from ipad-archive or the .pkg from appstore) to TestFlight, with this release's
# notes from the tableside-store checkout next to this repository (TABLESIDE_STORE).
TABLESIDE_STORE ?= ../tableside-store
TESTFLIGHT_NOTES = $(TABLESIDE_STORE)/scrollkeeper/testflight/what-to-test.txt
TESTFLIGHT_BUILD ?= $(shell ls -t build/ipad/export/*.ipa build/appstore/*.pkg 2>/dev/null | head -n 1)
testflight:
	@test -f "$(TESTFLIGHT_NOTES)" || { echo "testflight failed: $(TESTFLIGHT_NOTES) not found; set TABLESIDE_STORE"; exit 1; }
	@test -n "$(TESTFLIGHT_BUILD)" || { echo "testflight failed: no build; run make ipad-archive or make appstore"; exit 1; }
	.build/checkouts/tabletop-kit/scripts/testflight.sh io.github.scooper4711.Scrollkeeper "$(TESTFLIGHT_BUILD)" "$(TESTFLIGHT_NOTES)"

clean:
	rm -rf .build build ios/build
