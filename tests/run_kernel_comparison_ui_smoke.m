function run_kernel_comparison_ui_smoke(image_folder)
% 表示・純粋な代替学習器だけの補助試験。GPRは学習・保存しない。
if nargin < 1, image_folder = ''; end
[app, cleanup] = create_display_preview(); %#ok<ASGLU>
assert(~isfield(app.Panels{1}, 'Comparison'));
app.Window.Position = [40, 40, 1600, 1000];
main = app.MainTabs;
x = (1:40)'; inputs = [sin(x/4), cos(x/5), sin(x/7), 850 + 10*x]; actual = 50 + 2*sin(x/4);
source_rows = x + 1; names = {'SIN_TH', 'SIN_RN', 'NSG_TH', 'RESIST_TH'};
for panel = 1:3
    app.openComparison(panel); state = app.Panels{panel}; view = state.Comparison;
    app.openComparison(panel); assert(numel(state.Views.Children) == 7);
    assert(strcmp(view.Kernels.Multiselect, 'on'));
    assert(view.Folds.Layout.Row == 1 && view.Seed.Layout.Row == 2);
    assert(any(strcmp(view.Kernels.Items, 'swingperiodic')) == (panel == 2));
    state.Mapping.Data = [num2cell((1:5)'), [names, {'y'}]', [names, {'CD'}]'];
    kernels = {'matern32', 'squaredexponential', 'matern52'};
    view.Kernels.Value = kernels;
    report = evaluate_kernel_candidates(inputs, actual, kernels, 5, 0, 0, @syntheticModel, @syntheticPrediction);
    report.Kind = state.Kind; report.FitMethod = '表示見本（GPR未学習）';
    view.showReport(report, inputs, actual, source_rows, names);
    app.openComparison(panel); main.SelectedTab = state.Layout.Parent;
    state.Source.Text = '合成データ／GPR未学習'; state.Headline.Text = '合成データと代替学習器の表示見本（実GPRの比較結果ではありません）';
    assert(height(view.Summary.Data) == 3); assert(height(view.Metrics.Data) == 48);
    assert(view.selectedIndex() == 2); assert(strcmp(view.Save.Enable, 'on'));
    view.Selection.Value = 1; view.Selection.ValueChangedFcn(view.Selection, []);
    assert(isequal(view.Predictions.Data.ValidationPredicted, report.OOFPredictions(:, 1)));
    assert(isequal(view.Predictions.Data.SourceRow, source_rows));
    assert(height(view.ColumnSummary.Data) == 99);
    csv_file = [tempname, '.csv']; csv_cleanup = onCleanup(@() delete(csv_file));
    view.Tabs.SelectedTab = view.Summary.Parent.Parent;
    writetable(view.currentTable(), csv_file); loaded = readtable(csv_file);
    assert(height(loaded) == 3 && any(strcmp(loaded.Properties.VariableNames, 'RMSE')));
    lock = app.lockControls(view); assert(strcmp(view.Start.Enable, 'off')); clear lock; %#ok<NASGU>
    assert(strcmp(view.Start.Enable, 'on') && strcmp(view.Save.Enable, 'on'));
    if panel == 1 && ~isempty(image_folder)
        view.Selection.Value = 2; view.Selection.ValueChangedFcn(view.Selection, []);
        drawnow; pause(0.5); exportapp(app.Window, fullfile(image_folder, '29-kernel-comparison.png'));
        view.Tabs.SelectedTab = view.Tabs.Children(strcmp({view.Tabs.Children.Title}, '比較グラフ'));
        drawnow; pause(0.5); exportapp(app.Window, fullfile(image_folder, '30-kernel-comparison-chart.png'));
    end
    app.clearModelOutput(panel); assert(~isempty(view.Report)); assert(height(view.Summary.Data) == 3);
    app.invalidate(panel); assert(isempty(view.Report)); assert(strcmp(view.Save.Enable, 'off')); assert(isempty(view.Summary.Data));
end
state = app.Panels{3}; view = state.Comparison;
failed = evaluate_kernel_candidates(inputs, actual, {'matern32', 'matern52'}, 5, 0, 0, @fail, @syntheticPrediction);
view.showReport(failed, inputs, actual, source_rows, names); assert(strcmp(view.Save.Enable, 'off'));
assert(height(view.Summary.Data) == 2);
view.Kernels.ValueChangedFcn(view.Kernels, []); assert(isempty(view.Report));
app.Window.Position(3:4) = [900, 780]; drawnow; assert(state.Right.Layout.Row == 2);
app.Window.Position(3:4) = [1366, 900]; drawnow; assert(state.Right.Layout.Column == 2);
apply_app_theme(app.Window, 'ダーク'); apply_app_theme(app.Window, 'ライト');
assert(numel(findall(groot, 'Type', 'figure')) == 1);
fprintf('Kernel comparison UI: all 3 functions, selection, metrics, CSV, lock/unlock, stale results, failure, resize, single window: PASS\n');
end

function [model, warnings, details] = syntheticModel(~, ~, kernel, ~)
model = find(strcmp({'squaredexponential', 'matern32', 'matern52'}, kernel)) * 0.3;
warnings = []; details = [];
end
function prediction = syntheticPrediction(model, inputs)
prediction = 50 + 2*inputs(:, 1) + model*cos(inputs(:, 4)/40);
end
function [model, warnings, details] = fail(~, ~, ~, ~)
model = []; warnings = []; details = []; %#ok<NASGU>
error('preview:failure', '代替学習器の失敗表示試験');
end
