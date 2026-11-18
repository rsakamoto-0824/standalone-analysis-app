function result = build_windows(edition)
if nargin < 1, edition = 'standard'; end
if ~any(strcmp(edition, {'standard', 'pro'})), error('build_windows:edition', 'standard または pro を指定してください。'); end
project_root = setup_paths();
require_r2025b();
if ~ispc || ~strcmp(computer('arch'), 'win64')
    error('build_windows:wrongPlatform', 'Windows 64bit の MATLAB R2025b で実行してください。');
end
if ~license('test', 'Compiler') || ~license('test', 'Statistics_Toolbox')
    error('build_windows:missingToolbox', 'MATLAB Compiler と Statistics and Machine Learning Toolbox が必要です。');
end
% 入口は app/launch_analysis_app.m。App Designer の AnalysisApp.mlapp を作成済みなら、そちらを優先する。
ENTRY_MLAPP = 'AnalysisApp.mlapp'; ENTRY_FUNCTION = 'launch_analysis_app.m';
entry_name = ENTRY_FUNCTION;
if isfile(fullfile(project_root, 'app', ENTRY_MLAPP)), entry_name = ENTRY_MLAPP; end
run_tests();
output = fullfile(project_root, 'build', 'windows', edition);
staging = tempname; manifest = prepare_edition_build(project_root, edition, staging);
old_folder = pwd; old_path = path;
cleanup = onCleanup(@() restoreBuild(old_folder, old_path, staging));
rmpath(fullfile(project_root, 'app'), fullfile(project_root, 'core'));
cd(staging); addpath(fullfile(staging, 'core'), fullfile(staging, 'app'), '-begin');
clear app_edition plot_shap_figures;
executable = 'ProcessInsightTool';
if strcmp(edition, 'pro'), executable = [executable 'Pro']; end
sample_folder=fullfile(staging,'samples'); mkdir(sample_folder);
sample_files={'ProcessInsight_Samples.xlsx','README.md','sample_wordcloud.txt'};
for index=1:numel(sample_files)
    copyfile(fullfile(project_root,'samples',sample_files{index}),sample_folder);
end
additional = {fullfile(staging, 'core'), fullfile(staging, 'app'), fullfile(project_root, 'docs'), sample_folder, ...
    fullfile(project_root, 'README.md'), fullfile(project_root, 'verification.md'), fullfile(project_root, 'issues.md')};
result = compiler.build.standaloneWindowsApplication(fullfile(staging, 'app', entry_name), ...
    'ExecutableName', executable, 'OutputDir', output, 'AdditionalFiles', additional, 'Verbose', 'on');
% 利用者がすぐ使えるよう、サンプルと手順書（HTML）を exe と同じフォルダへ置く。手順書の生成用ファイルは除く。
copyfile(sample_folder, fullfile(output, 'samples'));
guide_output = fullfile(output, 'docs', 'user-guide'); mkdir(guide_output);
copyfile(fullfile(project_root, 'docs', 'user-guide'), guide_output);
if isfolder(fullfile(guide_output, '_src')), rmdir(fullfile(guide_output, '_src'), 's'); end
file = fopen(fullfile(output, 'edition-manifest.json'), 'w', 'n', 'UTF-8');
if file < 0, error('build_windows:manifest', '版の確認ファイルを保存できません。'); end
file_cleanup = onCleanup(@() fclose(file)); fprintf(file, '%s', jsonencode(manifest, 'PrettyPrint', true));
end

function restoreBuild(folder, previous_path, staging)
cd(folder); path(previous_path); clear app_edition plot_shap_figures;
if isfolder(staging), rmdir(staging, 's'); end
end
