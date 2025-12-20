function results = runtests_local()
%RUNTESTS_LOCAL Run all unit tests in this repo.
here = fileparts(mfilename("fullpath"));
results = runtests(here, "IncludeSubfolders", true);
T = table({results.Name}', [results.Passed]', [results.Failed]', ...
    'VariableNames', {'Name','Passed','Failed'});
disp(T);
assert(all([results.Passed]), "Some tests failed.");
end
