function run_swing_ui_smoke(image_folder)
% 合成SHAP値で表示と数値の受渡しを確認。GP学習・実SHAP計算はしない。
if nargin < 1, image_folder = ''; end
[app, cleanup] = create_display_preview(); %#ok<ASGLU>
app.Window.Position = [40, 40, 1320, 780];
state = app.Panels{5};
thickness = linspace(850, 1250, 241)'; x = thickness - 1050;
inputs = [sin(x/50), cos(x/60), sin(x/70), thickness];
shap = [0.1*sin(x/50), 0.2*cos(x/60), 0.1*sin(x/70), 0.01*x + 2.5*sin(2*pi*x/80 + 0.4)];
names = {'SIN_TH', 'SIN_RN', 'NSG_TH', 'RESIST_TH'};
[charts, labels] = plot_shap_figures(state.ChartTabs, shap, inputs, names);
app.registerCharts(5, charts, labels);
tab = state.ChartTabs.Children(strcmp({state.ChartTabs.Children.Title}, 'SHAP 依存: RESIST_TH'));
view = tab.UserData;
assert(isa(view, 'SwingCurveView')); assert(~isempty(view.Fit), view.Summary.Text);
assert(abs(view.Fit.Period - 80) < 1e-4);
assert(all(abs(view.Tables.Slopes.Data.Slope - 0.01) < 1e-6));
view.TableTabs.SelectedTab = view.Tables.Extrema.Parent.Parent;
assert(isequal(view.currentTable(), view.Tables.Extrema.Data));
view.Controls.RangeMin.Value = 900; view.Controls.RangeMax.Value = 1200;
view.Controls.PeriodMin.Value = 60; view.Controls.PeriodMax.Value = 100;
view.refit(); assert(~isempty(view.Fit), view.Summary.Text); assert(isequal(view.Axes.XLim, [900, 1200]));
assert(all(view.Tables.Extrema.Data.Thickness >= 900 & view.Tables.Extrema.Data.Thickness <= 1200));
view.Controls.PeriodMin.Value = 110; view.refit();
assert(isempty(view.Fit)); assert(isempty(view.Tables.Extrema.Data));
view.Controls.PeriodMin.Value = 60; view.refit(); assert(~isempty(view.Fit), view.Summary.Text);
view.Controls.Trend.Value = false; view.refit(); assert(view.Fit.Slope == 0);
view.Controls.Trend.Value = true; view.Controls.RangeMin.Value = 850; view.Controls.RangeMax.Value = 1250;
view.refit(); app.applyTheme(); apply_app_theme(app.Window, 'ダーク'); apply_app_theme(app.Window, 'ライト');
main = findobj(app.Window, 'Type', 'uitabgroup', 'TabLocation', 'left');
main.SelectedTab = state.Layout.Parent; state.Views.SelectedTab = state.ChartTabs.Parent.Parent; state.ChartTabs.SelectedTab = tab;
state.Source.Text = '合成データ（GP学習・実SHAP未実行）';
state.ModelInfo.Value = {'表示試験：正弦波＋直線で作成した合成SHAP値'; '周期80 / 振幅2.5 / 傾き0.01'};
state.Messages.Value = {'表示専用 R2022b / 合成データ'; '近似曲線、極値膜厚、山・谷を結ぶ傾きを確認'};
state.Headline.Text = 'スイング近似の表示見本（GP学習・実SHAP計算は未実行）';
drawnow;
chart_file = [tempname, '.png']; file_cleanup = onCleanup(@() delete(chart_file));
exportgraphics(view.Axes, chart_file, 'Resolution', 100); assert(isfile(chart_file));
assert(numel(findall(groot, 'Type', 'figure')) == 1);
if ~isempty(image_folder)
    view.TableTabs.SelectedTab = view.Tables.Slopes.Parent.Parent;
    drawnow; exportapp(app.Window, fullfile(image_folder, '22-swing-fit.png'));
    view.TableTabs.SelectedTab = view.Tables.Extrema.Parent.Parent;
    scroll(view.Layout, 'bottom');
    drawnow; exportapp(app.Window, fullfile(image_folder, '23-swing-extrema.png'));
    training = app.Panels{2}; main.SelectedTab = training.Layout.Parent;
    training.Mapping.Data = [num2cell((1:5)'), [names, {'y'}]', [names, {'CD'}]'];
    actual = 50 + shap(:, 4); prediction = actual + 0.05*cos(x/60);
    app.displayEvaluation(2, inputs, actual, prediction, '合成ベクトルでの表示見本 / GP未学習');
    training.Results.Data = table((1:numel(actual))', actual, prediction, actual - prediction, ...
        'VariableNames', {'SourceRow', 'Actual', 'Predicted', 'Residual'});
    training.Source.Text = 'demo_swing.csv / 合成データ（モデル未学習）';
    training.ModelInfo.Value = {'表示見本 / GPモデル未読込・未学習'; '正本の学習・保存コードは未変更'};
    training.IsPlot.Value = true;
    training.Messages.Value = {'表示見本：このチェックで学習後SHAPを計算'; 'この撮影ではGP学習・保存・実SHAPは未実行。'};
    app.applyTheme(); drawnow; exportapp(app.Window, fullfile(image_folder, '02-swing.png'));
end
fprintf('Swing UI: fit, range, extrema, slopes, table selection, recovery, theme, embedded PNG: PASS\n');
end
