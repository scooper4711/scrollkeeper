.PHONY: build test lint coverage app run install dmg icon ipad-simulator clean

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
	open "build/Paizo Library Manager.app"

# Copies the built app into /Applications, replacing an earlier copy.
install: app
	rm -rf "/Applications/Paizo Library Manager.app"
	ditto "build/Paizo Library Manager.app" "/Applications/Paizo Library Manager.app"

dmg: app
	scripts/make-dmg.sh

# Redraws Resources/AppIcon.icns from scripts/make-icon.swift.
icon:
	swift scripts/make-icon.swift

# Builds the iPad app and starts it in a simulator. IPAD_SIMULATOR names the simulator.
ipad-simulator:
	scripts/run-ipad-simulator.sh

clean:
	rm -rf .build build ios/build
