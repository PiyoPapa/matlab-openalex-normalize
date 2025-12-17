%% example_v0_1_500.m
% End-to-end example + QA for schema v0.1
% - Convert array-per-line JSONL -> standard JSONL (1 Work per line)
% - Normalize to v0.1 CSVs
% - Run QA checks:
%   works: required fields, fill-rate, OA consistency
%   authorships: orphan rows, fill-rate, multi-institution loss estimate (first institution only)
%   concepts: quick sanity
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

%% Step 3) Normalize (v0.1)
fprintf("\n=== Step 3: normalize_openalex (v0.1) ===\n");

% Derive output folder name from written record count if available
if exist("convSummary","var") && isfield(convSummary,"records_written")
    outDir = fullfile(outBase, runTag + "_n" + string(maxRecords));
else
    outDir = fullfile(outBase, runTag + "_nUNK");
end

manifest = normalize_openalex(stdJsonl, outDir, ...
    "schemaVersion","v0.1", ...
    "overwrite", overwriteOutputs, ...
    "maxRecords", maxRecords, ...
    "verbose", verbose);

disp(manifest);

%% Step 4) Existence check (v0.1)
fprintf("\n=== Step 4: output existence check ===\n");
expected = ["works.csv","authorships.csv","concepts.csv","run_manifest.json","normalize.log.txt"];
for f = expected
    p = fullfile(outDir, f);
    fprintf("  %-18s : %s\n", f, ternary(isfile(p), "OK", "MISSING"));
end
assert(isfile(fullfile(outDir,"works.csv")), "works.csv missing. Stop.");

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

fprintf("\nDONE. Output folder:\n%s\n", outDir);

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