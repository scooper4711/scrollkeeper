# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
