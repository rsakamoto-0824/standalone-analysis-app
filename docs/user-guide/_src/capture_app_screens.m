function capture_app_screens()
% 手順書専用の表示見本。製品コード・リリース制約・学習関数は変更しない。
project_root = fileparts(fileparts(fileparts(fileparts(mfilename('fullpath')))));
guide_root = fileparts(fileparts(mfilename('fullpath')));
image_folder = fullfile(guide_root, 'images');
if ~isfolder(image_folder), mkdir(image_folder); end
addpath(fullfile(project_root, 'core'));
preview_folder = tempname; mkdir(preview_folder);
folder_cleanup = onCleanup(@() removePreview(preview_folder));
text = fileread(fullfile(project_root, 'app', 'AnalysisController.m'));
assert(count(string(text), 'require_r2025b();') == 1, 'UI 起動時の確認箇所が変更されています。');
text = strrep(text, 'classdef AnalysisController < handle', 'classdef GuidePreviewController < handle');
text = strrep(text, 'function app = AnalysisController(window)', 'function app = GuidePreviewController(window)');
text = strrep(text, 'require_r2025b();', '% 表示専用コピー。計算用コールバックはすべて無効にする。');
text = strrep(text, 'スタンドアローン解析アプリ — R2025b', '手順書の表示見本 / R2022b / モデル未作成');
source_root_line = 'project_root = fileparts(fileparts(mfilename(''fullpath'')));';
text = strrep(text, source_root_line, ['project_root = ''' strrep(project_root, '''', '''''') ''';']);
preview_file = fullfile(preview_folder, 'GuidePreviewController.m');
fid = fopen(preview_file, 'w', 'n', 'UTF-8'); fprintf(fid, '%s', text); fclose(fid);
addpath(preview_folder);
window = uifigure('Visible', 'on');
window_cleanup = onCleanup(@() delete(window));
controller = GuidePreviewController(window);
window.Position = [40, 40, 1320, 860];
tab_group = findobj(window, 'Type', 'uitabgroup');
main_tabs = tab_group(arrayfun(@(group) strcmp(group.TabLocation, 'left'), tab_group));
all_tabs = main_tabs.Children;
tabs = gobjects(10, 1);
for tab_index = 1:10
    tabs(tab_index) = all_tabs(startsWith(string({all_tabs.Title}), sprintf('%d ', tab_index)));
end
row_index = (1:150)';
sample = [100 + sin(row_index / 7), 1.9 + cos(row_index / 11) / 100, ...
    60 + sin(row_index / 13), 900 + 10 * cos(row_index / 17), ...
    50 + sin(row_index / 9), row_index - 75, 50 * sin(row_index / 19)];
headers = {'SIN_TH', 'SIN_RN', 'NSG_TH', 'RESIST_TH', 'CD', 'Xmm', 'Ymm'};
image_names = {'01-apc', '02-swing', '03-in-plane', '04-generic', '05-predict', ...
    '06-shap', '07-metrics', '08-summary', '09-doe', '10-words'};
for index = 1:10
    panel = controller.Panels{index};
    fields = fieldnames(panel);
    for field_index = 1:numel(fields)
        item = panel.(fields{field_index});
        if isscalar(item) && isgraphics(item)
            if isprop(item, 'ButtonPushedFcn'), item.ButtonPushedFcn = []; end
            if isprop(item, 'ValueChangedFcn'), item.ValueChangedFcn = []; end
            if isprop(item, 'CellEditCallback'), item.CellEditCallback = []; end
        end
    end
    panel.Messages.Value = {'表示見本（R2022b / 合成データ）'; '学習・モデル保存・推定・SHAP・DOE は未実行です。'};
    if index <= 8
        panel.Source.Text = 'demo_training.csv / ヘッダー 1 行目 / 150 件（合成データ）';
        panel.Preview.Data = num2cell(sample(1:12, :)); panel.Preview.ColumnName = headers;
        panel.Mapping.ColumnFormat = {'numeric', 'char', [{'(未選択)'}, headers]};
    end
    if any(index == [1, 2])
        panel.Mapping.Data = [(num2cell((1:5)')), [headers(1:4), {'y'}]', headers(1:5)'];
    elseif index == 3
        panel.Mapping.Data = {1, 'X', 'Xmm'; 2, 'Y', 'Ymm'; 3, 'y', 'CD'};
        panel.TestMapping.Data = {1, 'X', 'Xmm'; 2, 'Y', 'Ymm'};
        panel.TestLoad.Text = '推定用: demo_coordinates.csv（合成データ）';
    elseif index == 4
        panel.Mapping.Data = {1, '入力1', 'SIN_TH'; 2, '入力2', 'SIN_RN'; ...
            3, '入力3', 'NSG_TH'; 4, '入力4', 'RESIST_TH'; 5, 'y', 'CD'};
    elseif any(index == [5, 6])
        panel.ModelInfo.Value = {'ここに読込モデルの PredictorNames / ResponseName を表示'; ...
            'この撮影ではモデル未読込。列対応は説明用の見本です。'};
        panel.Mapping.Data = [(num2cell((1:4)')), headers(1:4)', headers(1:4)'];
    elseif index == 7
        panel.Mapping.Data = {1, 'col1', 'actual'; 2, 'col2', 'predicted'};
        panel.Source.Text = '指標の説明用ベクトル: actual=[1,2,4], predicted=[2,3,5]';
        panel.Results.Data = cell2table(calc_all_metrics([1, 2, 4], [2, 3, 5]), 'VariableNames', {'Metric', 'Value'});
        panel.Messages.Value = {'R2022b / 合成ベクトルの計算値を表示'; 'RMSE=1、MAE=1、r=1、r_squared=1'};
    elseif index == 8
        panel.Columns.Items = {'demo_A', 'demo_B'}; panel.Columns.Value = {'demo_A', 'demo_B'};
        first = calc_column_summary([1, 2, 3, 4, NaN]); second = calc_column_summary([2, 4, 6, 8, NaN]);
        panel.Results.Data = table(string(first(:, 1)), cell2mat(first(:, 2)), cell2mat(second(:, 2)), ...
            'VariableNames', {'Statistic', 'demo_A', 'demo_B'});
        panel.Source.Text = 'demo_A=[1,2,3,4,NaN] / demo_B=[2,4,6,8,NaN]';
        panel.Messages.Value = {'R2022b / 合成ベクトルの計算値を表示'; 'NaN は要約統計量だけで除外します。'};
    elseif index == 9
        panel.Factors.Value = 2; panel.Runs.Value = 12; panel.Seed.Value = '42';
    elseif index == 10
        panel.Text.Value = {'MATLAB analysis MATLAB model'; 'analysis model model SHAP'};
        [words, counts] = create_wordCloud(strjoin(string(panel.Text.Value), newline));
        panel.Results.Data = table(words, counts, 'VariableNames', {'Word', 'Count'});
        panel.Messages.Value = {'R2022b / 説明用テキストの単語数を表示'; '日本語は空白区切りで入力します。'};
    end
    main_tabs.SelectedTab = tabs(index);
    drawnow; pause(0.25); drawnow;
    exportapp(window, fullfile(image_folder, [image_names{index} '.png']));
    fprintf('CAPTURED %s\n', image_names{index});
end
main_tabs.SelectedTab = tabs(1);
panel = controller.Panels{1};
result_tabs = panel.Results.Parent.Parent.Parent;
result_tabs.SelectedTab = panel.Preview.Parent.Parent;
drawnow; exportapp(window, fullfile(image_folder, '11-input-preview.png'));
result_tabs.SelectedTab = panel.Results.Parent.Parent;
panel.Messages.Value = {'警告の表示位置の見本（学習は未実行）'; ...
    'データが少ないためモデルの扱いに注意してください'; ...
    '実際の保存後は右下の検証表を確認します。'};
drawnow; exportapp(window, fullfile(image_folder, '12-warning-area.png'));
main_tabs.SelectedTab = tabs(6);
controller.Panels{6}.Mode.Value = 'ノイズ除去用SHAP';
drawnow; exportapp(window, fullfile(image_folder, '13-denoise-shap.png'));
cloud_figure = figure('Color', 'white', 'Name', 'Word Cloud / R2022b / 説明用テキスト', 'Position', [100, 100, 900, 540]);
cloud_cleanup = onCleanup(@() close(cloud_figure));
cloud = wordcloud(words, counts);
cloud.Title = 'Word Cloud';
drawnow; exportgraphics(cloud_figure, fullfile(image_folder, '14-wordcloud.png'), 'Resolution', 120);
fprintf('CAPTURES_COMPLETE\n');
end

function removePreview(folder)
if contains(path, folder), rmpath(folder); end
clear GuidePreviewController;
if isfolder(folder), rmdir(folder, 's'); end
end
