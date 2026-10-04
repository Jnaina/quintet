# Quintet

A five-letter word-deduction game for iPhone (iOS 17+), built from a developer specification for a daily five-letter word puzzle (the specification itself is not included here).
Not a daily puzzle: start a new game any time; each game picks a fresh random word from `Resources/words.txt` (3,555 words, used for both answers and valid guesses).

## Features (per the spec)
Six guesses, two-pass duplicate-safe evaluation, strict mode (chosen before the first guess), keyboard letter states that only get stronger,
split-flap / shake / bounce animations (reduced-motion aware), light / dark / high-contrast themes, statistics (played, win %, streaks, 1-6 distribution),
spoiler-free share + copy, instructions with examples, VoiceOver labels on every tile and key, physical keyboard support,
and game state saved after every accepted guess (restored on relaunch; a finished game updates statistics only once).

## Look and feel
Pure black background by default (Settings > Theme: Automatic / Light / Black; launch screen is black too).
Tile reveal is an airport-board **split-flap**: each tile clacks through 3 flaps (a dark flap face counting up through the 2 letters before the target, then the target on its result colour); the top half falls and the bottom half lands on each flap. One tile takes 0.126 s; the next tile starts when the previous one is 60% through (0.076 s) - see `FlipTiming` in `Engine.swift` (`-slowflip` launch argument slows it 10x for inspection). Reduce Motion replaces it with a short fade.
The game is silent (the flip sound was tried and removed at the user's request).

## Layout
- `Sources/Engine.swift`  pure logic (evaluation, strict mode, key states, stats) - tested by `tests/main.swift`
- `Sources/Model.swift`, `Views.swift`, `Panels.swift`, `Theme.swift`, `QuintetApp.swift`  SwiftUI app
- `Resources/words.txt` (3,555 five-letter words, used for answers and valid guesses), `Assets.xcassets` (original app icon), `preview/`
- `tests/main.swift`  engine tests

## Test and build
    swiftc -O Sources/Engine.swift tests/main.swift -o /tmp/t && /tmp/t        # engine tests
    xcodegen generate
    xcodebuild -project Quintet.xcodeproj -scheme Quintet -sdk iphoneos -configuration Release \
      -destination 'id=<iPhone UDID>' -allowProvisioningUpdates -allowProvisioningDeviceRegistration -derivedDataPath build-dev build
    xcrun devicectl device install app --device <UDID> build-dev/Build/Products/Release-iphoneos/Quintet.app

Launch arguments for the simulator: `-demo` (plays sample guesses), `-demowin` (plays a winning game).
Free-account note: the bundle ID `com.jnaina.galaga88` is reused (App ID quota); on the phone trust the developer under Settings > General > VPN & Device Management.

## Signing
The Apple team ID is intentionally blank. To build for a device, either set `DEVELOPMENT_TEAM` in `project.yml` (then run `xcodegen generate`) or append `DEVELOPMENT_TEAM=<your team id>` to the `xcodebuild` command line. Simulator builds need no signing (`CODE_SIGNING_ALLOWED=NO`).
