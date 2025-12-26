# matlab-openalex-normalize
[![Open in MATLAB Online](https://www.mathworks.com/images/responsive/global/open-in-matlab-online.svg)](https://matlab.mathworks.com/open/github/v1?repo=PiyoPapa/matlab-openalex-normalize)

Normalize standard OpenAlex Works JSONL into fixed-schema CSVs in MATLAB.
This repository provides a conservative normalization layer that converts
OpenAlex metadata into versioned CSV files for reproducible,
time-bounded exploratory use.

## Overview
This repository provides a **conservative normalization layer** for transforming
standard OpenAlex Works JSONL into **stable, inspection-ready CSV files** for
time-bounded exploratory workflows.

**What this repository provides**
- Deterministic normalization from standard OpenAlex JSONL (1 Work per line)
- Fixed, versioned CSV schemas with stable primary keys
- A required `run_manifest.json` capturing inputs, versions, and errors

**What this repository does NOT provide**
- Data acquisition from OpenAlex
- Semantic analysis, embeddings, clustering, or visualization
- Citation graph construction or large-scale network processing
- Automated cleaning, deduplication, or optimization beyond schema normalization

## Repository position in the OpenAlex–MATLAB workflow
This repository represents the **normalization layer** in a three-stage workflow:

1. **Acquisition** — fetch OpenAlex Works  
   → [`matlab-openalex-pipeline`](https://github.com/PiyoPapa/matlab-openalex-pipeline)

2. **Normalization** — fixed-schema, versioned CSVs (**this repository**)  
   → [`matlab-openalex-normalize`](https://github.com/PiyoPapa/matlab-openalex-normalize)

3. **Analysis / topic mapping** — diagnostics and semantic maps  
   → [`matlab-openalex-analyze`](https://github.com/PiyoPapa/matlab-openalex-analyze)
 
## Who this repository is for
This repository is for:
- Users who already have **standard OpenAlex Works JSONL** and need **inspection-ready, fixed-schema CSVs**
- Workflows that require **reproducible outputs** with explicit run metadata (`run_manifest.json`)

This repository is NOT for:
- Fetching data from OpenAlex (use `matlab-openalex-pipeline`)
- Analysis / topic mapping (use `matlab-openalex-analyze`)

## Scope and non-goals
### In scope
- Deterministic normalization from standard OpenAlex JSONL to fixed, versioned CSV schemas
- Explicit run manifests capturing inputs, versions, and normalization errors

### Out of scope
- Data acquisition, semantic analysis, embeddings, clustering, visualization, or graph construction
- Automated cleaning, deduplication, or optimization beyond schema normalization

This repository prioritizes:
- reproducibility over convenience
- transparency over abstraction
- explicit configuration over hidden defaults

## Repository layout
- `src/` — core normalization logic and schema-specific writers
- `data_processed/` — user-created, run-scoped output folders
- `docs/` — schema notes or supporting documentation (if present)
  
## Input / Output
### Input
- **Standard JSONL only** (`1 Work per line`)
- Array-per-line JSONL must be converted prior to normalization

### Output
- All outputs are written under `data_processed/<YYYYMMDD_HHMM>_n<records>/`
- `run_manifest.json` is always written and records inputs, versions, and errors
- CSV files are UTF-8 encoded and follow a fixed schema per version

CSV outputs are intended as intermediate, exchange-friendly formats; for very
large datasets, downstream database or columnar storage is recommended.
  
## Demos / Examples
Examples in this repository are intentionally minimal and limited to
normalization behavior and schema inspection. Analytical, visualization,
or semantic examples are maintained in downstream repositories.

## When to stop here / when to move on
- You can stop here if:
  - You only need stable, inspection-ready CSV exports (with a recorded manifest) for downstream use
- You may proceed to the next stage if:
  - You need diagnostics, semantic inspection, or topic mapping on normalized outputs  
  → [`matlab-openalex-analyze`](https://github.com/PiyoPapa/matlab-openalex-analyze)
 

## Schema / column definitions

### Schema versions
- **v0.1**: minimum stable set with fixed columns
- **v0.2**: backward-compatible extensions (no changes to v0.1 columns)

#### v0.1 outputs
Produces exactly:
- `works.csv`
- `authorships.csv`
- `concepts.csv`

#### v0.2 extensions
- `sources.csv` (v0.2.0)
- Optional outputs (v0.2.3+):
  - `institutions.csv`
  - `counts_by_year.csv`

Optional outputs do not block normalization if writing fails; failures are
recorded in `run_manifest.json`.

### Column definitions (v0.1)

**works.csv**
- work_id (string, OpenAlex URL)
- doi (string, nullable)
- title (string, nullable)
- publication_year (int, nullable)
- publication_date (string, nullable)
- type (string, nullable)
- language (string, nullable)
- cited_by_count (int, nullable)
- is_oa (bool, nullable)
- oa_status (string, nullable)

**authorships.csv**
- work_id (string)
- author_id (string)
- author_display_name (string, nullable)
- author_orcid (string, nullable)
- author_position (string, nullable)
- is_corresponding (bool, nullable)
- institution_id (string, nullable)
- institution_display_name (string, nullable)
- country_code (string, nullable)

**concepts.csv**
- work_id (string)
- concept_id (string)
- concept_display_name (string, nullable)
- concept_level (int, nullable)
- concept_score (double, nullable)

**Limitations**
- Only the first institution per authorship is stored in `authorships.csv`
- Abstract plaintext and URL fields are intentionally excluded

## Installation / Quick start

### Installation
Clone this repository and add `src/` to the MATLAB path:

```matlab
addpath(genpath("src"));
```

### Quick start
1. Convert pipeline JSONL to standard JSONL (if required)
2. Run normalization:

```matlab
inJsonl = "data/openalex_MATLAB_cursor_en.standard.jsonl";
outDir  = fullfile("data_processed", "20251216_0815_n10000");

normalize_openalex(inJsonl, outDir, ...
    "schemaVersion","v0.1", ...
    "verbose",true);
```

## Disclaimer 
The author is an employee of MathWorks Japan. 
This repository is a personal experimental project developed independently and is not part of any MathWorks product, service, or official content. 
MathWorks does not review, endorse, support, or maintain this repository. 
All opinions and implementations are solely those of the author.

## License 
MIT License. See the LICENSE file for details. 

## Notes
This repository prioritizes:
- reproducibility over convenience
- transparency over abstraction
- explicit configuration over hidden defaults

This project is maintained on a best-effort basis and does not provide official support.
For bug reports or questions, please use GitHub Issues.