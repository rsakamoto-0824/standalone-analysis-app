function manifest = prepare_edition_build(project_root, edition, staging)
% 配布版のソースを分離し、通常版にはProの評価実装を含めない。
if ~any(strcmp(edition, {'standard', 'pro'})), error('build:edition', 'standard または pro を指定してください。'); end
if isfolder(staging) && numel(dir(staging)) > 2, error('build:staging', '隔離先は空のフォルダを指定してください。'); end
if ~isfolder(staging), mkdir(staging); end
pro_files = {'app/SwingCurveView.m', 'core/fit_swing_curve.m', 'core/fit_swing_spline.m', ...
    'core/swing_curve_values.m', 'core/swing_curve_extrema.m', 'core/swing_spline_extrema.m', 'core/swing_residual_diagnostics.m'};
files = {};
for folder = {'app', 'core'}
    entries = dir(fullfile(project_root, folder{1}, '*'));
    mkdir(fullfile(staging, folder{1}));
    for index = 1:numel(entries)
        if entries(index).isdir, continue; end
        relative = [folder{1} '/' entries(index).name];
        if strcmp(edition, 'standard') && ismember(relative, pro_files), continue; end
        copyfile(fullfile(project_root, relative), fullfile(staging, relative)); files{end+1} = relative; %#ok<AGROW>
    end
end
writeFile(fullfile(staging, 'core', 'app_edition.m'), sprintf('function edition = app_edition()\nedition = ''%s'';\nend\n', edition));
if strcmp(edition, 'standard')
    path = fullfile(staging, 'app', 'plot_shap_figures.m'); source = fileread(path);
    first = strfind(source, '    if strcmp(predictor_names{column}, ''RESIST_TH'') && options.AllowSwingFit');
    last = strfind(source, '    layout = uigridlayout(tab, [1, 1]); ax = uiaxes(layout); charts{position + 1} = ax;');
    if numel(first) ~= 1 || numel(last) ~= 1 || first >= last
        error('build:proIsolation', '通常版のPro実装を分離できません。');
    end
    source = [source(1:first-1), source(last:end)]; writeFile(path, source);
    assert(~contains(source, 'SwingCurveView'), 'build:proIsolation', '通常版にPro画面の呼出しが残っています。');
end
manifest = struct('Edition', edition, 'Files', {sort(files)}, 'ProFiles', {intersect(files, pro_files)});
end

function writeFile(path, text)
file = fopen(path, 'w', 'n', 'UTF-8');
if file < 0, error('build:write', '版の設定ファイルを作成できません。'); end
cleanup = onCleanup(@() fclose(file)); fprintf(file, '%s', text);
end
