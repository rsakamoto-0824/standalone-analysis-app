function [app, cleanup, folder] = create_display_preview(edition)
if nargin < 1, edition = 'standard'; end
% 表示専用の一時コピー。GP学習・モデル保存・SHAP計算をここから呼ばない。
% R2022b でも UI 部分だけ補助確認するため、製品のリリース制約は変更しない。
root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(root, 'core'), fullfile(root, 'app'));
folder = tempname; mkdir(folder);
[~, token] = fileparts(folder); class_name = ['DisplayPreview_' regexprep(token, '[^A-Za-z0-9_]', '_')];
source = fileread(fullfile(root, 'app', 'AnalysisController.m'));
assert(count(string(source), 'require_r2025b();') == 1);
source = strrep(source, 'classdef AnalysisController < handle', ['classdef ' class_name ' < handle']);
source = strrep(source, 'function app = AnalysisController(window, edition)', ['function app = ' class_name '(window, edition)']);
source = strrep(source, 'require_r2025b();', '% 表示専用コピー。GP学習・モデル保存・SHAP計算は禁止。');
source = strrep(source, 'methods (Access = private)', 'methods');
source = strrep(source, 'properties (Access = private)', 'properties');
source = strrep(source, 'properties (SetAccess = private)', 'properties');
source = strrep(source, 'Process Insight Tool', 'Process Insight Tool / 表示専用 / R2022b / GP未学習');
source = strrep(source, "app.SettingsPath = fullfile(prefdir, 'StandaloneAnalysisApp', 'settings.json');", ...
    "app.SettingsPath = '" + strrep(fullfile(folder, 'settings.json'), "'", "''") + "';");
source = strrep(source, "project_root = fileparts(fileparts(mfilename('fullpath')));", ...
    "project_root = '" + strrep(root, "'", "''") + "';");
fid = fopen(fullfile(folder, [class_name '.m']), 'w', 'n', 'UTF-8'); fprintf(fid, '%s', source); fclose(fid);
addpath(folder); window = uifigure('Visible', 'off');
cleanup = onCleanup(@() removePreview(window, folder));
% 毎回別名の表示クラスでキャッシュの混在を防ぐ。
app = feval(class_name, window, edition); %#ok<FVAL>
window.Visible = 'on';
end
function removePreview(window, folder)
if isgraphics(window), delete(window); end
rmpath(folder); if isfolder(folder), rmdir(folder, 's'); end
end
