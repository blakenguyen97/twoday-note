#!/bin/zsh
# Runs the in-app self-test against a fresh store in /tmp. Exit code 0 when every check passed.
set -u
rm -rf ~/Library/Saved\ Application\ State/com.vuongnguyen.twodaynote.savedState
store=/tmp/TwodayNote-self.json
rm -f $store
APP_STORE=$store ~/Applications/TwodayNote.app/Contents/MacOS/TwodayNote --selftest
