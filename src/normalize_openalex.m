function manifest = normalize_openalex(inJsonl, outDir, options)
%NORMALIZE_OPENALEX Normalize OpenAlex Works standard JSONL into versioned CSVs.
%
% Input:
%   inJsonl : standard JSONL (1 Work per line)
%   outDir  : output run folder
%
% Options:
%   schemaVersion : "v0.1" (default)
%   verbose       : true/false
%   maxRecords    : positive integer or Inf
%   overwrite     : overwrite outDir if exists
%
% Output:
%   manifest : struct written also as run_manifest.json

arguments
    inJsonl (1,1) string
    outDir  (1,1) string
    options.schemaVersion (1,1) string = "v0.1"
    options.verbose (1,1) logical = true
    options.maxRecords (1,1) double = inf
    options.overwrite (1,1) logical = false
    options.debug (1,1) logical = false
    % v0.2 QA reproducibility: store up to N missing-source work_ids in manifest
    options.maxMissingWorkIds (1,1) double = 1000
end

schemaVersion = options.schemaVersion;
if ~(schemaVersion == "v0.1" || schemaVersion == "v0.2")
    error("Only schemaVersion=v0.1 or v0.2 is supported. Got: %s", schemaVersion);
end

% ---------- Prepare output folder ----------
% Guard: outDir must not be an existing file
if exist(outDir, "file") == 2 && ~isfolder(outDir)
    error("Output path exists as a file (must be a folder): %s", outDir);
end

if isfolder(outDir)
    if ~options.overwrite
        error("Output folder already exists: %s (set overwrite=true to proceed)", outDir);
    end
    % overwrite=true: clear existing files to avoid mixing schemas
    % (some MATLAB/OS combos error when pattern matches nothing)
    % Clean previous CSV files, but DO NOT remove sources.csv if it is a directory.
    % (A directory named "sources.csv" is used by tests to force write failure
    % and should be handled by write_sources_csv via error.)
    sourcesCsvPath = fullfile(outDir, "sources.csv");
    if exist(sourcesCsvPath,"file")==2
        try, delete(sourcesCsvPath); catch, end
    end
    % Delete CSV files only (avoid directories like "sources.csv/")
    try
        csvFiles = dir(fullfile(outDir, "*.csv"));
        for i = 1:numel(csvFiles)
            p = fullfile(csvFiles(i).folder, csvFiles(i).name);
            if ~csvFiles(i).isdir
                delete(p);
            end
        end
    catch
        % best-effort cleanup
    end
    try, delete(fullfile(outDir, "*.json")); catch, end
    try, delete(fullfile(outDir, "*.txt")); catch, end
else
    mkdir(outDir);
end

% ---------- Open input ----------
assert(isfile(inJsonl), "Input JSONL not found: %s", inJsonl);
fidIn = fopen(inJsonl, "r");
if fidIn < 0, error("Failed to open input: %s", inJsonl); end

% ---------- Open outputs (CSV) ----------
worksPath = fullfile(outDir, "works.csv");
authPath  = fullfile(outDir, "authorships.csv");
concPath  = fullfile(outDir, "concepts.csv");

fWorks = fopen(worksPath, "w");
fAuth  = fopen(authPath,  "w");
fConc  = fopen(concPath,  "w");

assert(fWorks > 0, "Failed to open for write: %s", worksPath);
assert(fAuth  > 0, "Failed to open for write: %s", authPath);
assert(fConc  > 0, "Failed to open for write: %s", concPath);

% v0.1: counts_by_year is omitted (often empty in Works payload)
c = onCleanup(@() cleanup_files(fidIn, fWorks, fAuth, fConc));

% Write headers (v0.1 fixed columns per README)
fprintf(fWorks, "work_id,doi,title,publication_year,publication_date,type,language,cited_by_count,is_oa,oa_status\n");
fprintf(fAuth,  "work_id,author_id,author_display_name,author_orcid,author_position,is_corresponding,institution_id,institution_display_name,country_code\n");
fprintf(fConc,  "work_id,concept_id,concept_display_name,concept_level,concept_score\n");
% (no counts_by_year.csv in v0.1)

% ---------- Counters ----------
lineNo = 0;
processed = 0;
writtenWorks = 0;
skippedMissingRequired = 0;

% v0.2: sources aggregation (primary_location.source)
sourcesMap = [];
missingPrimarySource = 0;
missingPrimarySourceId = 0;
missingPrimarySourceWorkIds = strings(0,1);
maxMissingIds = max(0, floor(options.maxMissingWorkIds));
if string(schemaVersion) == "v0.2"
    sourcesMap = containers.Map("KeyType","char","ValueType","any");
