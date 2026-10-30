function run_navigation_ui_smoke(image_folder)
% 画面と純粋な評価計算だけを確認する。GPRの学習・保存は行わない。
if nargin < 1, image_folder = ''; end
[app, cleanup] = create_display_preview(); %#ok<ASGLU>
main = app.MainTabs;
expected = {'1 APC 学習', '2 Swing Curve学習', '3 汎用 GPR 学習', '4 炉内補間', ...
    '5 保存モデルで推定', '6 SHAP 解析', '7 実験計画作成', '8 ワードクラウド', '9 設定', '10 Help'};
assert(isequal({main.Children.Title}, expected));
for index = 1:numel(main.Buttons)
    button = main.Buttons{index}; button.ValueChangedFcn(button, []);
    assert(isequal(main.SelectedTab, main.Pages{index}));
    assert(sum(cellfun(@(page) strcmp(page.Visible, 'on'), main.Pages)) == 1);
    assert(sum(cellfun(@(item) item.Value, main.Buttons)) == 1);
end
fprintf('NAV_SWITCH_PASS\n');
assert(~isempty(app.Furnace)); furnace = app.Furnace;
for index = 1:5, assert(~isfield(app.Panels{index}, 'Bins')); end
assert(~isprop(furnace, 'Bins'));
labels = findall(app.Window, 'Type', 'uilabel');
bin_labels = arrayfun(@(label) contains(string(label.Text), 'KL / MI') && contains(string(label.Text), 'ビン数'), labels);
assert(sum(bin_labels) == 1);
app.SettingsUI.Bins.Value = 3; app.saveSettings(); assert(app.Settings.Bins == 3);
assert(furnace.evaluationOptions().Bins == 3);
state = app.Panels{1}; state.Mapping.Data = {1, 'F1', 'F1'; 2, 'y', 'y'};
x = (1:60)'; actual = sin(x / 8) + x / 20; predicted = 0.7 * actual + cos(x / 5) / 2;
app.displayEvaluation(1, x, actual, predicted, '共通ビン数の補助試験');
expected_metrics = evaluate_predictions(actual, predicted, 3);
assert(isequaln(state.Metrics.Data.Value, expected_metrics.Value));
app.SettingsUI.Bins.Value = 7; app.saveSettings();
assert(isempty(state.Metrics.Data) && ~state.Confirmed);
assert(isempty(furnace.Report) && ~furnace.Confirmed && furnace.evaluationOptions().Bins == 7);
state.Mapping.Data = {1, 'F1', 'F1'; 2, 'y', 'y'};
app.displayEvaluation(1, x, actual, predicted, '共通ビン数の補助試験');
new_metrics = evaluate_predictions(actual, predicted, 7);
assert(isequaln(state.Metrics.Data.Value, new_metrics.Value));
assert(any(abs(expected_metrics.Value(7:8) - new_metrics.Value(7:8)) > 1e-6));
fprintf('COMMON_BINS_PASS\n');
main.SelectedTab = state.Layout.Parent;
state.Views.SelectedTab = state.ChartTabs.Parent.Parent;
state.ChartTabs.SelectedTab = ancestor(app.Panels{1}.Figures{2}, 'uitab'); drawnow;
if ~isempty(image_folder)
    state.Source.Text = '合成データ / GPR未学習';
    drawnow; pause(0.5); drawnow;
    exportapp(app.Window, fullfile(image_folder, '33-navigation-clipboard.png'));
    main.SelectedTab = main.Pages{9};
    app.SettingsUI.Message.Text = '設定保存先: prefdir / StandaloneAnalysisApp / settings.json（撮影用）';
    app.SettingsUI.SaveFolder.Value = 'C:\Analysis\Results（保存先の入力例）'; drawnow; pause(0.5); drawnow;
    exportapp(app.Window, fullfile(image_folder, '34-shared-bins.png'));
    main.SelectedTab = state.Layout.Parent; drawnow;
end
% 表示中のグラフは選択ダイアログを出さずにコピーできることを確認する。
chooser = fullfile(fileparts(which('DisplayPreviewController')), 'listdlg.m');
file = fopen(chooser, 'w');
fprintf(file, 'function varargout = listdlg(varargin)\nerror(''preview:unexpectedChooser'', ''表示中のグラフで選択ダイアログが呼ばれました。'');\nend\n');
fclose(file); rehash;
fprintf('CLIPBOARD_START\n');
clipboard = java.awt.Toolkit.getDefaultToolkit().getSystemClipboard();
previous_clipboard = clipboard.getContents([]);
clipboard_cleanup = onCleanup(@() restoreClipboard(clipboard, previous_clipboard));
fprintf('COPY_AXES_START\n');
state.CopyFigure.ButtonPushedFcn(state.CopyFigure, []);
assert(contains(state.Messages.Value{end}, 'クリップボードにコピーしました: 残差'), state.Messages.Value{end});
assert(clipboard.isDataFlavorAvailable(java.awt.datatransfer.DataFlavor.imageFlavor));
fprintf('COPY_AXES_PASS\n');
app.run(7); main.SelectedTab = app.Panels{7}.Layout.Parent;
words = app.Panels{7}; words.CopyFigure.ButtonPushedFcn(words.CopyFigure, []);
assert(contains(words.Messages.Value{end}, 'クリップボードにコピーしました: Word Cloud'));
assert(clipboard.isDataFlavorAvailable(java.awt.datatransfer.DataFlavor.imageFlavor));
fprintf('COPY_WORDCLOUD_PASS\n');
clear clipboard_cleanup;
main.SelectedTab = state.Layout.Parent; drawnow;
initial_width = main.Menu.Position(3);
for size = {[900, 780], [1600, 1000]}
    app.Window.Position(3:4) = size{1}; app.Window.SizeChangedFcn(app.Window, []); drawnow;
    assert(abs(main.Menu.Position(3) - initial_width) < 1);
    assert(all(cellfun(@(button) button.Position(3) >= 200, main.Buttons)));
end
assert(numel(findall(groot, 'Type', 'figure')) == 1);
fprintf('Navigation UI: full-width labels, furnace order, shared bins, stale results, axes/wordcloud clipboard images, resize: PASS\n');
end
function restoreClipboard(clipboard, previous)
if ~isempty(previous), clipboard.setContents(previous, []); end
end
