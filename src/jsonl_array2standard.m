function summary = jsonl_array2standard(inJsonl, outJsonl, options)
%JSONL_ARRAY2STANDARD Convert array-per-line JSONL to standard JSONL (1 record per line).
%
% inJsonl  : input JSONL where each line is a JSON array of Works
% outJsonl : output standard JSONL where each line is a JSON object (Work)
%
% Options:
%   overwrite : overwrite outJsonl if exists
%   verbose   : print progress
%   maxLines  : process at most N input lines (debug)
%
% Output:
%   summary : struct with conversion stats

arguments
    inJsonl (1,1) string
    outJsonl (1,1) string
    options.overwrite (1,1) logical = false
    options.verbose (1,1) logical = true
    options.maxLines (1,1) double = inf
end

assert(isfile(inJsonl), "Input not found: %s", inJsonl);

if isfile(outJsonl) && ~options.overwrite
    error("Output already exists: %s (set overwrite=true to proceed)", outJsonl);
end

% Ensure parent folder exists
outParent = fileparts(outJsonl);
if outParent ~= "" && ~isfolder(outParent)
    mkdir(outParent);
end

fidIn = fopen(inJsonl, "r");
if fidIn < 0, error("Failed to open input: %s", inJsonl); end

fidOut = fopen(outJsonl, "w");
if fidOut < 0
    fclose(fidIn);
    error("Failed to open output: %s", outJsonl);
end

c = onCleanup(@() cleanup(fidIn, fidOut));

lineNo = 0;
linesRead = 0;
arraysRead = 0;
recordsWritten = 0;
emptyLines = 0;

tStart = tic;

while true
    line = fgetl(fidIn);
    if ~ischar(line), break; end
    lineNo = lineNo + 1;

    if linesRead >= options.maxLines
        break
    end

    s = strtrim(string(line));
    if s == ""
        emptyLines = emptyLines + 1;
        continue
    end

    linesRead = linesRead + 1;

    % Parse: expecting JSON array
    try
        arr = jsondecode(s);
    catch ME
        error("JSON parse failed at input line %d: %s", lineNo, ME.message);
    end

    arraysRead = arraysRead + 1;

    % Validate it's an array / struct array
    if isempty(arr)
        continue
    end

    if ~isstruct(arr)
        error("Expected a JSON array of objects at line %d, but got type: %s", lineNo, class(arr));
    end

    % Write each element as one JSON object per line
    for i = 1:numel(arr)
        obj = arr(i);

        % jsonencode produces a JSON object string for a struct scalar
        try
            txt = jsonencode(obj);
        catch ME
            error("jsonencode failed at input line %d, element %d: %s", lineNo, i, ME.message);
        end

        fwrite(fidOut, txt);
        fwrite(fidOut, newline);
        recordsWritten = recordsWritten + 1;
    end

    if options.verbose && mod(recordsWritten, 10000) == 0
        fprintf("lines=%d arrays=%d records=%d elapsed=%.1fs\n", ...
            linesRead, arraysRead, recordsWritten, toc(tStart));
    end
end

summary = struct();
summary.input_path = char(inJsonl);
summary.output_path = char(outJsonl);
summary.timestamp = char(datetime("now","TimeZone","Asia/Tokyo","Format","yyyy-MM-dd'T'HH:mm:ssXXX"));
summary.lines_read = linesRead;
summary.arrays_read = arraysRead;
summary.records_written = recordsWritten;
summary.empty_lines = emptyLines;

if options.verbose
    fprintf("DONE: wrote %d records to %s\n", recordsWritten, outJsonl);
end

end

function cleanup(fidIn, fidOut)
safe_fclose(fidIn);
safe_fclose(fidOut);
end

function safe_fclose(fid)
if isnumeric(fid) && fid > 0
    fclose(fid);
end
end
