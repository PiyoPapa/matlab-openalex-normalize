function stats = write_sources_csv(outDir, sourcesMap)
%WRITE_SOURCES_CSV Write v0.2 sources.csv from an aggregated sources map.
%
% sources.csv (v0.2 minimal)
% - 1 row = 1 Source (primary_location.source)
% - Primary key: source_id (OpenAlex URL string)
%
% Columns:
% source_id,source_display_name,source_type,issn_l,is_oa,host_organization_id,works_count_seen
%
% Input:
%   outDir      : run folder
%   sourcesMap  : containers.Map(key=source_id char, value=struct)
%
% Output:
%   stats : struct with counts

arguments
    outDir (1,1) string
    sourcesMap {mustBeA(sourcesMap,"containers.Map")}
end

outPath = fullfile(outDir, "sources.csv");
fid = fopen(outPath, "w");
if fid < 0
    error("Failed to open for write: %s", outPath);
end
cleanupObj = onCleanup(@() fclose(fid));

fprintf(fid, "source_id,source_display_name,source_type,issn_l,is_oa,host_organization_id,works_count_seen\n");

keys = sourcesMap.keys;
% Deterministic output order
keys = sort(string(keys));

written = 0;
for i = 1:numel(keys)
    k = char(keys(i));
    rec = sourcesMap(k);

    fprintf(fid, "%s,%s,%s,%s,%s,%s,%s\n", ...
        csv_escape(rec.source_id), ...
        csv_escape(getfield_or(rec,"source_display_name","")), ...
        csv_escape(getfield_or(rec,"source_type","")), ...
        csv_escape(getfield_or(rec,"issn_l","")), ...
        csv_escape_logical(getfield_or(rec,"is_oa",[])), ...
        csv_escape(getfield_or(rec,"host_organization_id","")), ...
        csv_escape_num(getfield_or(rec,"works_count_seen",0)));

    written = written + 1;
end

stats = struct();
stats.unique_sources = numel(keys);
stats.written_sources = written;
stats.output_path = outPath;
end

% ===== helpers (local) =====
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

function out = csv_escape(x)
    % Convert input to string and escape for CSV
    if isempty(x)
        out = "";
        return;
    end
    % Normalize to string
    if isstring(x)
        out = x;
    elseif ischar(x)
        out = string(x);
    else
        out = string(x);
    end
    % Escape double quotes by doubling them
    out = replace(out, """", """""");
    % Quote field if it contains special chars
    if contains(out, ",") || contains(out, """") || contains(out, newline) || contains(out, char(13))
        out = """" + out + """";
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
    out = char(string(double(x)));
else
    out = char(string(x));
end
end