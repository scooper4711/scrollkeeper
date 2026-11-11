#!/bin/sh
# Rewrites the demo library's PDFs in Sources/ScrollkeeperKit/Demo/Files, which are committed.
#
# Needs checkouts beside this one:
#   ../tabletop-kit           its DemoLibraryTool writes the pawn, token, card, map and book PDFs
#   ../community-use-artwork  Paizo's Community Use Package: the Iconics and symbols in them
#   ../field-guide            Resources/Review/Field Guide Sample Monster Core.pdf and Field Guide Sample Alien Core.pdf,
#                             Field Guide's sample sourcebooks
#
# TABLETOP_KIT, COMMUNITY_USE_ARTWORK, FIELD_GUIDE  other places for those checkouts
set -eu

cd "$(dirname "$0")/.."
TABLETOP_KIT="${TABLETOP_KIT:-../tabletop-kit}"
ART="${COMMUNITY_USE_ARTWORK:-../community-use-artwork}"
FIELD_GUIDE="${FIELD_GUIDE:-../field-guide}"
OUTPUT="Sources/ScrollkeeperKit/Demo/Files"
SAMPLE="$FIELD_GUIDE/Resources/Review/Field Guide Sample Monster Core.pdf"
ALIEN_SAMPLE="$FIELD_GUIDE/Resources/Review/Field Guide Sample Alien Core.pdf"

for needed in "$TABLETOP_KIT/Package.swift" "$ART/Community Use Package- Iconics" "$SAMPLE" "$ALIEN_SAMPLE"; do
    [ -e "$needed" ] || { echo "Making the demo PDFs failed: $needed is missing." >&2; exit 1; }
done

swift run -c release --package-path "$TABLETOP_KIT" DemoLibraryTool "$OUTPUT" --art "$ART"
cp "$SAMPLE" "$OUTPUT/sample-monster-core.pdf"
cp "$ALIEN_SAMPLE" "$OUTPUT/sample-alien-core.pdf"
echo "Wrote the demo PDFs to $OUTPUT"
