#!/bin/zsh
# Snapshots of every page in light and dark, with seed data, on a fresh test store.
# Usage: tools/snap.sh            all pages
#        APP_SNAPSHOT_PAGES=all,settings tools/snap.sh
#        tools/snap.sh -appearance.liquidGlass YES     arguments go to the app (here: Liquid Glass on, whatever Settings says)
set -u
app=~/Applications/TwodayNote.app/Contents/MacOS/TwodayNote
store=/tmp/TwodayNote-test.json
shots=/tmp/TwodayNote-shots
# A crashed run leaves saved window state, and the next launch would wait on a "reopen windows?" alert.
rm -rf ~/Library/Saved\ Application\ State/com.vuongnguyen.twodaynote.savedState
# Seed data only fills an empty store, so start from nothing.
rm -f $store
rm -rf $shots
APP_STORE=$store APP_SEED=1 APP_SNAPSHOT=$shots $app "$@"
