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

## v0.2.3

### Added
- Optional output `institutions.csv` for institution-level normalization.
  - Fully expands authorship institutions.
  - 1 row represents a unique `(work_id, author_id, institution_id)` combination.
- Optional output `counts_by_year.csv` derived from `works.csv`.
  - 1 row represents `(publication_year, works_count)`.

### Changed
- `run_manifest.json` error reporting follows a fixed-key schema.
  - Added fixed error flags for optional writers:
    - `institutions_write_failed`
    - `institutions_write_error_message`
    - `counts_by_year_write_failed`
    - `counts_by_year_write_error_message`
- Optional writers are failure-tolerant and do not abort normalization.

### Notes
- This release completes the v0.2.x normalization scope.
- Row-exploding features such as reference/citation expansion remain explicitly out of scope.
