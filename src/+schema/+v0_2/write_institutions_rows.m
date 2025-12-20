function nRows = write_institutions_rows(fidInst, workId, authorships)
%WRITE_INSTITUTIONS_ROWS Write institutions.csv rows (FULL expansion).
%
% 1 row per (work_id, author_id, institution_id)
% - workId: string/char OpenAlex work id (e.g., "https://openalex.org/W...")
% - authorships: struct array from OpenAlex Work.authorships
% - fidInst: file id for institutions.csv (already opened, header already written)
%
% Returns:
%   nRows: number of rows written (double)

nRows = 0;

% Basic guards (cheap and non-fatal)
if ~(isnumeric(fidInst) && isscalar(fidInst) && fidInst > 0)
    return
end
% Normalize workId to scalar string to avoid non-scalar logical in guards
workId = string(workId);
if ~(isscalar(workId))
    workId = workId(1);
end
if ismissing(workId) || strlength(workId) == 0
    return
end
if isempty(authorships) || ~isstruct(authorships)
    return
end

for i = 1:numel(authorships)
    a = authorships(i);

    % author id (required for row)
    authorId = "";
    if isfield(a, "author") && isstruct(a.author) && isfield(a.author, "id")
        authorId = string(a.author.id);
    end
    if authorId == ""
        continue
    end

    % institutions array (may be empty)
    instArr = [];
    if isfield(a, "institutions") && ~isempty(a.institutions) && isstruct(a.institutions)
        instArr = a.institutions;
    else
        continue
    end

    for j = 1:numel(instArr)
        inst = instArr(j);

        instId = field_or_empty(inst, "id");
        if instId == ""
            continue
        end

        instName = field_or_empty(inst, "display_name");
        country  = field_or_empty(inst, "country_code");

        % ROR can appear as inst.ror or inst.ids.ror
        ror = "";
        if isfield(inst, "ror") && ~isempty(inst.ror)
            ror = string(inst.ror);
        elseif isfield(inst, "ids") && isstruct(inst.ids) && isfield(inst.ids, "ror") && ~isempty(inst.ids.ror)
            ror = string(inst.ids.ror);
        end

        % CSV (escape minimal; consistent with your existing writers style)
        fprintf(fidInst, "%s,%s,%s,%s,%s,%s\n", ...
            csv_esc(workId), ...
            csv_esc(authorId), ...
            csv_esc(instId), ...
            csv_esc(instName), ...
            csv_esc(country), ...
            csv_esc(ror));

        nRows = nRows + 1;
    end
end

end

% ---- helpers ----
function v = field_or_empty(s, fname)
v = "";
if isstruct(s) && isfield(s, fname) && ~isempty(s.(fname))
    v = string(s.(fname));
end
end

function out = csv_esc(in)
% Escape CSV field for a single column.
% - Convert to string
% - Replace double quotes with doubled quotes
% - Wrap in quotes if contains comma, quote, newline
s = string(in);
% IMPORTANT:
% contains(s, ...) returns a logical array if s is a string array.
% That will break "||" with: "Operands to the || and && operators must be scalar logical".
% Force s to a scalar string.
if ~isscalar(s)
    % Keep deterministic representation; avoid throwing away data silently.
    % Join multiple values with ';' (safe for CSV + still human-readable).
    s = strjoin(s, ";");
end
s = replace(s, """", """""");
if contains(s, ",") || contains(s, """") || contains(s, newline) || contains(s, char(13))
    out = """" + s + """";
else
    out = s;
end
end
