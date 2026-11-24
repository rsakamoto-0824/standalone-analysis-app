function result = build_windows(edition, make_installer, sample_folder)
% Windows 用の exe と、MATLAB Runtime を同梱したインストーラーを作る。
%   build_windows('standard')         通常版（配布版）：ProcessInsightTool
%   build_windows('pro')              Pro版：ProcessInsightToolPro
%   build_windows(edition, false)     exe だけを作る（インストーラーを作らない）
%   build_windows(edition, true, folder)  同梱するサンプルを folder から取る（既定は samples\installer\<版>）
% 同梱するサンプルは samples\installer\standard・samples\installer\pro のファイルすべて。置き換えるときはこのフォルダの
% ファイルを差し替える（ブックの名前とシート名の条件は check_installer_samples が確かめる）。
% 通常版には手順書（docs）を入れない。Pro 版には docs\user-guide の手順書を入れる。
% 配布先のクライアント PC には MATLAB がない前提。インストーラーに MATLAB Runtime を同梱するため
% （RuntimeDelivery = "installer"）、クライアント PC はインストーラーを1つ実行するだけで使える。
% 出力：
%   build\windows\<版>\application\   exe と、サンプル・手順書（Runtime を別に入れる場合の配布用）
%   build\windows\<版>\installer\     MATLAB Runtime を同梱したインストーラー（推奨の配布物）
%   build\windows\<版>\edition-manifest.json
if nargin < 1, edition = 'standard'; end
if nargin < 2, make_installer = true; end
if nargin < 3, sample_folder = ''; end
if ~any(strcmp(edition, {'standard', 'pro'})), error('build_windows:edition', 'standard または pro を指定してください。'); end
APP_VERSION = '1.0';
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
if isempty(sample_folder), sample_folder = fullfile(project_root, 'samples', 'installer', edition); end
% ビルド中に作業フォルダを移すため、相対パスで指定されたフォルダは今のフォルダからの絶対パスにする。
if isempty(regexp(sample_folder, '^([A-Za-z]:|[\\/])', 'once')), sample_folder = fullfile(pwd, sample_folder); end
% サンプルはテストより前に確かめる（置き換えたブックの名前やシートの誤りで、長いテストの後に止まらないように）。
samples = check_installer_samples(sample_folder, edition);
run_tests();
output = fullfile(project_root, 'build', 'windows', edition);
application_output = fullfile(output, 'application'); installer_output = fullfile(output, 'installer');
staging = tempname; manifest = prepare_edition_build(project_root, edition, staging);
old_folder = pwd; old_path = path;
cleanup = onCleanup(@() restoreBuild(old_folder, old_path, staging));
rmpath(fullfile(project_root, 'app'), fullfile(project_root, 'core'));
cd(staging); addpath(fullfile(staging, 'core'), fullfile(staging, 'app'), '-begin');
clear app_edition plot_shap_figures;
executable = 'ProcessInsightTool'; application_name = 'Process Insight Tool';
if strcmp(edition, 'pro'), executable = [executable 'Pro']; application_name = [application_name ' Pro']; end

% 利用者に渡すのはサンプルと（Pro 版だけ）手順書（HTML）。動画や開発用の文書は含めない（exe を大きくしないため）。
staged_samples = fullfile(staging, 'samples'); mkdir(staged_samples);
for index = 1:numel(samples.Files)
    copyfile(fullfile(sample_folder, samples.Files{index}), staged_samples);
end
deliverables = {staged_samples};
if strcmp(edition, 'pro')
    docs_folder = fullfile(staging, 'docs'); guide_folder = fullfile(docs_folder, 'user-guide'); mkdir(guide_folder);
    copyfile(fullfile(project_root, 'docs', 'user-guide'), guide_folder);
    if isfolder(fullfile(guide_folder, '_src')), rmdir(fullfile(guide_folder, '_src'), 's'); end
    deliverables{end + 1} = docs_folder;
end

additional = [{fullfile(staging, 'core'), fullfile(staging, 'app')}, deliverables, {fullfile(project_root, 'README.md')}];
result = compiler.build.standaloneWindowsApplication(fullfile(staging, 'app', entry_name), ...
    'ExecutableName', executable, 'OutputDir', application_output, 'AdditionalFiles', additional, 'Verbose', 'on');
% exe と同じフォルダにもサンプル（Pro 版は手順書も）を置く（ZIP で配る場合に、利用者がすぐ開けるように）。
copyfile(staged_samples, fullfile(application_output, 'samples'));
if strcmp(edition, 'pro'), copyfile(docs_folder, fullfile(application_output, 'docs')); end

if make_installer
    % MATLAB Runtime を同梱し、インストール時にインターネットへ接続しない。
    % ビルドする PC に、同じ更新版の MATLAB Runtime インストーラーが必要（compiler.runtime.download で入手）。
    try
        compiler.package.installer(result, ...
            'ApplicationName', application_name, 'InstallerName', [executable '_Installer'], ...
            'RuntimeDelivery', 'installer', 'AdditionalFiles', deliverables, ...
            'Shortcut', fullfile(application_output, [executable '.exe']), ...
            'Version', APP_VERSION, 'Summary', '成膜・露光プロセスのモデリング・補間・実験計画をまとめて扱う解析アプリ', ...
            'OutputDir', installer_output, 'Verbose', 'on');
    catch err
        error('build_windows:installer', ['インストーラーを作れませんでした。exe は %s にできています。\n' ...
            'MATLAB Runtime のインストーラーが必要です。インターネットに接続できる場合は compiler.runtime.download を実行し、' ...
            '接続できない場合は表示された URL から入手して［設定］→［MATLAB Compiler］で場所を指定してから、build_windows をやり直してください。\n詳細: %s'], ...
            application_output, err.message);
    end
end

manifest.Version = APP_VERSION; manifest.Installer = make_installer;
manifest.SampleFolder = sample_folder; manifest.Samples = samples.Files; manifest.SampleSheets = samples.Sheets;
manifest.Docs = strcmp(edition, 'pro');
file = fopen(fullfile(output, 'edition-manifest.json'), 'w', 'n', 'UTF-8');
if file < 0, error('build_windows:manifest', '版の確認ファイルを保存できません。'); end
file_cleanup = onCleanup(@() fclose(file)); fprintf(file, '%s', jsonencode(manifest, 'PrettyPrint', true));
end

function restoreBuild(folder, previous_path, staging)
cd(folder); path(previous_path); clear app_edition plot_shap_figures;
if isfolder(staging), rmdir(staging, 's'); end
end
