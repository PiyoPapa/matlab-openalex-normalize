# matlab-openalex-normalize
[![Open in MATLAB Online](https://www.mathworks.com/images/responsive/global/open-in-matlab-online.svg)](https://matlab.mathworks.com/open/github/v1?repo=PiyoPapa/matlab-openalex-normalize)

Normalize OpenAlex API JSONL into fixed-schema CSVs in MATLAB (sources, venues, manifests)

This repository converts **standard JSONL (1 Work per line)** into a small set of
**versioned, analysis-ready CSVs**.

It is intentionally separated from the data acquisition layer:

- **Acquisition (fetch):**
  [`matlab-openalex-pipeline`](https://github.com/PiyoPapa/matlab-openalex-pipeline)

Related repos:
- `matlab-openalex-pipeline` (fetch / cursor / array-per-line JSONL)
- `matlab-openalex-normalize` (this repo; normalize to versioned CSV)

## Scope (What this repo does / does not do)
### Non-goals (v0.1)

This project is **not** intended to be:
- a full-text mining or NLP pipeline
- a citation-network or reference-graph analysis engine
- a general-purpose OpenAlex client covering all use cases

Instead, v0.1 focuses on:
- stable, versioned normalization
- reproducible metadata analysis
- MATLAB-centric research and educational workflows

### This repo DOES
- Read **standard JSONL**: 1 line = 1 OpenAlex Work object
- Normalize into **versioned CSV schemas**
- Write outputs into a **run folder** with a required `run_manifest.json`
- Keep IDs stable by using **OpenAlex URL strings** as primary keys (e.g., `work_id`, `author_id`, ...)

### This repo DOES NOT
- Fetch data from OpenAlex (use `matlab-openalex-pipeline`)
- Provide downstream analysis / visualization
- Build citation graphs by default (`references` is explicitly postponed)

## Input format (Important)

### Accepted input
- **Standard JSONL only**: `1 record (Work) per line`

This repo expects JSONL that is **standard JSONL**. If your pipeline output is "array-per-line JSONL",
convert it first (a converter script can be provided in this repo).

### NOT accepted
- "Array-per-line" JSONL (1 line = an array of Works)
  - This format is used for high-throughput I/O in the pipeline repo, but must be converted before normalization.

## Output layout (run folder)

All outputs are written under:

`data_processed/<YYYYMMDD_HHMM>_n<records>/`

Example:
`data_processed/20251216_0815_n10000/`

Required file:
- `run_manifest.json` (always written)

CSV encoding:
- UTF-8

> **Note on CSV encoding**
>
> CSV files are written in **UTF-8**.
> When opening these files in Microsoft Excel on Windows,
> please ensure that UTF-8 encoding is explicitly selected
> to avoid character corruption (e.g., non-ASCII author names).

> **Note on scalability**
>
> CSV outputs are intended as **intermediate, exchange-friendly formats**.
> For large-scale analysis (hundreds of thousands to millions of records),
> users are expected to load these CSVs into databases, Parquet files,
> or other analytical backends of their choice.

## Manifest (run_manifest.json)

`run_manifest.json` MUST include at least:
- `input_path`
- `processed_records`
- `timestamp`
- `schema_version` (`v0.1` / `v0.2`)
- `git_commit` (if available)
- `tool` (e.g., "matlab-openalex-normalize")
- `matlab_release` (if available)
- `errors` (summary counts, optional)

Example:

```json
{
  "schema_version": "v0.1",
  "timestamp": "2025-12-16T08:15:00+09:00",
  "input_path": "data/openalex_MATLAB_cursor_en.standard.jsonl",
  "processed_records": 10000,
  "git_commit": "abc1234",
  "tool": "matlab-openalex-normalize",
  "matlab_release": "R2025b",
  "errors": { "skipped_missing_required": 12 }
}
```

## Schema versions
### v0.1 (Minimum stable set; fixed columns)

Produces exactly 3 CSV files (columns are fixed for the v0.1 line):

1. **works.csv**
   - 1 row = 1 Work
   - Primary key: `work_id`

2. **authorships.csv**
   - 1 row = 1 (Work × Author)

3. **concepts.csv**
   - 1 row = 1 (Work × Concept)

>Goal: cover the "core 80%" for bibliometrics / co-authorship / field / time-series.

### v0.2 (Extension; v0.1 unchanged)

Adds:

4. **sources.csv**
    - Uses primary_location.source as the standard source definition

5. **institutions.csv**
    - Derived from authorships (institution-level analysis)

6. **(reserved)**
    - references is intentionally NOT included

7. **counts_by_year.csv (planned)**
    - in future

### v0.3 (Planned; optional)

- references.csv (Work × ReferencedWork)
- Must be optional (default OFF)
- Must provide a limiter (e.g., maxReferencesPerWork)

## Proposed column definitions (v0.1)

>NOTE: These are the v0.1 fixed columns proposed for the initial release.
If you need to add columns, do it as a new schema version (v0.2+).

### works.csv
- work_id (string, OpenAlex URL)
- doi (string, nullable)
- title (string, nullable)
- publication_year (double/int, nullable)
- publication_date (string, nullable; ISO date)
- type (string, nullable)
- language (string, nullable)
- cited_by_count (double/int, nullable)
- is_oa (logical/bool, nullable)
- oa_status (string, nullable)

### authorships.csv
- work_id (string)
- author_id (string)
- author_display_name (string, nullable)
- author_orcid (string, nullable)
- author_position (string, nullable)
- is_corresponding (logical/bool, nullable)
- institution_id (string, nullable)
- institution_display_name (string, nullable)
- country_code (string, nullable)

### concepts.csv
- work_id (string)
- concept_id (string)
- concept_display_name (string, nullable)
- concept_level (double/int, nullable)
- concept_score (double, nullable)

> Notes on v0.1 limitations:
>
> - `authorships.csv` stores **only the first institution** per authorship.
>   In the raw OpenAlex data, approximately 10–15% of authorships may have
>   multiple institutions. Full expansion of institutions is planned for v0.2.
>
> - `oa_url` is intentionally **not included** in v0.1.
>   OpenAlex provides multiple URL concepts (OA URL, landing page, PDF URL),
>   and a single `oa_url` column was found to be semantically ambiguous.
>   URL fields will be reintroduced with explicit meanings in v0.2.

> - `summary` / plaintext abstract is intentionally **not included** in v0.1.
>   OpenAlex typically provides abstracts as `abstract_inverted_index`
>   rather than plaintext due to legal and licensing constraints.
>   Abstract handling is **intentionally separated** from the core normalization layer.
>   Optional reconstruction (length-limited or as a separate CSV such as `abstracts.csv`)
>   may be introduced in v0.2 as an **opt-in feature**.

### Installation

Clone this repository and add src/ to your MATLAB path.

Example:
```matlab
addpath(genpath("src"));
```

## Quick start
1.Convert pipeline JSONL to standard JSONL (if needed)

If needed, convert array-per-line JSONL to standard JSONL using a converter script (either from the pipeline repo or this repo).

2.Normalize
```matlab
inJsonl = "data/openalex_MATLAB_cursor_en.standard.jsonl";
outDir  = fullfile("data_processed", "20251216_0815_n10000");

normalize_openalex(inJsonl, outDir, ...
    "schemaVersion","v0.1", ... % fixed columns for v0.1
    "verbose",true);
```

Outputs:
- run_manifest.json
- works.csv
- authorships.csv
- concepts.csv

### Design principles
- Separation of concerns: acquisition vs normalization
- Streaming-first (avoid holding everything in memory)
- Schema is versioned and fixed per version
- Defaults avoid "row explosion" features (e.g., references)

## License
MIT
