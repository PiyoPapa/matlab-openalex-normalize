# matlab-openalex-normalize
[![Open in MATLAB Online](https://www.mathworks.com/images/responsive/global/open-in-matlab-online.svg)](https://matlab.mathworks.com/open/github/v1?repo=PiyoPapa/matlab-openalex-normalize)

Normalize standard OpenAlex Works JSONL into fixed-schema CSVs in MATLAB (versioned CSV + run_manifest)

This repository converts **standard JSONL (1 Work per line)** into a small set of
**versioned, analysis-ready CSVs**.

> **Design intent (important)**
>
> This repository is designed as a **stable normalization core**.
> It intentionally avoids downstream analytics, visualization,
> large-scale graph construction, or GPU-heavy processing.
>
> The primary goal is to provide **reproducible, fixed-schema CSV outputs**
> that can be safely used by researchers who are not data-engineering specialists.
>
> Heavy or exploratory analysis is expected to live in *separate repositories*
> that consume the outputs of this project.

> **Version note**
>
> The behavior described below reflects the implementation as of **v0.2.3**.
> Minor v0.2.x releases may introduce optional, backward-compatible outputs.

> **Compatibility note**
>
> This repo is intended to consume "standard JSONL" generated from
> `matlab-openalex-pipeline` (array-per-line JSONL must be converted first).
> Recommended compatibility policy:
> `matlab-openalex-pipeline >= v0.1.x` (fill in the minimum version you actually tested)

It is intentionally separated from the data acquisition layer:

- **Acquisition (fetch):**
  [`matlab-openalex-pipeline`](https://github.com/PiyoPapa/matlab-openalex-pipeline)

Downstream / related projects:
- **Topic mapping / clustering / visualization (GPU-heavy examples):**
  `matlab-openalex-map` (optional; analysis examples / visualization)
- **Citation graphs / reference edges (advanced users):**
  `matlab-openalex-edges` (separate repository; not part of this repo)

Related repos:
- `matlab-openalex-pipeline` (fetch / cursor / array-per-line JSONL)
- `matlab-openalex-normalize` (this repo; normalize to versioned CSV)

## Scope (What this repo does / does not do)
### Non-goals

This project is **explicitly NOT** intended to be:
- a full-text mining or NLP pipeline
- a citation-network or reference-graph analysis engine
- a general-purpose OpenAlex client covering all use cases
- a real-time monitoring system or research information OS
- a GPU-accelerated analytics or embedding pipeline

Instead, this repository focuses on:
- stable, versioned normalization
- reproducible metadata analysis
- MATLAB-centric research and educational workflows

### This repo DOES
- Read **standard JSONL**: 1 line = 1 OpenAlex Work object
- Normalize into **versioned CSV schemas**
- Write outputs into a **run folder** with a required `run_manifest.json`
- Keep IDs stable by using **OpenAlex URL strings** as primary keys (e.g., `work_id`, `author_id`, ...)

### This repo DOES NOT
- Perform semantic analysis, embeddings, clustering, or topic modeling
- Reconstruct or analyze abstracts / plaintext
- Manage scheduled data collection or notifications
- Provide dashboards or web-based interfaces
- Fetch data from OpenAlex (use `matlab-openalex-pipeline`)
- Provide downstream analysis / visualization
- Build citation graphs or reference edges

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
- `errors`(always present; fixed schema from v0.2.3)

Example (v0.2):

```json
{
  "schema_version": "v0.2",
  "timestamp": "2025-12-19T21:50:48+09:00",
  "input_path": "data/openalex_MATLAB_cursor_en.standard.jsonl",
  "processed_records": 500,
  "written_works": 500,

  "written_sources": 168,
  "unique_sources": 168,

  "written_institutions_rows": 1353,
  "written_counts_by_year_rows": 1,
  "unique_years": 1,

  "git_commit": "94442e1",
  "tool": "matlab-openalex-normalize",
  "matlab_release": "R2025b",

  "errors": {
    "missing_primary_location_source_count": 5,
    "missing_primary_location_source_id_count": 5,
    "missing_primary_location_source_work_ids": [
      "https://openalex.org/W4417279310",
      "https://openalex.org/W4417302039"
    ],

    "sources_write_failed": false,
    "sources_write_error_message": "",

    "institutions_write_failed": false,
    "institutions_write_error_message": "",

    "counts_by_year_write_failed": false,
    "counts_by_year_write_error_message": ""
  }
}
```

### Notes on errors (v0.2.3)

From v0.2.3, the `errors` object in `run_manifest.json` follows a fixed-key schema.
All keys listed below are always present, even if their values are zero, false,
or empty strings.

- missing_primary_location_source_count
- missing_primary_location_source_id_count
- missing_primary_location_source_work_ids
- sources_write_failed
- sources_write_error_message
- institutions_write_failed
- institutions_write_error_message
- counts_by_year_write_failed
- counts_by_year_write_error_message

This allows downstream code to rely on the presence and type of error fields
without conditional existence checks, even when optional writers are enabled.

> Backward compatibility
>
> Outputs generated by v0.2.2 remain valid in v0.2.3.
> Optional outputs and their associated manifest keys introduced in v0.2.3
> (e.g., institutions.csv, counts_by_year.csv) may be absent in earlier runs.
> Downstream consumers MUST handle their absence gracefully.

## Project positioning

This repository represents the **normalization layer** in a larger OpenAlex-based workflow:

1. **Acquisition** — fetch OpenAlex data (`matlab-openalex-pipeline`)
2. **Normalization** — fixed-schema, versioned CSVs (**this repo**)
3. **Exploration / mapping** — clustering, topic maps, visualization (separate repos)
4. **Advanced analysis** — citation graphs, large-scale networks (separate repos)

Keeping these layers separate is a deliberate design choice
to minimize user error, maintenance burden, and accidental misuse.
 
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

v0.2 extends v0.1 without changing any v0.1 CSV schemas/columns.

#### v0.2.0 (core extension)
Adds:

4. **sources.csv**
   - Uses `primary_location.source` as the standard source definition
   - Some Works legitimately have no source in OpenAlex metadata (e.g., some book-chapters).
     These Works remain in `works.csv` but do not contribute to `sources.csv`.

   **Columns (v0.2.0):**
   - `source_id` (string): OpenAlex Source ID (URL)
   - `source_display_name` (string, nullable)
   - `source_type` (string, nullable; e.g., journal, conference, book)
   - `issn_l` (string, nullable)
   - `is_oa` (logical/bool, nullable)
   - `host_organization_id` (string, nullable)
   - `works_count_seen` (double/int): number of Works associated with this source

Also improves `run_manifest.json`:
   - `errors.missing_primary_location_source_count`
   - `errors.missing_primary_location_source_work_ids` (optional; for reproducibility)

> Note on sources.csv (v0.2.2)
>
> Writing sources.csv may fail in some runs (e.g., filesystem-related issues).
> In such cases:
>
> - normalization continues
> - other CSV outputs are still written
> - the failure is recorded in run_manifest.json.errors

#### v0.2.x (optional additions)
Introduced as optional, safe additions in v0.2.3:

5. **institutions.csv**
   - Derived from authorships (institution-level analysis)
   - **1 row = (work_id × author_id × institution_id)**
   - Fully expands multi-institution authorships (no truncation)
   - Intended for institution-level aggregation and analysis
   - Optional output: normalization continues even if writing fails

6. **counts_by_year.csv**
   - Derived from `works.csv`
   - **1 row = (publication_year × works_count)**
   - Sum of works_count always equals the number of rows in works.csv
   - Intended for quick time-series inspection and sanity checks
   - Optional output: normalization continues even if writing fails

## Out of scope
The following items are intentionally excluded from this repository
and will not be implemented here.

- citation or reference edge tables (e.g., Work × ReferencedWork)
- graph-style relationship outputs
- large-scale row-exploding expansions

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

## What to do next

After normalization, typical next steps include:
- **Topic mapping / clustering / visualization**
  - See: `matlab-openalex-map`
  - GPU / toolbox requirements may apply

- **Citation or reference analysis**
  - See: `matlab-openalex-edges` (planned)
  - Intended for advanced users handling large edge tables

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

* * *
## FAQ

### What input format is accepted?
Only **standard JSONL** is accepted: `1 line = 1 OpenAlex Work object`.
If your input is array-per-line JSONL (from `matlab-openalex-pipeline`), convert it first.

### How do I convert pipeline output to standard JSONL?
Use the pipeline helper (recommended):

    inJsonl  = "data/openalex_....jsonl";
    outJsonl = "data/openalex_....standard.jsonl";
    n = openalex_write_jsonl(inJsonl, outJsonl);

### What does v0.1 produce?
v0.1 produces exactly these fixed-schema CSVs:
`works.csv`, `authorships.csv`, `concepts.csv` (plus `run_manifest.json`).

### What does v0.2 add?
v0.2 extends outputs (while keeping v0.1 unchanged).
In v0.2.0, this includes `sources.csv`.
Optional CSVs introduced in v0.2.x are documented above.

### Does this repo deduplicate or "clean" OpenAlex data?
No. It normalizes structure into a stable schema. If you need heavy cleaning/deduplication, do it downstream.

### How are IDs represented?
Primary keys are kept stable using OpenAlex URL strings (e.g., `work_id`, `author_id`, `source_id`).

### Why are references not included?
Because reference expansion can easily explode row counts and complexity.
Such features are intentionally out of scope for this repository.

### Excel / UTF-8: why do characters break?
CSVs are written in UTF-8. Excel on Windows may mis-detect encoding; select UTF-8 explicitly when opening.

### How large can this scale?
Normalization is streaming-first where possible, but CSVs are an intermediate format.
For very large datasets, load results into a database/Parquet/other backend of your choice.

### Design principles
- Separation of concerns: acquisition vs normalization
- Streaming-first (avoid holding everything in memory)
- Schema is versioned and fixed per version
- Defaults avoid "row explosion" features (e.g., references)

## Disclaimer 
The author is an employee of MathWorks Japan. 
This repository is a personal experimental project developed independently and is not part of any MathWorks product, service, or official content. 
MathWorks does not review, endorse, support, or maintain this repository. 
All opinions and implementations are solely those of the author.

## License 
MIT License. See the LICENSE file for details. 

## A note for contributors 
This repository prioritizes: 
- clarity over abstraction
- reproducibility over convenience
- explicit configuration over magic defaults 

## Contact 
This project is maintained on a best-effort basis and does not provide official support. 
If you plan to extend it, please preserve these principles.
