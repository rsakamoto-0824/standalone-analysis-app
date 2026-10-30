classdef FurnaceInterpolationView < handle
    properties (SetAccess = private)
        Layout
        Controls
        Right
        Source
        Wafer
        Slot
        Batch
        Targets
        Methods
        Minimum
        Maximum
        Step
        RBFWidth
        RBFRidge
        Extrapolate
        Confirm
        Run
        Messages
        Headline
        Selection
        Tabs
        Tables
        PlotTabs
        Charts
        CopyFigure
        Report = []
        Data = []
        Confirmed = false
    end
    properties (Access = private)
        Window
        Settings
        Constants
        Lock
        LogFolder
        ChartNames = {'炉内プロファイル比較', '内部Slot検証のRMSE', '選択モデルの検証残差'}
    end
    methods
        function view = FurnaceInterpolationView(parent, window, settings, lock_callback, log_folder)
            view.Window = window; view.Settings = settings; view.Constants = furnace_constants(); view.Lock = lock_callback; view.LogFolder = log_folder;
            view.Layout = uigridlayout(parent, [1, 2]); view.Layout.ColumnWidth = {380, '1x'};
            view.Controls = uigridlayout(view.Layout, [17, 1], 'Scrollable', 'on');
            view.Controls.RowHeight = {56, 32, 44, 32, 32, 32, 120, 146, 32, 32, 32, 32, 32, 26, 32, 34, 100};
            uilabel(view.Controls, 'Text', 'WaferId・BoatSlot・計測列を指定。バッチがあればRunごとに分けます。計測列の空欄は未計測として扱います。', 'WordWrap', 'on');
            uibutton(view.Controls, 'Text', 'Excel / CSV を開く', 'ButtonPushedFcn', @(~, ~) view.load());
            view.Source = uilabel(view.Controls, 'Text', '入力ファイル未選択', 'WordWrap', 'on');
            view.Wafer = view.choiceRow('WaferId列', {'(未選択)'});
            view.Slot = view.choiceRow('BoatSlot列', {'(未選択)'});
            view.Batch = view.choiceRow('バッチ列（任意）', {'(バッチ列なし：1Run)'});
            view.Targets = view.listRow('目的変数（複数選択可）', {'(入力待ち)'}, {});
            view.Methods = view.listRow('比較する方式（Ctrl / Commandで選択）', view.Constants.Labels, view.Constants.Labels);
            view.Methods.ItemsData = view.Constants.Methods; view.Methods.Value = view.Constants.Methods;
            view.Minimum = view.numberRow('予測Slotの下限', 1, [1, view.Constants.MaximumSlot], true);
            view.Maximum = view.numberRow('予測Slotの上限', 1, [1, view.Constants.MaximumSlot], true);
            view.Step = view.numberRow('Slotの間隔', 1, [1, view.Constants.MaximumSlot], true);
            view.RBFWidth = view.numberRow('RBF幅（0=自動）', view.Constants.DefaultRBFWidth, [0, Inf], false);
            view.RBFRidge = view.numberRow('RBF正則化', view.Constants.DefaultRBFRidge, [view.Constants.MinimumRBFRidge, view.Constants.MaximumRBFRidge], false);
            view.Extrapolate = uicheckbox(view.Controls, 'Text', '計測範囲外も予測する（外挿）', 'Value', false);
            view.Confirm = uibutton(view.Controls, 'Text', '列・バッチ区分・予測範囲を確認', 'ButtonPushedFcn', @(~, ~) view.confirm());
            view.Run = uibutton(view.Controls, 'Text', 'バッチごとに比較・補間', 'FontWeight', 'bold', 'ButtonPushedFcn', @(~, ~) view.run());
            view.Messages = uitextarea(view.Controls, 'Editable', 'off', 'Value', {'実行待ち'});
            parameters = {view.Wafer, view.Slot, view.Batch, view.Targets, view.Methods, view.Minimum, view.Maximum, view.Step, view.RBFWidth, view.RBFRidge, view.Extrapolate};
            for index = 1:numel(parameters), parameters{index}.ValueChangedFcn = @(~, ~) view.changed(); end
            view.Slot.ValueChangedFcn = @(~, ~) view.slotChanged();
            view.Right = uigridlayout(view.Layout, [4, 1]); view.Right.RowHeight = {62, 34, '1x', 34};
            view.Headline = uilabel(view.Right, 'Text', '内部Slotの検証RMSE: —    R²: —', 'WordWrap', 'on', 'FontWeight', 'bold');
            view.Selection = uidropdown(view.Right, 'Items', {'比較を実行してください'}, 'Enable', 'off', 'ValueChangedFcn', @(~, ~) view.select());
            view.Tabs = uitabgroup(view.Right); view.Tables = struct();
            fields = {'Predictions', 'Comparison', 'Metrics', 'Validation', 'Summary', 'Preview'};
            names = {'予測結果', 'モデル比較', '全評価指標', '検証予測', '選択モデル要約', '入力プレビュー'};
            for index = 1:numel(fields)
                tab = uitab(view.Tabs, 'Title', names{index}); grid = uigridlayout(tab, [1, 1]); view.Tables.(fields{index}) = uitable(grid, 'Data', table());
            end
            tab = uitab(view.Tabs, 'Title', 'グラフ'); grid = uigridlayout(tab, [1, 1]); view.PlotTabs = uitabgroup(grid); view.Charts = cell(1, 3);
            for index = 1:3
                tab = uitab(view.PlotTabs, 'Title', view.ChartNames{index}); grid = uigridlayout(tab, [1, 1]); view.Charts{index} = uiaxes(grid);
            end
            exports = uigridlayout(view.Right, [1, 3]); exports.Padding = [0, 0, 0, 0];
            uibutton(exports, 'Text', '表示中の表を保存', 'ButtonPushedFcn', @(~, ~) view.exportTable());
            uibutton(exports, 'Text', 'グラフをPNGに保存', 'ButtonPushedFcn', @(~, ~) view.exportFigure());
            view.CopyFigure = uibutton(exports, 'Text', 'グラフをコピー', 'ButtonPushedFcn', @(~, ~) view.copyFigure());
            view.resize(window.Position(3));
        end
        function importSource(view, source)
            view.Data = source; view.Source.Text = sprintf('%s / %d行', view.fileName(), size(source.Cells, 1));
            choices = [{'(未選択)'}, source.Headers]; view.Wafer.Items = choices; view.Slot.Items = choices;
            view.Batch.Items = [{'(バッチ列なし：1Run)'}, source.Headers];
            view.Wafer.Value = view.matchColumn({'WaferId', 'WaferID', 'Wafer_Id'}, '(未選択)');
            view.Slot.Value = view.matchColumn({'BoatSlot', 'Boat_Slot'}, '(未選択)');
            view.Batch.Value = view.matchColumn({'バッチ', 'Batch', 'BatchId', 'RunId'}, '(バッチ列なし：1Run)');
            view.Targets.Items = source.Headers;
            view.Targets.Value = source.Headers(~cellfun(@isempty, regexpi(source.Headers, '膜厚|屈折率|thickness|refractive')));
            preview = source.Cells(1:min(100, size(source.Cells, 1)), :);
            for index = 1:numel(preview)
                value = preview{index};
                if isempty(value) || (isscalar(value) && ismissing(value)), preview{index} = ''; end
            end
            view.Tables.Preview.Data = preview; view.Tables.Preview.ColumnName = source.Headers; view.slotChanged();
        end
        function slotChanged(view)
            if ~isempty(view.Data) && ~strcmp(view.Slot.Value, '(未選択)')
                try
                    slots = extract_numeric_columns(view.Data, {view.Slot.Value}); view.Minimum.Value = min(slots); view.Maximum.Value = max(slots);
                catch
                    % 入力不備の詳細は確認ボタンでまとめて表示する。
                end
            end
            view.changed();
        end
        function changed(view)
            view.Confirmed = false; view.clear(); view.Messages.Value = {'入力・条件を変更しました。列・バッチ区分・予測範囲を確認してください。'};
        end
        function clear(view)
            view.Report = [];
            for name = {'Predictions', 'Comparison', 'Metrics', 'Validation', 'Summary'}, view.Tables.(name{1}).Data = table(); end
            for index = 1:numel(view.Charts), cla(view.Charts{index}, 'reset'); end
            set(view.Selection, 'Items', {'比較を実行してください'}, 'ItemsData', [], 'Enable', 'off'); view.Headline.Text = '内部Slotの検証RMSE: —    R²: —';
        end
        function confirm(view)
            try
                data = view.preparedData(); view.querySlots();
                if isempty(view.Methods.Value), error('furnace:method', '比較方式を1個以上選択してください。'); end
                view.Confirmed = true;
                view.Messages.Value = {sprintf('%dバッチ・%d計測項目。各Runを別々に補間します。', numel(unique(data.Batch)), numel(data.TargetNames)); ...
                    'WaferIdの対応と予測範囲を確認済みです。実行できます。'};
            catch err
                view.showError(err);
            end
        end
        function run(view)
            started = tic; progress = []; entry = struct('Function', 'furnace_interpolation', 'Status', 'started');
            try
                require_r2025b();
                if ~view.Confirmed, error('furnace:unconfirmed', '列・バッチ区分・予測範囲の確認ボタンを押してください。'); end
                data = view.preparedData(); query = view.querySlots(); options = view.evaluationOptions();
                entry.InputFile = view.fileName(); entry.Rows = numel(data.Slots); entry.Kernel = strjoin(string(view.Methods.Value), ',');
                view.clear(); controls_cleanup = view.Lock(); %#ok<NASGU>
                progress = uiprogressdlg(view.Window, 'Title', '炉内補間', 'Message', 'バッチごとの計測データを準備中', 'Indeterminate', 'on', 'Cancelable', 'on');
                progress_cleanup = onCleanup(@() view.closeProgress(progress));
                report = interpolate_furnace_batches(data, query, view.Methods.Value, options, @(event) view.progress(progress, event));
                clear progress_cleanup;
                view.showReport(report); entry.Status = 'completed'; clear controls_cleanup;
            catch err
                view.closeProgress(progress); entry.Status = ['failed:' err.identifier]; view.showError(err);
            end
            entry.ElapsedSeconds = toc(started);
            try
                write_training_log(view.LogFolder, entry);
            catch err
                view.Messages.Value = [status_lines(view.Messages.Value); {['ログ保存失敗: ' err.message]}];
            end
        end
        function showReport(view, report)
            view.clear(); view.Report = report;
            view.Tables.Predictions.Data = report.Predictions; view.Tables.Comparison.Data = sortrows(report.Comparison, {'Batch', 'Target', 'Rank'});
            view.Tables.Metrics.Data = report.Metrics; view.Tables.Validation.Data = report.Validation;
            valid = find(~cellfun(@isempty, report.Series)); labels = cell(numel(valid), 1);
            for index = 1:numel(valid)
                item = report.Series{valid(index)}; labels{index} = char(item.Batch + " / " + item.Target + " / " + item.Method);
            end
            if ~isempty(valid)
                first = report.Series{valid(1)};
                best = find(report.Comparison.Batch == first.Batch & report.Comparison.Target == first.Target & report.Comparison.Rank == 1, 1);
                set(view.Selection, 'Items', labels, 'ItemsData', valid', 'Value', best, 'Enable', 'on'); view.select();
            else
                view.Headline.Text = '成功したモデルがありません。「モデル比較」のNoteを確認してください。';
            end
            view.Messages.Value = {sprintf('成功 %d / %d。評価の順位はバッチ・目的変数ごとです。', numel(valid), height(report.Comparison)); ...
                '両端の計測Slotを残し、内部Slotを1点ずつ外して検証しました。'; ...
                '外挿は別表示。GPRの95%区間は応答の予測区間です。採用前に別の実測でも確認してください。'; ...
                '生成したSlotに入力のWaferIdがない場合、WaferIdは空欄です。予測表・評価表・PNGを保存できます。'};
            apply_app_theme(view.Layout, view.Settings.Theme);
        end
        function select(view)
            if isempty(view.Report) || strcmp(view.Selection.Enable, 'off'), return; end
            item = view.Report.Series{view.Selection.Value}; comparison = view.Report.Comparison;
            selected = comparison.Batch == item.Batch & comparison.Target == item.Target & comparison.Method == item.Method;
            view.Headline.Text = sprintf('%s / %s / %s\n内部Slot検証 RMSE: %.6g    R²: %.6g（n=%d）', ...
                item.Batch, item.Target, item.Method, comparison.RMSE(selected), comparison.R2(selected), comparison.ValidationSlots(selected));
            view.Tables.Summary.Data = summarize_model_columns([item.Slots, item.Actual, item.ValidationPrediction, item.Actual - item.ValidationPrediction, item.TrainingPrediction], ...
                ["BoatSlot", "Actual", "ValidationPredicted", "ValidationResidual", "TrainingPredicted"]);
            ax = view.Charts{1}; cla(ax, 'reset'); hold(ax, 'on');
            for index = 1:numel(view.Report.Series)
                other = view.Report.Series{index};
                if ~isempty(other) && other.Batch == item.Batch && other.Target == item.Target
                    inside = other.Prediction; inside(other.Outside) = NaN;
                    curve = plot(ax, other.Query, inside, '-', 'DisplayName', char(other.Method));
                    outside = other.Prediction; outside(~other.Outside) = NaN;
                    plot(ax, other.Query, outside, '--', 'Marker', '.', 'Color', curve.Color, 'HandleVisibility', 'off');
                end
            end
            finite = all(isfinite(item.Interval), 2);
            if any(finite)
                x = item.Query(finite); lower = item.Interval(finite, 1); upper = item.Interval(finite, 2);
                fill(ax, [x; flipud(x)], [lower; flipud(upper)], [0.3, 0.5, 0.8], 'FaceAlpha', 0.12, 'EdgeColor', 'none', 'DisplayName', '選択GPRの応答95%予測区間');
            end
            measurement_color = [0.1, 0.1, 0.1];
            if strcmp(view.Settings.Theme, 'ダーク'), measurement_color = [0.95, 0.95, 0.95]; end
            scatter(ax, item.Slots, item.Actual, 36, measurement_color, 'filled', 'DisplayName', '計測値');
            xline(ax, min(item.Slots), ':', 'HandleVisibility', 'off'); xline(ax, max(item.Slots), ':', 'HandleVisibility', 'off');
            xlabel(ax, 'BoatSlot'); ylabel(ax, char(item.Target), 'Interpreter', 'none'); title(ax, char(item.Batch + " / " + item.Target), 'Interpreter', 'none');
            legend(ax, 'Location', 'best', 'Interpreter', 'none'); grid(ax, 'on');
            selected = comparison.Batch == item.Batch & comparison.Target == item.Target & comparison.Status == "成功";
            scores = sortrows(comparison(selected, :), 'Rank'); ax = view.Charts{2}; cla(ax, 'reset'); bar(ax, scores.RMSE);
            ax.XTick = 1:height(scores); ax.XTickLabel = scores.Method; ax.XTickLabelRotation = 25; ax.TickLabelInterpreter = 'none'; ylabel(ax, '内部Slot検証RMSE'); grid(ax, 'on');
            ax = view.Charts{3}; cla(ax, 'reset'); scatter(ax, item.Slots, item.Actual - item.ValidationPrediction, 30, 'filled'); yline(ax, 0, '--');
            xlabel(ax, '検証したBoatSlot（両端を除く）'); ylabel(ax, 'Actual - validation predicted'); grid(ax, 'on');
            apply_app_theme(view.Layout, view.Settings.Theme);
        end
        function data = currentTable(view)
            table_view = findobj(view.Tabs.SelectedTab, 'Type', 'uitable'); data = table();
            if ~isempty(table_view) && ~isequal(table_view(1), view.Tables.Preview), data = table_view(1).Data; end
        end
        function resize(view, width)
            if width < 1100
                view.Layout.RowHeight = {280, '1x'}; view.Layout.ColumnWidth = {'1x'};
                view.Controls.Layout.Row = 1; view.Controls.Layout.Column = 1; view.Right.Layout.Row = 2; view.Right.Layout.Column = 1;
            else
                view.Layout.RowHeight = {'1x'}; view.Layout.ColumnWidth = {380, '1x'};
                view.Controls.Layout.Row = 1; view.Controls.Layout.Column = 1; view.Right.Layout.Row = 1; view.Right.Layout.Column = 2;
            end
        end
        function applySettings(view, settings)
            view.Settings = settings; view.changed(); apply_app_theme(view.Layout, settings.Theme);
        end
        function options = evaluationOptions(view)
            options = struct('RBFWidth', view.RBFWidth.Value, 'RBFRidge', view.RBFRidge.Value, ...
                'AllowExtrapolation', view.Extrapolate.Value, 'Bins', view.Settings.Bins);
        end
        function setBusy(view, busy)
            view.Run.Enable = matlab.lang.OnOffSwitchState(~busy);
            view.Selection.Enable = matlab.lang.OnOffSwitchState(~busy && ~isempty(view.Report) && any(~cellfun(@isempty, view.Report.Series)));
        end
    end
    methods (Access = private)
        function field = choiceRow(view, label, items)
            row = uigridlayout(view.Controls, [1, 2]); row.Padding = [0, 0, 0, 0]; row.ColumnWidth = {140, '1x'};
            uilabel(row, 'Text', label); field = uidropdown(row, 'Items', items);
        end
        function field = listRow(view, label, items, value)
            row = uigridlayout(view.Controls, [2, 1]); row.Padding = [0, 0, 0, 0]; row.RowHeight = {20, '1x'};
            uilabel(row, 'Text', label); field = uilistbox(row, 'Items', items, 'Value', value, 'Multiselect', 'on');
        end
        function field = numberRow(view, label, value, limits, integer)
            row = uigridlayout(view.Controls, [1, 2]); row.Padding = [0, 0, 0, 0]; row.ColumnWidth = {'1.2x', '1x'};
            uilabel(row, 'Text', label); field = uieditfield(row, 'numeric', 'Value', value, 'Limits', limits, 'RoundFractionalValues', matlab.lang.OnOffSwitchState(integer));
        end
        function name = matchColumn(view, candidates, fallback)
            name = fallback;
            for index = 1:numel(candidates)
                match = find(strcmpi(view.Data.Headers, candidates{index}), 1);
                if ~isempty(match), name = view.Data.Headers{match}; return; end
            end
        end
        function data = preparedData(view)
            if isempty(view.Data), error('furnace:noInput', '入力ファイルを選択してください。'); end
            batch = view.Batch.Value; if strcmp(batch, '(バッチ列なし：1Run)'), batch = ''; end
            data = prepare_furnace_data(view.Data, view.Wafer.Value, view.Slot.Value, view.Targets.Value, batch);
        end
        function query = querySlots(view)
            if view.Minimum.Value > view.Maximum.Value, error('furnace:range', '予測Slotの下限を上限以下にしてください。'); end
            count = floor((view.Maximum.Value - view.Minimum.Value) / view.Step.Value) + 1;
            if count > view.Constants.MaximumQuerySlots, error('furnace:querySize', '予測位置は%dSlotまでです。', view.Constants.MaximumQuerySlots); end
            query = (view.Minimum.Value:view.Step.Value:view.Maximum.Value)';
        end
        function name = fileName(view)
            [~, base, extension] = fileparts(view.Data.FileName); name = [base extension];
        end
        function load(view)
            try
                [name, folder] = uigetfile({'*.xlsx;*.csv', 'Excel / CSV'}, '炉内補間の入力', view.Settings.SaveFolder); if isequal(name, 0), return; end
                path = fullfile(folder, name); [~, ~, extension] = fileparts(name); sheet = 1;
                if strcmpi(extension, '.xlsx')
                    sheets = sheetnames(path); [choice, accepted] = listdlg('ListString', cellstr(sheets), 'SelectionMode', 'single', 'PromptString', 'シートを選択');
                    if ~accepted, return; end; sheet = char(sheets(choice));
                end
                answer = inputdlg('ヘッダーの行番号', '入力設定', 1, {'1'}); if isempty(answer), return; end
                view.importSource(read_furnace_data(path, sheet, str2double(answer{1})));
            catch err
                view.showError(err);
            end
        end
        function progress(~, progress, event)
            progress.Message = sprintf('バッチ %d / %d：%s\n%s / %s\n%s（学習 %d / 最大%d）', ...
                event.BatchIndex, event.BatchCount, event.Batch, event.Target, event.Method, event.Stage, event.Index, event.Total);
            drawnow; if progress.CancelRequested, error('AnalysisApp:cancelled', '炉内補間を中止しました。今回の部分結果は保存しません。'); end
        end
        function closeProgress(~, progress)
            if ~isempty(progress) && isvalid(progress), close(progress); end
        end
        function showError(view, err)
            view.Messages.Value = [status_lines(view.Messages.Value); status_lines(err.message)]; uialert(view.Window, err.message, '炉内補間を中止しました', 'Icon', 'error');
        end
        function exportTable(view)
            try
                data = view.currentTable(); if isempty(data), error('furnace:noResult', '保存する結果・評価・要約の表を選択してください。'); end
                [name, folder] = uiputfile({'*.csv', 'CSV'; '*.xlsx', 'Excel'}, '炉内補間の表を保存', fullfile(view.Settings.SaveFolder, 'furnace_result.csv'));
                if isequal(name, 0), return; end; writetable(data, fullfile(folder, name));
            catch err
                view.showError(err);
            end
        end
        function exportFigure(view)
            try
                if isempty(view.Report) || isempty(view.Charts{1}.Children), error('furnace:noChart', '補間のグラフがありません。'); end
                [choice, accepted] = listdlg('ListString', view.ChartNames, 'SelectionMode', 'single', 'PromptString', '保存する図'); if ~accepted, return; end
                [name, folder] = uiputfile('*.png', '炉内補間の図を保存', fullfile(view.Settings.SaveFolder, 'furnace_chart.png')); if isequal(name, 0), return; end
                view.Tabs.SelectedTab = view.PlotTabs.Parent.Parent; view.PlotTabs.SelectedTab = ancestor(view.Charts{choice}, 'uitab'); drawnow;
                exportgraphics(view.Charts{choice}, fullfile(folder, name), 'Resolution', 150);
            catch err
                view.showError(err);
            end
        end
        function copyFigure(view)
            try
                copied_name = copy_app_chart(view.Charts, view.ChartNames);
                if ~isempty(copied_name)
                    view.Messages.Value = [status_lines(view.Messages.Value); {['クリップボードにコピーしました: ' copied_name]}];
                end
            catch err
                view.showError(err);
            end
        end
    end
end
