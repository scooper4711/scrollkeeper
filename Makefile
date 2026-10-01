.PHONY: build test lint coverage app run dmg icon clean

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

dmg: app
	scripts/make-dmg.sh

# Redraws Resources/AppIcon.icns from scripts/make-icon.swift.
icon:
	swift scripts/make-icon.swift

clean:
	rm -rf .build build
