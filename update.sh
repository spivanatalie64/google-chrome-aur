#!/usr/bin/env bash
# update.sh — fetch and extract the current stable Google Chrome .deb.
#
# The PKGBUILD calls this script during package(): it downloads the latest
# stable Chrome .deb from Google's "current" direct URL, verifies it, and
# extracts its filesystem payload into the target directory.
#
# Usage:
#   ./update.sh check                print the latest stable pkgver (no download)
#   ./update.sh extract <pkgdir>     download the current .deb and extract it
#
# NOTE: this script is a source file of the PKGBUILD, so its sha512sum in
# PKGBUILD / .SRCINFO must be regenerated whenever this file changes:
#   sha512sum update.sh

set -euo pipefail

CHANNEL="${CHANNEL:-stable}"
DIRECT_URL="https://dl.google.com/linux/direct/google-chrome-${CHANNEL}_current_amd64.deb"
INDEX_URL="https://dl.google.com/linux/chrome/deb/dists/stable/main/binary-amd64/Packages"

case "${1:-extract}" in
	check)
		# Cheap: read the version from Google's package index so CI never has
		# to pull the ~140 MB .deb just to answer "is there an update?".
		curl -fsSL "$INDEX_URL" \
			| sed -n '/^Package: google-chrome-stable$/,/^$/p' \
			| sed -n 's/^Version: //p' \
			| cut -d- -f1
		;;

	extract)
		PKGDIR="${2:?usage: update.sh extract <pkgdir>}"
		mkdir -p "$PKGDIR"
		DEB="$PWD/google-chrome-${CHANNEL}_current_amd64.deb"
		TMP="$(mktemp -d)"
		trap 'rm -rf "$TMP"' EXIT

		curl -fsSL "$DIRECT_URL" -o "$DEB"
		# Validate the ar magic bytes (!<arch>) — command substitution strips
		# trailing newlines, so check only the 7-byte signature. Avoids the
		# `file` binary, which SIGSYS-crashes under fakeroot on some systems.
		[ "$(head -c 7 "$DEB")" = '!<arch>' ] || {
			echo "update.sh: downloaded file is not a valid .deb" >&2
			exit 1
		}

		# The .deb is an ar archive holding data.tar.xz; extract its payload.
		bsdtar -xf "$DEB" -C "$TMP"
		bsdtar -xf "$TMP/data.tar.xz" -C "$PKGDIR"

		echo "update.sh: extracted Chrome ${CHANNEL} into $PKGDIR" >&2
		;;

	*)
		echo "usage: update.sh {check|extract <pkgdir>}" >&2
		exit 1
		;;
esac
