function tests = test_manifest_schema
tests = functiontests(localfunctions);
end

% NOTE: This test suite intentionally includes both success and failure paths.
 
function test_manifest_has_errors_struct_and_v02_keys(testCase)
thisFile = mfilename("fullpath");
testsDir = fileparts(thisFile);           % .../<repo>/tests
repoRoot = string(fileparts(testsDir));   % .../<repo>

% Ensure paths (example script assumes this too)
addpath(genpath(fullfile(repoRoot,"src")));

% Input: use the same naming convention as examples
rawDir  = fullfile(repoRoot, "data_raw");
inJsonl = fullfile(rawDir, "openalex_MATLAB_cursor_en_500.jsonl");
testCase.assertTrue(isfile(inJsonl), ...
    sprintf("Missing input JSONL: %s", inJsonl));

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

% File exists (success path)
manifestPath = fullfile(outDir, "run_manifest.json");
testCase.assertTrue(isfile(manifestPath), ...
    sprintf("run_manifest.json was not created: %s", manifestPath));
 
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
        sprintf("manifest.errors.%s is missing (schema not stable)", mustHave(k)));
end
end

function test_manifest_schema_stable_when_sources_write_fails(testCase)
% This test forces sources.csv writing to fail, and checks that
% manifest.errors schema is still stable and contains failure info.

thisFile = mfilename("fullpath");
testsDir = fileparts(thisFile);           % .../<repo>/tests
repoRoot = string(fileparts(testsDir));   % .../<repo>
addpath(genpath(fullfile(repoRoot,"src")));

rawDir  = fullfile(repoRoot, "data_raw");
inJsonl = fullfile(rawDir, "openalex_MATLAB_cursor_en_500.jsonl");
testCase.assertTrue(isfile(inJsonl), sprintf("Missing input JSONL: %s", inJsonl));

stdJsonl = fullfile(rawDir, "openalex_MATLAB_cursor_en_500.standard.jsonl");
doConvert = should_convert_jsonl(inJsonl);
if doConvert
    jsonl_array2standard(inJsonl, stdJsonl, "overwrite", true, "verbose", false);
else
    stdJsonl = inJsonl;
end

% Force failure: make outDir a FILE, not a folder.
runTag = string(datetime("now","TimeZone","Asia/Tokyo","Format","yyyyMMdd_HHmmss"));
brokenOutDir = fullfile(repoRoot, "data_processed", "TEST_BROKEN_" + runTag + "_n10");
if isfolder(brokenOutDir)
    try, rmdir(brokenOutDir, "s"); catch, end
end
mkdir(brokenOutDir);

% Break ONLY sources.csv writing:
% create a folder named "sources.csv" so fopen(<outDir>/sources.csv,"w") fails.
sourcesCsvAsDir = fullfile(brokenOutDir, "sources.csv");
if isfolder(sourcesCsvAsDir)
    try, rmdir(sourcesCsvAsDir, "s"); catch, end
end
mkdir(sourcesCsvAsDir);

manifest = normalize_openalex(stdJsonl, brokenOutDir, ...
    "schemaVersion","v0.2", ...
    "overwrite", true, ...
    "maxRecords", 10, ...
    "verbose", false);

% Even if writing sources.csv fails, manifest must exist in memory and have stable schema.
testCase.verifyTrue(isstruct(manifest), "manifest must be a struct");
testCase.verifyTrue(isfield(manifest, "errors"), "manifest.errors must exist");
testCase.verifyTrue(isstruct(manifest.errors), "manifest.errors must be a struct");

% Required keys for v0.2.2 stability
mustHave = [
    "skipped_missing_required"
    "missing_primary_location_source_count"
    "missing_primary_location_source_id_count"
    "missing_primary_location_source_work_ids"
    "sources_write_failed"
    "sources_write_error_message"
    ];
for k = 1:numel(mustHave)
    testCase.verifyTrue(isfield(manifest.errors, mustHave(k)), ...
        sprintf("manifest.errors.%s is missing (schema not stable on failure)", mustHave(k)));
end

testCase.verifyTrue(logical(manifest.errors.sources_write_failed), ...
    "sources_write_failed must be true when sources.csv writing fails");
testCase.verifyGreaterThan(strlength(string(manifest.errors.sources_write_error_message)), 0, ...
    "sources_write_error_message must be non-empty when sources.csv writing fails");
% Type checks (v0.2.2 contract)
testCase.verifyTrue(islogical(manifest.errors.sources_write_failed) ...
    && isscalar(manifest.errors.sources_write_failed), ...
    "sources_write_failed must be logical scalar");

testCase.verifyTrue(ischar(manifest.errors.sources_write_error_message) ...
    || isstring(manifest.errors.sources_write_error_message), ...
    "sources_write_error_message must be string or char");

testCase.verifyTrue(isnumeric(manifest.errors.missing_primary_location_source_count) ...
    && isscalar(manifest.errors.missing_primary_location_source_count), ...
    "missing_primary_location_source_count must be numeric scalar");
end

% ---- helpers copied/adapted from example_v0_2_500 (keep local for tests) ----
function tf = should_convert_jsonl(jsonlPath)
fid = fopen(jsonlPath,"r");
assert(fid>0, "Failed to open: %s", jsonlPath);
c = onCleanup(@() fclose(fid)); 
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
