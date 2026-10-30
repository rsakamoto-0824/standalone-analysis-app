function capture_app_screens(extra_only, dark_only)
% 補助確認と手順書用の撮影。GP学習・モデル保存・実SHAP計算は行わない。
root = fileparts(fileparts(fileparts(fileparts(mfilename('fullpath')))));
if nargin < 1, extra_only = false; end
if nargin < 2, dark_only = false; end
folder = fullfile(fileparts(fileparts(mfilename('fullpath'))), 'images');
addpath(fullfile(root, 'tests'));
[app, cleanup] = create_display_preview(); window = app.Window; %#ok<ASGLU>
window.Position = [40, 40, 1320, 860];
main = app.MainTabs;
x = (1:40)'; inputs = [sin(x/7), cos(x/9), sin(x/11), cos(x/13)];
actual = 10 + sin(x/8); predicted = actual + 0.08 * cos(x/6);
headers = {'SIN_TH', 'SIN_RN', 'NSG_TH', 'RESIST_TH', 'CD'};
for index = 1:5
    state = app.Panels{index};
    main.SelectedTab = state.Layout.Parent;
    state.Source.Text = 'demo.csv / 40件（合成データ・表示見本）';
    state.Preview.Data = num2cell([inputs, actual]); state.Preview.ColumnName = headers;
    roles = headers(1:4);
    if index <= 3, roles = [roles, {'y'}]; end %#ok<AGROW>
    state.Mapping.Data = [num2cell((1:numel(roles))'), roles', headers(1:numel(roles))'];
    state.Mapping.ColumnFormat = {'numeric', 'char', [{'(未選択)'}, headers]};
    if any(index == [4, 5]), state.Actual.Items = [{'(実測値なし)'}, headers]; state.Actual.Value = 'CD'; end
    app.displayEvaluation(index, inputs, actual, predicted, '合成ベクトルでの表示見本 / GP未学習');
    state.Results.Data = table(x + 1, actual, predicted, actual - predicted, 'VariableNames', {'SourceRow', 'Actual', 'Predicted', 'Residual'});
    state.ModelInfo.Value = {'表示見本 / GPモデル未読込・未学習'; '正本の学習・保存コードは未変更'};
    state.Messages.Value = {'日本語のステータスを文単位で表示します。'; 'R2022b表示見本 / モデル学習・保存・実SHAPは未実行。'};
end
state = app.Panels{5};
main.SelectedTab = state.Layout.Parent;
[charts, names] = plot_shap_figures(state.ChartTabs, 0.1 * inputs, inputs, headers(1:4));
app.registerCharts(5, charts, names);
if ~dark_only
    state = app.Panels{6}; state.Factors.Value = 3; state.Runs.Value = 16; state.Method.Value = 'I最適'; app.run(6);
    app.run(7);
end
app.applyTheme();
image_names = {'01-apc', '02-swing', '03-generic', '04-predict', '05-shap', '06-doe', '07-words', '08-settings', '09-help'};
app.SettingsUI.Message.Text = '設定保存先: prefdir / StandaloneAnalysisApp / settings.json（撮影用・未保存）';
app.SettingsUI.SaveFolder.Value = 'C:\Analysis\Results（保存先の入力例）';
if dark_only
    apply_app_theme(window, 'ダーク'); main.applyTheme('ダーク'); capture(window, folder, '14-dark-theme'); return;
end
if ~extra_only
display_order = [1:3, 5:10];
for image_index = 1:numel(display_order)
    index = display_order(image_index);
    main.SelectedTab = main.Children(startsWith(string({main.Children.Title}), sprintf('%d ', index)));
    capture(window, folder, image_names{image_index});
end
end
main.SelectedTab = main.Children(startsWith(string({main.Children.Title}), '1 ')); state = app.Panels{1};
if ~extra_only
state.Views.SelectedTab = state.Metrics.Parent.Parent; capture(window, folder, '10-model-evaluation');
state.Views.SelectedTab = state.Summary.Parent.Parent; capture(window, folder, '11-column-summary');
state.Views.SelectedTab = state.ChartTabs.Parent.Parent; capture(window, folder, '12-model-chart');
end
window.Position(3:4) = [900, 780]; window.SizeChangedFcn(window, []); drawnow; capture(window, folder, '13-resize');
window.Position(3:4) = [1320, 860]; window.SizeChangedFcn(window, []); drawnow; apply_app_theme(window, 'ダーク'); main.applyTheme('ダーク'); capture(window, folder, '14-dark-theme');
app.applyTheme(); state.Views.SelectedTab = state.Preview.Parent.Parent; capture(window, folder, '17-input-preview');
main.SelectedTab = main.Children(startsWith(string({main.Children.Title}), '6 ')); state = app.Panels{5};
state.Mode.Value = 'ノイズ除去用SHAP'; capture(window, folder, '18-denoise');
state.Views.SelectedTab = state.ChartTabs.Parent.Parent;
state.ChartTabs.SelectedTab = state.ChartTabs.Children(strcmp({state.ChartTabs.Children.Title}, 'SHAP 分布'));
capture(window, folder, '21-shap-chart');
main.SelectedTab = main.Children(startsWith(string({main.Children.Title}), '7 ')); state = app.Panels{6};
state.Views.SelectedTab = state.ChartTabs.Parent.Parent; capture(window, folder, '19-confounding');
main.SelectedTab = main.Children(startsWith(string({main.Children.Title}), '8 ')); state = app.Panels{7};
state.Views.SelectedTab = state.ChartTabs.Parent.Parent; capture(window, folder, '20-wordcloud');
fprintf('CAPTURES_COMPLETE: GP学習・モデル保存・実SHAP未実行\n');
end
function capture(window, folder, name)
drawnow; pause(0.3); drawnow; exportapp(window, fullfile(folder, [name '.png'])); fprintf('CAPTURED %s\n', name);
end