end

% If you want small logs, keep them bounded.
logPath = fullfile(outDir, "normalize.log.txt");
fidLog = fopen(logPath, "w");
logCleanup = onCleanup(@() safe_fclose(fidLog));

parseErrorLine = []; %#ok<NASGU>

% ---------- Main streaming loop ----------
tStart = tic;
while true
    line = fgetl(fidIn);
    if ~ischar(line), break; end
    lineNo = lineNo + 1;

    if strlength(strtrim(string(line))) == 0
        continue
    end

    % JSON parse (fail-fast with line number)
    try
        w = jsondecode(line);
    catch ME
        if fidLog > 0
            fprintf(fidLog, "[ERROR] JSON parse failed at line %d: %s\n", lineNo, ME.message);
        end
        error("JSON parse failed at line %d: %s", lineNo, ME.message);
    end

    if processed >= options.maxRecords
        break
    end
    processed = processed + 1;

    % Required fields: id, publication_year, cited_by_count
    workId = safe_get_str(w, "id");
    pubYear = safe_get_num(w, "publication_year");
    citedBy = safe_get_num(w, "cited_by_count");

    if workId == "" || isnan(pubYear) || isnan(citedBy)
        skippedMissingRequired = skippedMissingRequired + 1;
        if fidLog > 0
            fprintf(fidLog, "[SKIP] missing required at line %d: id='%s', publication_year=%s, cited_by_count=%s\n", ...
                lineNo, workId, num2str(pubYear), num2str(citedBy));
        end
        continue
    end

    % ---------- works.csv ----------
    % v0.2: collect sources (primary_location.source)
    if string(schemaVersion) == "v0.2"
        try
            [sourcesMap, hadSource, hadSourceId] = update_sources_map(sourcesMap, w);
            if ~hadSource, missingPrimarySource = missingPrimarySource + 1; end
            if ~hadSourceId, missingPrimarySourceId = missingPrimarySourceId + 1; end
            if ~hadSource
                if maxMissingIds > 0 && numel(missingPrimarySourceWorkIds) < maxMissingIds
                    missingPrimarySourceWorkIds(end+1,1) = string(workId); %#ok<AGROW>
                end
            end
        catch
            % count as missing both (keep running)
            missingPrimarySource = missingPrimarySource + 1;
            missingPrimarySourceId = missingPrimarySourceId + 1;
            if maxMissingIds > 0 && numel(missingPrimarySourceWorkIds) < maxMissingIds
                missingPrimarySourceWorkIds(end+1,1) = string(workId); %#ok<AGROW>
            end
        end
    end
    doi  = safe_get_str(w, "doi");
    ttl  = safe_get_str(w, "title");
    pdat = safe_get_str(w, "publication_date");
    typ  = safe_get_str(w, "type");
    lang = safe_get_str(w, "language");

    [isOA, oaStatus] = parse_open_access(w);

    fprintf(fWorks, "%s,%s,%s,%s,%s,%s,%s,%s,%s,%s\n", ...
        csv_escape(workId), ...
        csv_escape(doi), ...
        csv_escape(ttl), ...
        csv_escape_num(pubYear), ...
        csv_escape(pdat), ...
        csv_escape(typ), ...
        csv_escape(lang), ...
        csv_escape_num(citedBy), ...
        csv_escape_logical(isOA), ...
        csv_escape(oaStatus));

    writtenWorks = writtenWorks + 1;

    % ---------- authorships.csv (optional, zero rows allowed) ----------
    if isfield(w, "authorships") && ~isempty(w.authorships)
        try
            write_authorships_rows(fAuth, workId, w.authorships);
        catch ME
            % Keep running: authorships are not required for v0.1 core.
            if fidLog > 0
                fprintf(fidLog, "[WARN] authorships write failed at line %d: %s\n", lineNo, ME.message);
            end
        end
    end

    % ---------- concepts.csv (optional) ----------
    if isfield(w, "concepts") && ~isempty(w.concepts)
        try
            write_concepts_rows(fConc, workId, w.concepts);
        catch ME
            if fidLog > 0
                fprintf(fidLog, "[WARN] concepts write failed at line %d: %s\n", lineNo, ME.message);
            end
        end
    end

    % ---------- counts_by_year.csv (optional) ----------
    % v0.1: skip counts_by_year

    if options.verbose && mod(writtenWorks, 1000) == 0
        elapsed = toc(tStart);
        fprintf("processed=%d writtenWorks=%d skipped=%d elapsed=%.1fs\n", ...
            processed, writtenWorks, skippedMissingRequired, elapsed);
    end
end

