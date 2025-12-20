function tests = test_sources_writer_smoke
tests = functiontests(localfunctions);
end

function test_write_sources_csv_handles_tricky_strings(testCase)
thisFile = mfilename("fullpath");
testsDir = fileparts(thisFile);           % .../<repo>/tests
repoRoot = string(fileparts(testsDir));   % .../<repo>
addpath(genpath(fullfile(repoRoot,"src")));

% Prepare outDir
runTag = string(datetime("now","TimeZone","Asia/Tokyo","Format","yyyyMMdd_HHmmss"));
outDir = fullfile(repoRoot, "data_processed", "TESTSRC_" + runTag);
if ~isfolder(outDir), mkdir(outDir); end

% Build a sourcesMap similar to normalize_openalex(update_sources_map)
mp = containers.Map("KeyType","char","ValueType","any");

rec1 = struct();
rec1.source_id = "https://openalex.org/S123";
rec1.source_display_name = "Journal, ""Alpha""" + newline + "Line2";
rec1.source_type = "journal";
rec1.issn_l = "1234-5678";
rec1.is_oa = true;
rec1.host_organization_id = "https://openalex.org/I999";
rec1.works_count_seen = 2;
mp(char(rec1.source_id)) = rec1;

rec2 = struct();
rec2.source_id = "https://openalex.org/S456";
rec2.source_display_name = "";   % empty is allowed
rec2.source_type = "";
rec2.issn_l = "";
rec2.is_oa = [];                 % empty logical allowed
rec2.host_organization_id = "";
rec2.works_count_seen = 0;
mp(char(rec2.source_id)) = rec2;

% Call writer
stats = schema.v0_2.write_sources_csv(outDir, mp);

% Assert stats shape (loose)
testCase.verifyTrue(isstruct(stats), "write_sources_csv must return a struct");
testCase.verifyTrue(isfield(stats,"written_sources"));
testCase.verifyTrue(isfield(stats,"unique_sources"));

% Output file must exist
p = fullfile(outDir, "sources.csv");
testCase.assertTrue(isfile(p), "sources.csv not created");

% Basic CSV sanity: first line must contain source_id
fid = fopen(p,"r"); testCase.assertTrue(fid>0);
c = onCleanup(@() fclose(fid)); 
hdr = string(fgetl(fid));
testCase.verifyTrue(contains(hdr, "source_id"), "sources.csv header missing source_id");
testCase.verifyTrue(contains(hdr, "works_count_seen"), "sources.csv header missing works_count_seen");
end

function test_write_sources_csv_tolerates_missing_fields_and_weird_types(testCase)
% This test enforces defensive CSV writing behavior.
% If this fails, write_sources_csv needs hardening for v0.2.2.

thisFile = mfilename("fullpath");
testsDir = fileparts(thisFile);
repoRoot = string(fileparts(testsDir));
addpath(genpath(fullfile(repoRoot,"src")));

runTag = string(datetime("now","TimeZone","Asia/Tokyo","Format","yyyyMMdd_HHmmss"));
outDir = fullfile(repoRoot, "data_processed", "TESTSRC_WEIRD_" + runTag);
if ~isfolder(outDir), mkdir(outDir); end

mp = containers.Map("KeyType","char","ValueType","any");

% Record with missing fields
recA = struct();
recA.source_id = "https://openalex.org/SAAA";
recA.source_display_name = missing;      
recA.works_count_seen = 1;
mp(char(recA.source_id)) = recA;

% Record with weird field types
recB = struct();
recB.source_id = "https://openalex.org/SBBB";
recB.source_display_name = ["a","b"];    % string array (non-scalar)
recB.is_oa = "true";                     % wrong type (string)
recB.works_count_seen = "2";             % wrong type (string)
mp(char(recB.source_id)) = recB;

% Completely unexpected payload (non-struct)
mp("https://openalex.org/SCCC") = 12345;

stats = schema.v0_2.write_sources_csv(outDir, mp);
testCase.verifyTrue(isstruct(stats), "write_sources_csv must return a struct");

% Defensive behavior: non-struct entry should not kill valid ones
testCase.verifyGreaterThanOrEqual(stats.written_sources, 2, ...
    "write_sources_csv should write valid struct records even if map contains junk");

p = fullfile(outDir, "sources.csv");
testCase.assertTrue(isfile(p), "sources.csv not created for weird inputs");

fid = fopen(p,"r"); testCase.assertTrue(fid>0);
c = onCleanup(@() fclose(fid));
hdr = string(fgetl(fid));
testCase.verifyTrue(contains(hdr, "source_id"), "sources.csv header missing source_id");
end