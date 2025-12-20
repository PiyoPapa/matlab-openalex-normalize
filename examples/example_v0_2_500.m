%% example_v0_2_500.m
% End-to-end example + QA for schema v0.2
% - Convert array-per-line JSONL -> standard JSONL (1 Work per line)
% - Normalize to v0.2 CSVs (v0.1 + sources.csv)
% - Run QA checks:
%   works: required fields, fill-rate, OA consistency
%   authorships: orphan rows, fill-rate, multi-institution loss estimate (first institution only)
%   institutions (v0.2 optional): existence, orphan rows, required columns
%   concepts: quick sanity
%   sources (v0.2): existence, counts, missing primary_location.source rate (manifest)
%   counts_by_year (v0.2 optional): existence, sum check vs works.csv
%
% Assumptions:
%   - Current folder = repo root (matlab-openalex-normalize)
%   - Input files in ./data_raw/
%       openalex_MATLAB_cursor_en_500.jsonl   (array-per-line JSONL)

close all; clear; clc;

%% Step 0) Paths & inputs
repoRoot = string(pwd);

% Add repo paths
addpath(genpath(fullfile(repoRoot,"src")));
addpath(genpath(fullfile(repoRoot,"examples")));

rawDir = fullfile(repoRoot, "data_raw");
inJsonl = fullfile(rawDir, "openalex_MATLAB_cursor_en_500.jsonl");
assert(isfile(inJsonl), "Missing input JSONL: %s", inJsonl);

stdJsonl = fullfile(rawDir, "openalex_MATLAB_cursor_en_500.standard.jsonl");

% Output run folder
runTag = string(datetime("now","TimeZone","Asia/Tokyo","Format","yyyyMMdd_HHmmss"));
outBase = fullfile(repoRoot, "data_processed");

% Normalize options
maxRecords = 500;          % as your test target
overwriteOutputs = true;   % safe for examples
verbose = true;

%% Step 1) Convert to standard JSONL (if needed)
% If your input is already standard JSONL, this will fail (because it expects arrays).
% In that case, skip conversion and set stdJsonl = inJsonl.

doConvert = should_convert_jsonl(inJsonl);
if doConvert
    fprintf("\n=== Step 1: jsonl_array2standard ===\n");
    convSummary = jsonl_array2standard(inJsonl, stdJsonl, ...
        "overwrite", true, ...
        "verbose", verbose);
    disp(convSummary);
else
    stdJsonl = inJsonl;
end

%% Step 2) Quick decode check (standard JSONL must be 1 JSON object per line)
fprintf("\n=== Step 2: decode sanity check ===\n");
preview_first_n_ids(stdJsonl, 3);

%% Step 3) Normalize (v0.2)
fprintf("\n=== Step 3: normalize_openalex (v0.2) ===\n");

% Derive output folder name from written record count if available
if exist("convSummary","var") && isfield(convSummary,"records_written")
    outDir = fullfile(outBase, runTag + "_n" + string(maxRecords));
else
    outDir = fullfile(outBase, runTag + "_nUNK");
end

manifest = normalize_openalex(stdJsonl, outDir, ...
    "schemaVersion","v0.2", ...
    "overwrite", overwriteOutputs, ...
    "maxRecords", maxRecords, ...
    "verbose", verbose);

disp(manifest);

%% Step 4) Existence check (v0.2)
fprintf("\n=== Step 4: output existence check ===\n");
expected = ["works.csv","authorships.csv","concepts.csv","sources.csv","run_manifest.json","normalize.log.txt"];
for f = expected
    p = fullfile(outDir, f);
    fprintf("  %-18s : %s\n", f, ternary(isfile(p), "OK", "MISSING"));
end
assert(isfile(fullfile(outDir,"works.csv")), "works.csv missing. Stop.");
% Optional outputs (v0.2 safe additions)
opt = ["institutions.csv","counts_by_year.csv"];
for f = opt
    p = fullfile(outDir, f);
    fprintf("  %-18s : %s (optional)\n", f, ternary(isfile(p), "OK", "MISSING"));
end

%% Step 5) QA: works.csv (required, fill-rate, OA consistency)
fprintf("\n=== Step 5: QA works.csv ===\n");
T = readtable(fullfile(outDir,"works.csv"), "TextType","string");

% Required fields per v0.1 contract
reqMissing = [sum(T.work_id==""), sum(isnan(T.publication_year)), sum(isnan(T.cited_by_count))];
disp("works required missing [work_id, publication_year, cited_by_count] = ");
disp(reqMissing);
assert(all(reqMissing==0), "Required fields missing in works.csv");

