.PHONY: build test lint coverage app run install dmg icon ipad-simulator ipad-install ipad-uitest clean

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

clean:
	rm -rf .build build ios/build