% ---------- Manifest ----------
manifest = struct();
manifest.schema_version = char(schemaVersion);
manifest.timestamp = char(datetime("now", "TimeZone", "Asia/Tokyo", "Format", "yyyy-MM-dd'T'HH:mm:ssXXX"));
manifest.input_path = char(inJsonl);
manifest.output_dir = char(outDir);
manifest.requested_max_records = ifelse(isinf(options.maxRecords), [], options.maxRecords);
manifest.processed_records = processed;
manifest.written_works = writtenWorks;
manifest.tool = "matlab-openalex-normalize";
manifest.matlab_release = version; % e.g., "9.18.0.1234567 (R2025b)"
manifest.git_commit = get_git_commit_safe();
manifest.errors = struct("skipped_missing_required", skippedMissingRequired);

% v0.2: stabilize manifest.errors schema (always present, even if sources write fails)
if string(schemaVersion) == "v0.2"
    manifest.errors.sources_write_failed = false;
    manifest.errors.sources_write_error_message = "";
    manifest.errors.missing_primary_location_source_count = missingPrimarySource;
    manifest.errors.missing_primary_location_source_id_count = missingPrimarySourceId;
    manifest.errors.missing_primary_location_source_work_ids = cellstr(missingPrimarySourceWorkIds);
end

% ---------- v0.2: write sources.csv ----------
if string(schemaVersion) == "v0.2"
    try
        srcStats = schema.v0_2.write_sources_csv(outDir, sourcesMap);
        manifest.written_sources = srcStats.written_sources;
        manifest.unique_sources = srcStats.unique_sources;
        % Backward-compatible keys (kept for older scripts) - consider deprecating in v0.3
        manifest.errors.missing_primary_location_source = missingPrimarySource;
        manifest.errors.missing_primary_location_source_id = missingPrimarySourceId;
    catch ME
        manifest.errors.sources_write_failed = true;
        manifest.errors.sources_write_error_message = string(ME.message);
        % Keep missing_* counts/work_ids already populated above.
    end
end

% Write JSON (pretty if available)
manifestPath = fullfile(outDir, "run_manifest.json");
write_json_pretty(manifestPath, manifest);

% Done
if options.verbose
    fprintf("DONE: %s\n", outDir);
end

end

% ===================== Helpers =====================

function cleanup_files(varargin)
for k = 1:numel(varargin)
    safe_fclose(varargin{k});
end
end

function safe_fclose(fid)
if isnumeric(fid) && fid > 0
    fclose(fid);
end
end

function s = safe_get_str(st, field)
s = "";
if isstruct(st) && isfield(st, field) && ~isempty(st.(field))
    v = st.(field);
    if ischar(v) || isstring(v)
        s = string(v);
    else
        % fallback: stringify
        try, s = string(v); catch, s = ""; end
    end
end
end

function x = safe_get_num(st, field)
x = NaN;
if isstruct(st) && isfield(st, field) && ~isempty(st.(field))
    v = st.(field);
    if isnumeric(v) && isscalar(v)
        x = double(v);
    elseif ischar(v) || isstring(v)
        tmp = str2double(string(v));
        if ~isnan(tmp), x = tmp; end
    end
end
end

function [isOA, oaStatus] = parse_open_access(w)
% Default empty
isOA = [];
oaStatus = "";

if isfield(w, "open_access") && isstruct(w.open_access)
    oa = w.open_access;
    if isfield(oa, "is_oa") && ~isempty(oa.is_oa)
        isOA = logical(oa.is_oa);
    end
    if isfield(oa, "oa_status") && ~isempty(oa.oa_status)
        oaStatus = string(oa.oa_status);
    end
end
end

function write_authorships_rows(fid, workId, authorships)
% authorships is typically a struct array
for i = 1:numel(authorships)
    a = authorships(i);

    authorId = "";
    authorName = "";
    authorOrcid = "";
    authorPos = "";
    isCorr = [];
    instId = "";
    instName = "";
    country = "";

    if isfield(a, "author") && isstruct(a.author)
        authorId = safe_get_str(a.author, "id");
        authorName = safe_get_str(a.author, "display_name");
        authorOrcid = safe_get_str(a.author, "orcid");
    end
    authorPos = safe_get_str(a, "author_position");
    if isfield(a, "is_corresponding") && ~isempty(a.is_corresponding)
        isCorr = logical(a.is_corresponding);
    end

    % institutions: take the first one as v0.1 (simple + stable)
    if isfield(a, "institutions") && ~isempty(a.institutions)
        inst = a.institutions(1);
        if isstruct(inst)
            instId = safe_get_str(inst, "id");
            instName = safe_get_str(inst, "display_name");
            country = safe_get_str(inst, "country_code");
        end
    end

    fprintf(fid, "%s,%s,%s,%s,%s,%s,%s,%s,%s\n", ...
        csv_escape(workId), ...
        csv_escape(authorId), ...
        csv_escape(authorName), ...
        csv_escape(authorOrcid), ...
        csv_escape(authorPos), ...
        csv_escape_logical(isCorr), ...
        csv_escape(instId), ...
        csv_escape(instName), ...
        csv_escape(country));
