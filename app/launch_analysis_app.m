function controller = launch_analysis_app()
% ソース確認用の起動口。配布時は AnalysisApp.mlapp を入口にする。
project_root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(project_root, 'core'));
require_r2025b();
window = uifigure('Name', 'Process Insight Tool', 'Position', [100, 100, 1320, 860]);
controller = AnalysisController(window);
window.UserData = controller;
end
