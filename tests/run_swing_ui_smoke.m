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
assert(~view.Diagnostics.Tested); % 数値誤差だけの残差は正規性の判定対象外
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
main = app.MainTabs;
main.SelectedTab = state.Layout.Parent; state.Views.SelectedTab = state.ChartTabs.Parent.Parent; state.ChartTabs.SelectedTab = tab;
state.Source.Text = '合成データ（GP学習・実SHAP未実行）';
state.ModelInfo.Value = {'表示試験：正弦波＋直線で作成した合成SHAP値'; '周期80 / 振幅2.5 / 傾き0.01'};
state.Messages.Value = {'表示専用 R2022b / 合成データ'; '近似曲線、極値膜厚、山・谷を結ぶ傾きを確認'};
state.Headline.Text = 'Swing Curve近似の表示見本（GP学習・実SHAP計算は未実行）';
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
end
% 分布の診断はノイズを加えた別の合成SHAP値で確認する。
delete(state.ChartTabs.Children);
stream = RandStream('mt19937ar', 'Seed', 42); shap(:, 4) = shap(:, 4) + 0.15*randn(stream, size(x));
[charts, labels] = plot_shap_figures(state.ChartTabs, shap, inputs, names); app.registerCharts(5, charts, labels);
tab = state.ChartTabs.Children(strcmp({state.ChartTabs.Children.Title}, 'SHAP 依存: RESIST_TH')); view = tab.UserData;
state.ChartTabs.SelectedTab = tab;
assert(view.Diagnostics.Tested); assert(numel(charts) == 8);
assert(isequal(view.Tables.Residuals.Data.Residual, shap(:, 4) - view.Fit.Prediction));
view.TableTabs.SelectedTab = view.Tables.Normality.Parent.Parent;
assert(isequaln(view.currentTable(), view.Diagnostics.Table));
view.Controls.RangeMin.Value = 900; view.Controls.RangeMax.Value = 1200; view.refit();
assert(view.Diagnostics.Count == nnz(thickness >= 900 & thickness <= 1200));
assert(isequal(view.Tables.Residuals.Data.InputRow, find(thickness >= 900 & thickness <= 1200)));
view.Controls.PeriodMin.Value = 100; view.Controls.PeriodMax.Value = 50; view.refit();
assert(isempty(view.Diagnostics)); assert(isempty(view.Tables.Normality.Data)); assert(isempty(view.Tables.Residuals.Data));
assert(isempty(view.DiagnosticAxes.QQ.Children));
view.Controls.RangeMin.Value = 850; view.Controls.RangeMax.Value = 1250;
view.Controls.PeriodMin.Value = 0; view.Controls.PeriodMax.Value = 0; view.refit();
assert(view.Diagnostics.Tested);
apply_app_theme(app.Window, 'ダーク'); apply_app_theme(app.Window, 'ライト');
fields = {'Histogram', 'QQ', 'Residual'};
for index = 1:numel(fields)
    ax = view.DiagnosticAxes.(fields{index}); view.PlotTabs.SelectedTab = ancestor(ax, 'uitab');
    scroll(view.Layout, 'bottom'); drawnow;
    exportgraphics(ax, chart_file, 'Resolution', 100); assert(isfile(chart_file));
end
assert(numel(findall(groot, 'Type', 'figure')) == 1);
if ~isempty(image_folder)
    state.Messages.Value = {'表示専用 R2022b / 合成SHAP値＋正規乱数ノイズ'; '残差の分布・検定・歪度・尖度の参考診断'};
    scroll(view.Layout, view.PlotTabs);
    view.PlotTabs.SelectedTab = ancestor(view.DiagnosticAxes.Histogram, 'uitab');
    view.TableTabs.SelectedTab = view.Tables.Normality.Parent.Parent;
    drawnow; exportapp(app.Window, fullfile(image_folder, '24-swing-residual-histogram.png'));
    view.PlotTabs.SelectedTab = ancestor(view.DiagnosticAxes.QQ, 'uitab');
    drawnow; exportapp(app.Window, fullfile(image_folder, '25-swing-residual-qq.png'));
    view.PlotTabs.SelectedTab = ancestor(view.DiagnosticAxes.Residual, 'uitab');
    view.TableTabs.SelectedTab = view.Tables.Residuals.Parent.Parent;
    drawnow; exportapp(app.Window, fullfile(image_folder, '26-swing-residual-thickness.png'));
    help_tab = main.Children(strcmp({main.Children.Title}, '10 Help')); main.SelectedTab = help_tab;
    scroll(help_tab.Children(1), 'bottom');
    drawnow; pause(0.5); exportapp(app.Window, fullfile(image_folder, '09-help.png'));
end
fprintf('Swing UI: fit, range, extrema, slopes, residual diagnostics, table selection, recovery, theme, embedded PNG: PASS\n');
end