end
end

function write_concepts_rows(fid, workId, concepts)
% concepts is typically a struct array
for i = 1:numel(concepts)
    c = concepts(i);
    cid = safe_get_str(c, "id");
    cname = safe_get_str(c, "display_name");
    clevel = safe_get_num(c, "level");
    cscore = safe_get_num(c, "score");

    fprintf(fid, "%s,%s,%s,%s,%s\n", ...
        csv_escape(workId), ...
        csv_escape(cid), ...
        csv_escape(cname), ...
        csv_escape_num(clevel), ...
        csv_escape_num(cscore));
end
end

function write_counts_by_year_rows(fid, workId, countsByYear)
% counts_by_year is typically a struct array with fields year / cited_by_count
for i = 1:numel(countsByYear)
    r = countsByYear(i);
    y = safe_get_num(r, "year");
    c = safe_get_num(r, "cited_by_count");
    if isnan(y)
        continue
    end
    fprintf(fid, "%s,%s,%s\n", csv_escape(workId), csv_escape_num(y), csv_escape_num(c));
end
end

function out = csv_escape(s)
% Return CSV-safe string without surrounding quotes unless needed.
s = string(s);
if s == ""
    out = "";
    return
end
s = replace(s, """", """"""); % escape quotes

% NOTE: Some MATLAB versions require pattern or string array (cellstr may error).
% Also ensure robustness across string scalar inputs.
patterns = [",", """", newline, string(char(13))];
needsQuote = any(contains(s, patterns));

if needsQuote
    out = """" + s + """";
else
    out = s;
end
out = char(out);
end

function out = csv_escape_num(x)
if isempty(x) || (isnumeric(x) && isnan(x))
    out = "";
else
    out = char(string(x));
end
end

function out = csv_escape_logical(x)
if isempty(x)
    out = "";
elseif islogical(x)
    out = char(string(double(x))); % 0/1
else
    out = char(string(x));
end
end

function s = get_git_commit_safe()
s = "unknown";
try
    [status, out] = system("git rev-parse --short HEAD");
    if status == 0
        s = strtrim(string(out));
    end
catch
end
s = char(s);
end

function write_json_pretty(path, st)
% Prefer pretty output when possible; fallback to compact jsonencode.
try
    txt = jsonencode(st, "PrettyPrint", true);
catch
    txt = jsonencode(st);
end
fid = fopen(path, "w");
if fid < 0, error("Failed to write manifest: %s", path); end
fwrite(fid, txt);
fwrite(fid, newline);
fclose(fid);
end

function y = ifelse(cond, a, b)
if cond, y = a; else, y = b; end
end

% ===================== v0.2: sources helpers =====================
function [mp, hadSource, hadSourceId] = update_sources_map(mp, w)
% Aggregate primary_location.source by source_id (OpenAlex URL).
hadSource = false;
hadSourceId = false;

if ~isstruct(w) || ~isfield(w,"primary_location") || ~isstruct(w.primary_location)
    return
end

pl = w.primary_location;
if ~isfield(pl,"source")
    return
end

s = pl.source;
% normalize possible container types
if iscell(s), s = s{1}; end
if isstruct(s) && numel(s) >= 1, s = s(1); end

% Decide whether "source exists"
if ~isstruct(s) || isempty(fieldnames(s))
    return
end
hadSource = true;

if ~isfield(s,"id") || isempty(s.id)
    return
end
hadSourceId = true;

sid = string(s.id);
key = char(sid);

if isKey(mp, key)
    rec = mp(key);
    rec.works_count_seen = rec.works_count_seen + 1;
else
    rec = struct();
    rec.source_id = sid;
    rec.source_display_name = getfield_or(s,"display_name","");
    rec.source_type = getfield_or(s,"type","");
    rec.issn_l = getfield_or(s,"issn_l","");
    rec.is_oa = getfield_or(s,"is_oa",[]);
    rec.host_organization_id = getfield_or(s,"host_organization","");
    rec.works_count_seen = 1;
end

mp(key) = rec;
end

function v = getfield_or(st, f, default)
if ~isstruct(st) || ~isfield(st,f)
    v = default; return
end
v0 = st.(f);
if isempty(v0)
    v = default;
else
    v = v0;
end
end