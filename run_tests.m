function results = run_tests()
project_root = setup_paths();
require_r2025b();
check_model_contract();
results = runtests(fullfile(project_root, 'tests'), 'IncludeSubfolders', true);
disp(table(results));
assertSuccess(results);
end
