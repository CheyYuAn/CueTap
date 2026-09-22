#!/bin/zsh
# Build, publish a GitHub release, and point the Homebrew tap at it.
#
#   scripts/release.sh 0.4.1 [NOTES.md]
#
# Needs gh logged in, a clean main, and the tap repository checked out next to
# this one (override with CUETAP_TAP_DIR). NOTES.md becomes the release notes;
# without it the notes point at the README.

set -e

VERSION="$1"
NOTES="$2"
[[ -n "$VERSION" ]] || { echo "usage: $0 VERSION [NOTES.md]" >&2; exit 2; }
[[ -z "$NOTES" || -f "$NOTES" ]] || { echo "notes file not found: $NOTES" >&2; exit 2; }

ROOT="${0:A:h:h}"
TAP_DIR="${CUETAP_TAP_DIR:-$ROOT/../homebrew-cuetap}"
REPO="CheyYuAn/CueTap"
ARCHIVE="cuetap-$VERSION-macos.tar.gz"

cd "$ROOT"

[[ -z "$(git status --porcelain)" ]] || { echo "working tree is dirty" >&2; exit 1; }
[[ "$(git rev-parse --abbrev-ref HEAD)" == "main" ]] || { echo "not on main" >&2; exit 1; }
[[ -d "$TAP_DIR/Formula" ]] || { echo "tap not found at $TAP_DIR" >&2; exit 1; }
if git rev-parse "v$VERSION" >/dev/null 2>&1; then echo "tag v$VERSION already exists" >&2; exit 1; fi

echo "==> Building"
"$ROOT/build/products/Release/cuetap" quit >/dev/null 2>&1 || true
"$ROOT/Skills/cuetap/scripts/build-local.sh" "$ROOT" >/dev/null

BUILT=$("$ROOT/build/products/Release/cuetap" version --json | /usr/bin/python3 -c 'import sys,json; print(json.load(sys.stdin)["version"])')
[[ "$BUILT" == "$VERSION" ]] || { echo "the binary reports $BUILT, expected $VERSION; bump MARKETING_VERSION first" >&2; exit 1; }

echo "==> Packaging $ARCHIVE"
rm -f "$ROOT/$ARCHIVE"
tar -czf "$ROOT/$ARCHIVE" -C "$ROOT/build/products/Release" cuetap html-demo.json
SHA=$(shasum -a 256 "$ROOT/$ARCHIVE" | cut -d' ' -f1)
echo "    sha256 $SHA"

echo "==> Publishing release v$VERSION"
git push origin main
if [[ -n "$NOTES" ]]; then
  gh release create "v$VERSION" --repo "$REPO" --title "CueTap $VERSION" --notes-file "$NOTES" "$ROOT/$ARCHIVE"
else
  gh release create "v$VERSION" --repo "$REPO" --title "CueTap $VERSION" \
    --notes "See the README for what CueTap does and how to install it." "$ROOT/$ARCHIVE"
fi

echo "==> Updating the tap"
FORMULA="$TAP_DIR/Formula/cuetap.rb"
/usr/bin/sed -i '' \
  -e "s|^  url .*|  url \"https://github.com/$REPO/releases/download/v$VERSION/$ARCHIVE\"|" \
  -e "s|^  sha256 .*|  sha256 \"$SHA\"|" \
  "$FORMULA"
grep -q "$SHA" "$FORMULA" || { echo "the formula was not updated; check $FORMULA" >&2; exit 1; }
git -C "$TAP_DIR" add Formula/cuetap.rb
git -C "$TAP_DIR" commit -q -m "Update cuetap to $VERSION"
git -C "$TAP_DIR" push -q origin main

echo "==> Done. brew upgrade cuetap now gets $VERSION."
