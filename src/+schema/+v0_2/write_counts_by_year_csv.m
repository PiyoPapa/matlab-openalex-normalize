function stats = write_counts_by_year_csv(outDir, worksCsvPath)
%WRITE_COUNTS_BY_YEAR_CSV Derive counts_by_year.csv from works.csv.
%
% Output:
%   counts_by_year.csv: publication_year,works_count

stats = struct( ...
    "written_rows", 0, ...
    "unique_years", 0, ...
    "total_works_count", 0, ...
    "min_year", NaN, ...
    "max_year", NaN);

if ~(isfolder(outDir) && isfile(worksCsvPath))
    error("write_counts_by_year_csv: invalid input. outDir='%s', worksCsvPath='%s'", outDir, worksCsvPath);
end

opts = detectImportOptions(worksCsvPath, "Delimiter", ",", "Encoding", "UTF-8");

% 重要：列名の揺れに備えて "publication_year" を探す
vn = string(opts.VariableNames);
col = "publication_year";
if ~any(vn == col)
    % ありがちな変形：publication_year_1 など
    hit = vn(startsWith(vn, col));
    if isempty(hit)
        error("write_counts_by_year_csv: 'publication_year' column not found in works.csv. cols=%s", strjoin(vn, ","));
    end
    col = hit(1);
end

opts.SelectedVariableNames = cellstr(col);

T = readtable(worksCsvPath, opts);

% ここが肝：ドット参照をやめて、列名で取り出す
y = T{:, col};

% numeric 化
y = str2double(string(y));
y = double(y);
y = y(isfinite(y) & y > 0);

outPath = fullfile(outDir, "counts_by_year.csv");
fid = fopen(outPath, "w");
if fid <= 0
    error("Failed to open for write: %s", outPath);
end
c = onCleanup(@() fclose(fid));
fprintf(fid, "publication_year,works_count\n");

if isempty(y)
    % header only
    return
end

uy = sort(unique(y));
counts = zeros(size(uy));
for i = 1:numel(uy)
    counts(i) = sum(y == uy(i));
end

for i = 1:numel(uy)
    fprintf(fid, "%d,%d\n", uy(i), counts(i));
end

stats.written_rows = numel(uy);
stats.unique_years = numel(uy);
stats.total_works_count = sum(counts);
stats.min_year = min(uy);
stats.max_year = max(uy);
end
