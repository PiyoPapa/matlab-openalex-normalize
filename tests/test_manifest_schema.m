function tests = test_manifest_schema
tests = functiontests(localfunctions);
end

function test_manifest_has_errors_struct_and_v02_keys(testCase)
repoRoot = string(pwd);

% Ensure paths (example script assumes this too)
addpath(genpath(fullfile(repoRoot,"src")));

% Input: use the same naming convention as examples
rawDir  = fullfile(repoRoot, "data_raw");
inJsonl = fullfile(rawDir, "openalex_MATLAB_cursor_en_500.jsonl");
testCase.assertTrue(isfile(inJsonl), "Missing input JSONL: %s", inJsonl);

% Convert if needed (same logic as example_v0_2_500)
stdJsonl = fullfile(rawDir, "openalex_MATLAB_cursor_en_500.standard.jsonl");
doConvert = should_convert_jsonl(inJsonl);
if doConvert
    % NOTE: jsonl_array2standard must exist on path; if not, this will fail
    jsonl_array2standard(inJsonl, stdJsonl, "overwrite", true, "verbose", false);
else
    stdJsonl = inJsonl;
end

% Output folder (unique per run)
runTag = string(datetime("now","TimeZone","Asia/Tokyo","Format","yyyyMMdd_HHmmss"));
outDir = fullfile(repoRoot, "data_processed", "TEST_" + runTag + "_n20");

manifest = normalize_openalex(stdJsonl, outDir, ...
    "schemaVersion","v0.2", ...
    "overwrite", true, ...
    "maxRecords", 20, ...
    "verbose", false);

% File exists
manifestPath = fullfile(outDir, "run_manifest.json");
testCase.assertTrue(isfile(manifestPath), "run_manifest.json was not created");

% Basic structure checks
testCase.verifyTrue(isstruct(manifest), "manifest must be a struct");
testCase.verifyTrue(isfield(manifest, "errors"), "manifest.errors must exist");
testCase.verifyTrue(isstruct(manifest.errors), "manifest.errors must be a struct");

% v0.2 expected keys (your code currently writes these on success)
% If missing => v0.2.2 needs to fix schema stability.
mustHave = [
    "skipped_missing_required"
    "missing_primary_location_source_count"
    "missing_primary_location_source_id_count"
    "missing_primary_location_source_work_ids"
    ];
for k = 1:numel(mustHave)
    testCase.verifyTrue(isfield(manifest.errors, mustHave(k)), ...
        "manifest.errors.%s is missing (schema not stable)", mustHave(k));
end
end

% ---- helpers copied/adapted from example_v0_2_500 (keep local for tests) ----
function tf = should_convert_jsonl(jsonlPath)
fid = fopen(jsonlPath,"r");
assert(fid>0, "Failed to open: %s", jsonlPath);
c = onCleanup(@() fclose(fid)); %#ok<NASGU>
tf = true;
while true
    ln = fgetl(fid);
    if ~ischar(ln), break; end
    s = strtrim(string(ln));
    if s == "", continue; end
    tf = startsWith(s, "[");
    break
end
end
