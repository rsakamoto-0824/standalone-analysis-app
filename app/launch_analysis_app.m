function controller = launch_analysis_app(edition)
% アプリの起動口。MATLABのコマンドウィンドウから、または配布版の入口として使う。
%   launch_analysis_app            既定の版で起動
%   launch_analysis_app('pro')     Pro版の画面を確認（ソース実行時のみ切替可能）
if nargin < 1, edition = app_edition(); end
if ~isdeployed
    project_root = fileparts(fileparts(mfilename('fullpath')));
    addpath(fullfile(project_root, 'core'), fullfile(project_root, 'app'));
end
require_r2025b();
window = uifigure('Name', 'Process Insight Tool', 'Position', [80, 60, AnalysisController.WINDOW_SIZE], 'Visible', 'off');
controller = AnalysisController(window, edition);
window.UserData = controller;
movegui(window, 'center'); window.Visible = 'on';
if isdeployed
    % 配布版では、ウィンドウを閉じるまでアプリを終了させない。
    waitfor(window);
end
end