% Fill-rate by column (type safe)
R = fillrate_table(T);
disp("Top missing-rate columns in works.csv:");
disp(R(1:min(12,height(R)),:));

% OA consistency check (robust to type)
[oaCounts, oaBads] = qa_open_access(T);
disp("OA counts:");
disp(oaCounts);
disp("OA inconsistencies:");
disp(oaBads);

%% Step 6) QA: authorships.csv (orphans, fill-rate, multi-institution loss)
fprintf("\n=== Step 6: QA authorships.csv ===\n");
A = readtable(fullfile(outDir,"authorships.csv"), "TextType","string");

% Orphan rows: authorships.work_id must exist in works.work_id
orphans = sum(~ismember(A.work_id, unique(T.work_id)));
fprintf("authorships orphan rows = %d\n", orphans);

AR = fillrate_table(A);
disp("Top missing-rate columns in authorships.csv:");
disp(AR(1:min(12,height(AR)),:));

% Multi-institution loss estimate (from JSONL)
% This quantifies how often institutions has 2+ entries; if high, "first institution" is lossy.
loss = estimate_multi_institution_rate(stdJsonl, maxRecords);
disp("Multi-institution stats (from JSONL):");
disp(loss);
if loss.nAuth_withInst > 0
    fprintf("multiInst rate among withInst = %.4f\n", loss.nAuth_multiInst / loss.nAuth_withInst);
end

%% Step 6b) QA: institutions.csv (v0.2 optional)
fprintf("\n=== Step 6b: QA institutions.csv (v0.2 optional) ===\n");
instPath = fullfile(outDir, "institutions.csv");
if isfile(instPath)
    I = readtable(instPath, "TextType","string");
    fprintf("institutions rows = %d\n", height(I));

    % Required columns (as writer header)
    reqCols = ["work_id","author_id","institution_id","institution_display_name","country_code","ror"];
    missCols = reqCols(~ismember(reqCols, string(I.Properties.VariableNames)));
    if ~isempty(missCols)
        error("institutions.csv missing required columns: %s", strjoin(missCols, ", "));
    end

    % Required fields should not be empty
    missReq = [sum(I.work_id==""), sum(I.author_id==""), sum(I.institution_id=="")];
    disp("institutions required missing [work_id, author_id, institution_id] = ");
    disp(missReq);
    assert(all(missReq==0), "Required fields missing in institutions.csv");

    % Orphan works: institutions.work_id must exist in works.work_id
    instOrphans = sum(~ismember(I.work_id, unique(T.work_id)));
    fprintf("institutions orphan work_id rows = %d\n", instOrphans);
    assert(instOrphans==0, "institutions.csv contains orphan work_id rows");
else
    % If missing, explain using manifest (optional writer should record errors)
    if isstruct(manifest) && isfield(manifest,"errors") ...
            && isfield(manifest.errors,"institutions_write_failed") ...
            && manifest.errors.institutions_write_failed
        msg = "";
        if isfield(manifest.errors,"institutions_write_error_message")
            msg = string(manifest.errors.institutions_write_error_message);
        end
        fprintf("institutions.csv is missing because writer failed. error_message=%s\n", msg);
    else
        fprintf("institutions.csv is missing (optional). No writer failure recorded in manifest.\n");
    end
end

%% Step 7) QA: concepts.csv (quick sanity)
fprintf("\n=== Step 7: QA concepts.csv ===\n");

C = readtable(fullfile(outDir,"concepts.csv"), "TextType","string");
fprintf("concepts rows = %d\n", height(C));

% Check that concept_level / concept_score are parseable numbers (not required, but sanity)
try
    lvl = str2double(C.concept_level); 
    scr = str2double(C.concept_score); 
    fprintf("concept_level and concept_score look numeric-like (string->double ok)\n");
catch
    fprintf("WARN: concept_level / concept_score numeric parsing failed; inspect CSV writing.\n");
