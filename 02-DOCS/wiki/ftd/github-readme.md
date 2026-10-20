# GitHub README

## Intent
Replace Flutter's starter README with an English, GitHub-ready introduction to Fynitiv that
preserves the creator's playful tone, highlights the supplied product features, and explains
the Jellyfin requirement and optional service integrations without overstating them.

## Scope
- In:
  - English README with project logo, short value proposition, feature overview, platform
    targets, prerequisites / getting started, optional integrations, and friendly call to action.
  - Preserve and polish the user's tone: one center across platforms, customizable skins,
    karaoke/music effects, subtitle sync, games, media requests, no extra Jellyfin plugins for
    core functionality, and the nice-creator line.
- Out:
  - Add screenshots that are not present in the repository.
  - Invent release download URLs, license, pricing, or support guarantees.
  - Change app code, packages, or tests.

## Checklist
- [x] FTD created before the README change.
- [x] Replace starter README with English product copy.
- [x] Verify relative logo path and feature/platform claims against repository/user-provided
  details.

## Evidence
- Existing `README.md` is the default Flutter starter text.
- `assets/images/Logo_fynitiv.png` exists and is suitable as the GitHub header image.
- Feature folders confirm Jellyfin video/library, music, lyrics/effects, books/e-reader, games,
  radio/Live TV, subtitles, and Seerr.
- ROMM is configured as an external game-library service; Seerr is an optional request/discovery
  integration. Core Jellyfin use should not be described as requiring extra Jellyfin plugins.
- Android and Windows target directories exist. The in-app splash explicitly lists Android,
  Linux and Windows as available platforms; README will use those user-confirmed targets.
- Repositories include no prepared README screenshots or known release/license URL to link.
- `README.md` now contains the logo, product pitch, feature list, platform targets, optional
  integrations, Getting Started, Flutter source-run commands, and the creator's friendly call
  to ask for missing features.
- `git diff --check` completed without whitespace errors (Git reports only expected LF→CRLF
  working-copy notices).

## Next
Add official release, screenshots, license, and repository/support links when those destinations
are finalized; review the README on GitHub for image sizing and layout.
