function run_ui_smoke(image_folder)
% UI・純粋関数のみ。R2025b のモデル実行確認を代替しない。
if nargin < 1, image_folder = ''; end
[app, cleanup] = create_display_preview(); %#ok<ASGLU>
window = app.Window; main = findobj(window, 'Type', 'uitabgroup', 'TabLocation', 'left');
assert(numel(main.Children) == 9);
assert(~any(contains(string({main.Children.Title}), {'面内学習', '評価指標', '列の要約統計量'})));
app.message(1, '日本語のステータスが1行で表示されます。');
assert(strcmp(app.Panels{1}.Messages.Value{end}, '日本語のステータスが1行で表示されます。'));
state = app.Panels{1}; state.Mapping.Data = {1, 'F1', 'F1'; 2, 'F2', 'F2'; 3, 'y', 'y'};
x = (1:12)'; actual = 2 * x; predicted = actual + 1;
app.displayEvaluation(1, [x, x.^2], actual, predicted, '合成データによる表示試験');
assert(height(state.Metrics.Data) == 8); assert(height(state.Summary.Data) == 55);
[charts, names] = plot_shap_figures(state.ChartTabs, [sin(x), cos(x)], [x, x.^2], {'F1', 'F2'});
app.registerCharts(1, charts, names);
assert(numel(findall(groot, 'Type', 'figure')) == 1);
chart_path = [tempname, '.png']; image_cleanup = onCleanup(@() delete(chart_path));
state.Views.SelectedTab = state.ChartTabs.Parent.Parent;
state.ChartTabs.SelectedTab = ancestor(charts{1}, 'uitab'); drawnow;
exportgraphics(charts{1}, chart_path, 'Resolution', 100); assert(isfile(chart_path));
app.applyTheme(); apply_app_theme(window, 'ダーク'); apply_app_theme(window, 'ライト');
state = app.Panels{6}; state.Factors.Value = 2; state.Runs.Value = 8; state.Method.Value = 'I最適';
app.run(6); assert(height(state.Results.Data) == 8); assert(~isempty(state.ChartTabs.Children));
state.Method.Value = '直交表'; state.Levels.Value = '3'; app.run(6);
assert(height(state.Results.Data) == 9);
assert(numel(state.Views.Children) == 7); % 再実行で追加の表タブを重複させない
app.run(7); app.run(7); assert(numel(app.Panels{7}.ChartTabs.Children) == 1);
main.SelectedTab = app.Panels{7}.Layout.Parent;
app.Panels{7}.Views.SelectedTab = app.Panels{7}.ChartTabs.Parent.Parent; drawnow;
exportgraphics(app.Panels{7}.Figures{1}, chart_path, 'Resolution', 100); assert(isfile(chart_path));
assert(numel(findall(groot, 'Type', 'figure')) == 1);
main.SelectedTab = app.Panels{1}.Layout.Parent;
window.Position(3:4) = [900, 780]; drawnow;
assert(app.Panels{1}.Right.Layout.Row == 2);
assert(numel(app.Panels{1}.Layout.ColumnWidth) == 1);
assert(main.Position(3) == window.Position(3) - 20);
if ~isempty(image_folder), exportapp(window, fullfile(image_folder, '13-resize.png')); end
window.Position(3:4) = [1600, 1000]; drawnow;
assert(app.Panels{1}.Right.Layout.Column == 2);
app.SettingsUI.Theme.Value = 'ダーク'; app.saveSettings();
assert(strcmp(app.Settings.Theme, 'ダーク')); assert(isfile(app.SettingsPath));
assert(isempty(app.Panels{1}.Metrics.Data));
assert(~app.Panels{1}.Confirmed);
fprintf('UI smoke: 9 tabs, status, evaluation, embedded SHAP/DOE/wordcloud, resize, theme/settings: PASS\n');
end