end
%% Step 7b) QA: counts_by_year.csv (v0.2 optional)
fprintf("\n=== Step 7b: QA counts_by_year.csv (v0.2 optional) ===\n");
cbyPath = fullfile(outDir, "counts_by_year.csv");
if isfile(cbyPath)
    Y = readtable(cbyPath, "TextType","string");
    fprintf("counts_by_year rows (unique years) = %d\n", height(Y));

    reqCols = ["publication_year","works_count"];
    missCols = reqCols(~ismember(reqCols, string(Y.Properties.VariableNames)));
    if ~isempty(missCols)
        error("counts_by_year.csv missing required columns: %s", strjoin(missCols, ", "));
    end

    % Basic numeric-like checks
    try
        yrs = str2double(string(Y.publication_year));
        cnt = str2double(string(Y.works_count));
        assert(all(isfinite(yrs)), "publication_year contains non-numeric values");
        assert(all(isfinite(cnt)), "works_count contains non-numeric values");
        fprintf("counts_by_year parse ok. min_year=%g max_year=%g total=%g\n", min(yrs), max(yrs), sum(cnt));
    catch ME
        error("counts_by_year numeric parsing failed: %s", ME.message);
    end

    % Sum check vs works.csv
    total = sum(str2double(string(Y.works_count)));
    fprintf("sum(counts_by_year.works_count) = %d, height(works) = %d\n", total, height(T));
    assert(total == height(T), "counts_by_year total does not match works.csv row count");
else
    if isstruct(manifest) && isfield(manifest,"errors") ...
            && isfield(manifest.errors,"counts_by_year_write_failed") ...
            && manifest.errors.counts_by_year_write_failed
        msg = "";
        if isfield(manifest.errors,"counts_by_year_write_error_message")
            msg = string(manifest.errors.counts_by_year_write_error_message);
        end
        fprintf("counts_by_year.csv is missing because writer failed. error_message=%s\n", msg);
    else
        fprintf("counts_by_year.csv is missing (optional). No writer failure recorded in manifest.\n");
    end
end
%% Step 8) QA: sources.csv (v0.2)
fprintf("\n=== Step 8: QA sources.csv (v0.2) ===\n");
S = readtable(fullfile(outDir,"sources.csv"), "TextType","string");
fprintf("sources rows (unique sources) = %d\n", height(S));

% Basic sanity: primary key uniqueness
dup = height(S) - numel(unique(S.source_id));
fprintf("duplicate source_id rows = %d\n", dup);
assert(dup==0, "Duplicate source_id detected in sources.csv");

% Works_count_seen should be numeric-like (string->double ok)
try
    seen = str2double(string(S.works_count_seen));
    fprintf("works_count_seen parse ok. min=%g max=%g sum=%g\n", min(seen), max(seen), sum(seen));
catch
    fprintf("WARN: works_count_seen numeric parsing failed; inspect CSV writing.\n");
end

% Manifest: missing primary_location.source (count + optional work_ids)
missSrc = [];
if isstruct(manifest) && isfield(manifest,"errors")
    % Prefer README-facing keys, fallback to legacy keys
    if isfield(manifest.errors,"missing_primary_location_source_count")
        missSrc = manifest.errors.missing_primary_location_source_count;
    elseif isfield(manifest.errors,"missing_primary_location_source")
        missSrc = manifest.errors.missing_primary_location_source;
    end
end

if ~isempty(missSrc)
    fprintf("missing primary_location.source (count) = %d (of maxRecords=%d)\n", missSrc, maxRecords);
else
    fprintf("WARN: manifest.errors.missing_primary_location_source(_count) not found.\n");
end

fprintf("\nDONE. Output folder:\n%s\n", outDir);

% If missing sources exist, prefer manifest-captured work_ids (v0.2.0+)
if ~isempty(missSrc) && missSrc > 0
    ids = strings(0,1);
    if isstruct(manifest) && isfield(manifest,"errors") ...
            && isfield(manifest.errors,"missing_primary_location_source_work_ids")
        ids = string(manifest.errors.missing_primary_location_source_work_ids);
    end

    if numel(ids) > 0
        fprintf("Missing primary_location.source work_ids (from manifest, n=%d):\n", numel(ids));
        disp(ids);
    else
        % Fallback for older manifests: enumerate from JSONL
        ids = find_missing_primary_location_source_ids(stdJsonl, maxRecords);
        fprintf("Missing primary_location.source work_ids (from JSONL fallback, n=%d):\n", numel(ids));
        disp(ids);
    end
end
%% ===================== Local helpers =====================

function preview_first_n_ids(stdJsonl, n)
fid = fopen(stdJsonl, "r");
assert(fid > 0, "Failed to open: %s", stdJsonl);
c = onCleanup(@() fclose(fid));

for k = 1:n
    ln = fgetl(fid);
    assert(ischar(ln), "Unexpected EOF while reading %s", stdJsonl);
    w = jsondecode(ln);
    if isfield(w,"id")
        fprintf("  line %d: id=%s\n", k, string(w.id));
    else
        fprintf("  line %d: (no id field)\n", k);
    end
end
end

function out = ternary(cond, a, b)
if cond, out = a; else, out = b; end
end

