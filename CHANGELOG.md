# Changelog

All notable changes to **Full Auto Bot** are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [0.1.2] — 2026-06-03

### Fixed
- Zip top-level structure: now `mods-unpacked/BlackTriangle-FullAutoBot/...`
  instead of `BlackTriangle-FullAutoBot/...`. Brotato's ModLoader Workshop
  loader strictly requires the `mods-unpacked/` prefix and silently rejected
  the v0.1.0/v0.1.1 packages with `"does not have the correct file structure"`.
  Local-folder loading was more permissive, which is why the issue went
  unnoticed during local testing.
- Updated the GitHub Action accordingly so released artifacts are packaged
  correctly going forward.

## [0.1.1] — 2026-06-03

### Fixed
- Declared `compatible_game_version` as `1.1.15.4` (and the rest of the
  1.1.15.x line) so ModLoader no longer shows the "outdated mod" warning
  every time the player returns to the main menu.
- Declared `compatible_mod_loader_version` as `["6.0.0", "6.1.0", "6.3.0"]`
  to match the ModLoader versions Brotato ships with.

## [0.1.0] — 2026-06-03

### Added
- Robot button on the difficulty-selection screen that activates the bot
  and launches a Danger 6 run.
- Bot driver: movement, shop, level-up, and crate decisions.
- Per-character strategies for all **64** base and DLC characters,
  ported from the Python prototype.
- DPS / effective-HP combat valuation for shop and level-up picks.
- Movement strategies: sampling flee, orbital flee, pure-repulsion
  flee, panic-dodge override.
- Mirror-bullet trap fix (perpendicular escape when two opposing
  projectiles cancel each other out).
- Manual override: pressing any movement key hands control back to
  the player for the rest of the run.

### Compatibility
- Brotato 1.1.15+
- ModLoader 6.x
- Tested with the *Abyssal Terrors* DLC characters.

[0.1.0]: https://github.com/HelpFreedom/brotato-full-autobot/releases/tag/v0.1.0
[0.1.1]: https://github.com/HelpFreedom/brotato-full-autobot/releases/tag/v0.1.1
[0.1.2]: https://github.com/HelpFreedom/brotato-full-autobot/releases/tag/v0.1.2
