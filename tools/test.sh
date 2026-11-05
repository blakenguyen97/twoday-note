#!/bin/zsh
# Unit tests for TwodayNoteKit. With only the Command Line Tools (no Xcode),
# SwiftPM does not find the swift-testing macro plugin, so pass its path.
set -u
plugins=/Library/Developer/CommandLineTools/usr/lib/swift/host/plugins/testing
extra=()
[[ -d $plugins ]] && extra=(-Xswiftc -plugin-path -Xswiftc $plugins)
swift test --package-path "${0:A:h:h}" --scratch-path ~/Library/Developer/TwodayNote/test-build $extra
