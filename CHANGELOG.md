# Changelog

## v0.2.2

### Added
- Stable `run_manifest.json.errors` schema (always-present keys)
- Failure-tolerant handling of `sources.csv` writing
- Unit tests covering both success and failure paths

### Fixed
- Defensive CSV writing for missing / malformed source records
- Removal of filesystem-dependent warnings during overwrite runs

### Notes
- Deprecated legacy error keys remain for backward compatibility
