function settings = app_settings(action, path, proposed)
constants = model_constants();
defaults = struct('SaveFolder', pwd, 'Theme', 'ライト', ...
    'Kernel', constants.DEFAULT_KERNEL, 'SwingKernel', constants.DEFAULT_KERNEL, 'FitMethod', constants.DEFAULT_FIT_METHOD, ...
    'ShowPlots', true, 'InputCount', 4, 'Bins', 0, 'Factors', 3, 'Runs', 20, 'Seed', 42);
settings = defaults;
if strcmp(action, 'defaults'), return; end
if strcmp(action, 'load')
    if ~isfile(path), return; end
    proposed = jsondecode(fileread(path));
elseif ~strcmp(action, 'save')
    error('settings:action', '設定操作が不正です。');
end
if ~isstruct(proposed) || ~isscalar(proposed), error('settings:invalid', '設定は単一の構造体が必要です。'); end
if ~isfield(proposed, 'SwingKernel') && isfield(proposed, 'Kernel'), settings.SwingKernel = proposed.Kernel; end
fields = fieldnames(defaults);
for index = 1:numel(fields)
    name = fields{index};
    if isfield(proposed, name), settings.(name) = proposed.(name); end
end
if ~(ischar(settings.SaveFolder) || isscalar(string(settings.SaveFolder))) || ~isfolder(settings.SaveFolder)
    error('settings:folder', '保存先フォルダが存在しません。');
end
settings.SaveFolder = char(settings.SaveFolder);
if ~any(strcmp(settings.Theme, {'ライト', 'ダーク'})), error('settings:theme', 'テーマが不正です。'); end
validate_model_parameters(settings.Kernel, settings.FitMethod, 'settings');
validate_model_parameters(settings.SwingKernel, settings.FitMethod, 'settings', true);
validateattributes(settings.ShowPlots, {'logical', 'numeric'}, {'scalar', 'binary'});
settings.ShowPlots = logical(settings.ShowPlots);
validateattributes(settings.InputCount, {'numeric'}, {'scalar', 'integer', '>=', 1, '<=', 100});
validateattributes(settings.Bins, {'numeric'}, {'scalar', 'integer', '>=', 0, '<=', 1000});
if settings.Bins == 1, error('settings:bins', 'ビン数は0（自動）または2以上です。'); end
validateattributes(settings.Factors, {'numeric'}, {'scalar', 'integer', '>=', 1, '<=', 8});
validateattributes(settings.Runs, {'numeric'}, {'scalar', 'integer', '>=', 1, '<=', 300});
validateattributes(settings.Seed, {'numeric'}, {'scalar', 'integer', '>=', 0, '<=', 2^32 - 1});
if strcmp(action, 'save')
    folder = fileparts(path);
    if ~isfolder(folder), mkdir(folder); end
    encoded = jsonencode(settings, 'PrettyPrint', true);
    temporary = [tempname(folder), '.json'];
    cleanup = onCleanup(@() removeTemporary(temporary));
    fid = fopen(temporary, 'w', 'n', 'UTF-8');
    if fid < 0, error('settings:write', '設定ファイルを開けません。'); end
    file_cleanup = onCleanup(@() fclose(fid));
    fprintf(fid, '%s', encoded); clear file_cleanup;
    [success, message] = movefile(temporary, path, 'f');
    if ~success, error('settings:write', '%s', message); end
end
end

function removeTemporary(path)
if isfile(path), delete(path); end
end
