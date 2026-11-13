# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.0.0] - 2026-11-13

### Added
- Add Field Guide's Starfinder sample to the demo library
- Show the free web supplements with their parent books' covers
- Describe the shared download folder on the iPad
- Put iPad downloads in the Tableside App Group
- Make the demo maps Flip-Mat size and illustrate the sample
- Add the privacy policy and link it from Help and About
- Drop the Downloads entitlement from the App Store build
- Build Scrollkeeper for the Mac App Store without its updater
- Offer the demo library on the sign-in screen
- Serve real PDFs in the demo library
- Name the download folder in Settings
- Share the library list and covers with the toolkit apps
- Run Scrollkeeper in the App Sandbox
- Let Field Guide ask Scrollkeeper for titles
- Offer Paizo's free deity supplements in every library

### Fixed
- Make the iPad UI tests hold up on a slow simulator
- Download a file saved elsewhere in the temporary folder
- Open Device Hub after starting the iPad simulator
- Say what went wrong when Paizo's site changed or is unreachable
- Scroll to the demo title in the iPad UI tests
- Forget the library when the account is removed
- Open Pluck by its capitalized bundle ID
- Put the packages' resources in the app

### Changed
- Move the iPad downloads to the App Group in the specs
- Allow Community Use art and ORC rules text in the demo files
- Say what deleting the app leaves on a Mac
- Bump SonarSource/sonarqube-scan-action
- Redraw the demo pawns
- Specify the demo library on the sign-in screen
- Add the demo library's PDFs
- Specify the demo library's PDFs and sharing
- Name the download folder in Settings
- Use tabletop-kit 0.16.0
- Use TablesideShared for the App Group and library list
- Specify the sandboxed app and its shared download folder
- Welcome signed commits without requiring them
- Add a contributing guide
- Bump SonarSource/sonarqube-scan-action

[2.0.0]: https://github.com/scooper4711/scrollkeeper/releases/tag/v2.0.0

## [1.5.0] - 2026-10-20

### Added
- Name the app's version and project in its user agent
- Run the iPad app on the iPhone too

### Fixed
- Name the iPhone in the downloads settings

[1.5.0]: https://github.com/scooper4711/scrollkeeper/releases/tag/v1.5.0

## [1.4.1] - 2026-10-20

[1.4.1]: https://github.com/scooper4711/scrollkeeper/releases/tag/v1.4.1

## [1.4.0] - 2026-10-20

### Added
- Keep the chosen download folder as a bookmark
- Send Mapsmith status links and list only its maps
- Tell requesting apps how their download is going
- Hand requesting apps a list of titles they can open

### Fixed
- Open Mapsmith by its new bundle ID
- Answer requests in the app delegate, not the window
- Open no extra window for a request that launches the app

### Changed
- Make the stop-at-the-first-failure check deterministic
- Plan the shared App Group download folder
- Group Dependabot security updates
- Give Mapsmith status links and a maps-only index
- Specify title index requests and status links

[1.4.0]: https://github.com/scooper4711/scrollkeeper/releases/tag/v1.4.0

## [1.3.0] - 2026-10-18

### Added
- Preview the selected title with Space
- Show how far a refresh has got

### Fixed
- Open the book before its maps and posters
- Put Paizo Printables in a category of their own
- Bundle the universal binary from where SwiftPM built it

### Changed
- Specify Space to preview a title
- Specify Printables, refresh progress and book-first open
- Allow trial release builds run by hand
- Remove the empty 1.2.1 changelog entry

[1.3.0]: https://github.com/scooper4711/scrollkeeper/releases/tag/v1.3.0

## [1.2.0] - 2026-10-15

### Added
- Send only the PDFs of map packs that also hold images
- Tell other apps which maps are downloaded
- Open titles in other apps from scrollkeeper links
- Resolve open requests from other apps
- Write an index of owned maps for other apps

### Fixed
- Find the test bundle under newer SwiftPM layouts
- Enable file sharing in the iPad app's Info.plist
- Stop the iPad install when its build fails

### Changed
- Match the handoff design to the code
- Describe opening maps from Mapsmith
- Add app handoff spec
- Say the toolkit is Mac apps, two also on the iPad
- Rename the suite the Tableside Toolkit
- List every Society Toolkit app
- Remove the statement about the use of AI
- Open the README with the problem Scrollkeeper solves
- Add the Society Toolkit section to the README

[1.2.0]: https://github.com/scooper4711/scrollkeeper/releases/tag/v1.2.0

## [1.1.0] - 2026-10-03

### Added
- Check a title's downloads when it is opened
- Check downloaded files for updates within an allowance
- Add the policy and lookup for update checks
- Download and open titles from the grid and list

### Fixed
- Make the downloads button work while downloading on iPad
- Resume downloads that were cut off
- Open the downloads list while downloads are running
- Keep the download buttons readable in a narrow details pane

### Changed
- Specify checks for updated files
- Updating screenshot
- Remove merge commits from the 1.0.0 changelog

[1.1.0]: https://github.com/scooper4711/scrollkeeper/releases/tag/v1.1.0

## [1.0.0] - 2026-10-02

### Added
- Check for updates when the app opens
- Check for updates and offer to download the new version
- Flag downloads that Paizo has updated since the user last downloaded
- Show the release date in a title's details

### Changed
- Various documentation updates
- Add SonarCloud analysis, Dependabot updates and README badges

[1.0.0]: https://github.com/scooper4711/scrollkeeper/releases/tag/v1.0.0

## [0.1.0] - 2026-10-02

### Added
- Initial release

[0.1.0]: https://github.com/scooper4711/scrollkeeper/releases/tag/v0.1.0
