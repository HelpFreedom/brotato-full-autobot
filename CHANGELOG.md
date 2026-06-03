# Changelog

All notable changes to **Full Auto Bot** are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/),
and this project adheres to [Semantic Versioning](https://semver.org/).

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
