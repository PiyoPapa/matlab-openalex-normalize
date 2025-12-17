# Schema v0.2.0 – Design Notes (Draft)

## Scope
- Add: sources.csv, institutions.csv
- Exclude: references, abstracts, counts_by_year

## New CSVs
### sources.csv
- 1 row = 1 Source (primary_location.source)
- Primary key: source_id (OpenAlex URL)

### institutions.csv
- 1 row = 1 Institution
- Primary key: institution_id (OpenAlex URL)
- Derived from authorships

## Extraction Rules
- Use primary_location only
- Ignore secondary locations
- No expansion of references

## Row Explosion Policy
- No Work × Location expansion
- No Work × Institution expansion beyond authorships

## Backward Compatibility
- v0.1 CSVs are untouched (columns frozen)