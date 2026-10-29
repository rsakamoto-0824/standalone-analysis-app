function run_furnace_ui_smoke(image_folder)
% 実GPRを学習せず、スプライン/RBF/3次多項式と合成入力で画面を確認する。
if nargin < 1, image_folder = ''; end
[app, cleanup] = create_display_preview(); %#ok<ASGLU>
assert(isempty(app.Furnace)); app.openFurnace(); view = app.Furnace;
main = findobj(app.Window, 'Type', 'uitabgroup', 'TabLocation', 'left');
assert(numel(main.Children) == 10); assert(any(strcmp({main.Children.Title}, '2 Swing Curve学習')));
app.Window.Position = [40, 40, 1600, 1000];
slots = (5:10:95)'; rows = numel(slots);
thickness = 100 + 3*sin(slots/45); refractive = 1.46 + 0.01*cos(slots/40);
values = [thickness, refractive]; values([3, 7], 1) = NaN; values([2, 6], 2) = NaN;
cells = [cellstr("DEMO-A-" + string((1:rows)')), num2cell(slots), num2cell(values), repmat({'Run-A'}, rows, 1); ...
    cellstr("DEMO-B-" + string((1:rows)')), num2cell(slots), num2cell(values + [5, 0.02]), repmat({'Run-B'}, rows, 1)];
source = struct('FileName', 'synthetic_furnace.csv', 'Headers', {{'WaferId', 'BoatSlot', '膜厚', '屈折率', 'バッチ'}}, ...
    'Cells', {cells}, 'RowNumbers', (2:2*rows + 1)');
view.importSource(source); assert(strcmp(view.Batch.Value, 'バッチ')); assert(numel(view.Targets.Value) == 2);
assert(view.Minimum.Value == 5 && view.Maximum.Value == 95);
assert(numel(view.Methods.Value) == 6 && any(strcmp(view.Methods.ItemsData, 'poly3')));
view.Methods.Value = {'spline', 'rbf', 'poly3'}; view.Minimum.Value = 1; view.Maximum.Value = 100; view.confirm(); assert(view.Confirmed);
data = prepare_furnace_data(source, 'WaferId', 'BoatSlot', {'膜厚', '屈折率'}, 'バッチ');
report = interpolate_furnace_batches(data, (1:100)', {'spline', 'rbf', 'poly3'}, struct());
view.showReport(report);
assert(height(view.Tables.Comparison.Data) == 12); assert(height(view.Tables.Predictions.Data) == 1200);
assert(height(view.Tables.Metrics.Data) == 192); assert(strcmp(view.Selection.Enable, 'on'));
assert(numel(view.Charts{1}.Children) >= 4);
view.Selection.Value = 7; view.Selection.ValueChangedFcn(view.Selection, []);
assert(contains(view.Headline.Text, 'Run-B'));
view.Selection.Value = 3; view.Selection.ValueChangedFcn(view.Selection, []);
assert(contains(view.Headline.Text, 'poly3'));
view.Source.Text = '合成データ / 2バッチ / GPR未学習';
view.Messages.Value = {'R2022bの表示・操作の補助確認'; 'スプライン/RBF/3次多項式のみ補助計算。GPRは未学習。'; 'WaferIdは架空のDEMO識別子。実測データではありません。'};
view.Tabs.SelectedTab = view.Tables.Comparison.Parent.Parent;
assert(height(view.currentTable()) == 12);
file = [tempname, '.csv']; file_cleanup = onCleanup(@() delete(file)); writetable(view.currentTable(), file); loaded = readtable(file); assert(height(loaded) == 12);
if ~isempty(image_folder)
    drawnow; exportapp(app.Window, fullfile(image_folder, '31-furnace-comparison.png'));
end
view.Tabs.SelectedTab = view.PlotTabs.Parent.Parent;
view.PlotTabs.SelectedTab = ancestor(view.Charts{1}, 'uitab'); drawnow;
png = [tempname, '.png']; png_cleanup = onCleanup(@() delete(png)); exportgraphics(view.Charts{1}, png, 'Resolution', 100); assert(isfile(png));
if ~isempty(image_folder), exportapp(app.Window, fullfile(image_folder, '32-furnace-profiles.png')); end
lock = app.lockControls(view); assert(strcmp(view.Run.Enable, 'off')); clear lock; %#ok<NASGU>
assert(strcmp(view.Run.Enable, 'on') && strcmp(view.Selection.Enable, 'on'));
view.RBFWidth.ValueChangedFcn(view.RBFWidth, []); assert(isempty(view.Report) && ~view.Confirmed);
view.showReport(report); app.SettingsUI.Theme.Value = 'ダーク'; app.saveSettings();
assert(isempty(view.Report) && ~view.Confirmed); assert(view.Bins.Value == app.SettingsUI.Bins.Value);
app.Window.Position(3:4) = [900, 780]; app.Window.SizeChangedFcn(app.Window, []); drawnow;
fprintf('Furnace native resize: width=%g / row=%g / column=%g\n', app.Window.Position(3), view.Right.Layout.Row, view.Right.Layout.Column);
assert(view.Right.Layout.Row == 2);
app.Window.Position(3:4) = [1366, 900]; app.Window.SizeChangedFcn(app.Window, []); drawnow;
fprintf('Furnace native resize: width=%g / row=%g / column=%g\n', app.Window.Position(3), view.Right.Layout.Row, view.Right.Layout.Column);
assert(view.Right.Layout.Column == 2);
app.openFurnace(); assert(isequal(app.Furnace, view));
assert(numel(findall(groot, 'Type', 'figure')) == 1);
fprintf('Furnace UI: spline/RBF/poly3, batch/wafer mapping, sparse targets, comparison, profiles, CSV/PNG, lock, settings, resize, single window: PASS\n');
end