function R = fillrate_table(T)
vars = T.Properties.VariableNames;
missRate = zeros(numel(vars),1);
cls = strings(numel(vars),1);

for i = 1:numel(vars)
    v = T.(vars{i});
    cls(i) = string(class(v));
    missRate(i) = missing_rate(v);
end

R = table(string(vars(:)), cls, missRate, 'VariableNames', {'var','class','missing_rate'});
R = sortrows(R, 'missing_rate', 'desc');
end

function r = missing_rate(v)
% Robust missing-rate for common MATLAB table column types
if isstring(v)
    r = mean(v=="");
elseif isnumeric(v)
    r = mean(isnan(v));
elseif islogical(v)
    r = 0;
elseif isdatetime(v) || isduration(v) || iscategorical(v)
    r = mean(ismissing(v));
elseif iscell(v)
    r = mean(cellfun(@(x) isempty(x) || (isstring(x)&&x=="") || (ischar(x)&&isempty(x)), v));
else
    try
        r = mean(ismissing(v));
    catch
        r = 0;
    end
end
end

function [counts, bads] = qa_open_access(T)
% Normalize is_oa into numeric vector isOA: 0/1/NaN
if ~ismember("is_oa", T.Properties.VariableNames)
    error("works.csv has no column named is_oa");
end

v = T.is_oa;
if isstring(v)
    isOA = nan(height(T),1);
    isOA(v=="0") = 0;
    isOA(v=="1") = 1;
    isOA(v=="")  = nan;
elseif isnumeric(v)
    isOA = double(v);
else
    vs = string(v);
    isOA = nan(height(T),1);
    isOA(vs=="0") = 0;
    isOA(vs=="1") = 1;
    isOA(vs=="")  = nan;
end

oa_status = T.oa_status;

counts = table(sum(isnan(isOA)), sum(isOA==0), sum(isOA==1), ...
    'VariableNames', {'isOA_empty','isOA_0','isOA_1'});

% Consistency expectations:
% - v0.1 does not include any URL fields (URLs are deferred to v0.2).
% - if isOA==1 => oa_status should usually be present (can be relaxed, but monitor)
bad1 = sum(isOA==1 & oa_status=="");
bads = table(bad1, 'VariableNames', {'bad_isOA1_noStatus'});
end

function loss = estimate_multi_institution_rate(stdJsonl, maxRecords)
fid = fopen(stdJsonl, "r");
assert(fid > 0, "Failed to open: %s", stdJsonl);
c = onCleanup(@() fclose(fid));

nWork = 0;
nAuth = 0;
nAuth_withInst = 0;
nAuth_multiInst = 0;

while true
    ln = fgetl(fid);
    if ~ischar(ln), break; end

    nWork = nWork + 1;
    if nWork > maxRecords
        break
    end

    w = jsondecode(ln);

    if isfield(w,"authorships") && ~isempty(w.authorships)
        au = w.authorships;
        for i = 1:numel(au)
            nAuth = nAuth + 1;
            if isfield(au(i),"institutions") && ~isempty(au(i).institutions)
                nAuth_withInst = nAuth_withInst + 1;
                if numel(au(i).institutions) >= 2
                    nAuth_multiInst = nAuth_multiInst + 1;
                end
            end
        end
    end
end

loss = table(nWork,nAuth,nAuth_withInst,nAuth_multiInst);
end

function tf = should_convert_jsonl(jsonlPath)
% Returns true if the first non-empty line looks like a JSON array ("[ ... ]")
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
function ids = find_missing_primary_location_source_ids(stdJsonl, maxRecords)
fid = fopen(stdJsonl,"r");
assert(fid>0, "Failed to open: %s", stdJsonl);
c = onCleanup(@() fclose(fid));

ids = strings(0,1);
n = 0;

while true
    ln = fgetl(fid);
    if ~ischar(ln), break; end
    s = strtrim(string(ln));
    if s == "", continue; end

    n = n + 1;
    if n > maxRecords, break; end

    w = jsondecode(ln);
    wid = "";
    if isfield(w,"id"), wid = string(w.id); end

    hasSource = false;
    if isfield(w,"primary_location") && ~isempty(w.primary_location) ...
            && isfield(w.primary_location,"source") && ~isempty(w.primary_location.source) ...
            && isfield(w.primary_location.source,"id")
        sid = string(w.primary_location.source.id);
        hasSource = strlength(sid) > 0;
    end

    if ~hasSource && wid ~= ""
        ids(end+1,1) = wid; %#ok<AGROW>
    end
end
end
