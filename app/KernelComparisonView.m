classdef KernelComparisonView < handle
    properties (SetAccess = private)
        Tab
        Kernels
        Folds
        Seed
        Start
        Selection
        Save
        Summary
        Metrics
        Predictions
        FoldMetrics
        ColumnSummary
        Tabs
        Charts
        ChartNames = {'カーネル比較 RMSE', '選択モデル 検証予測', '選択モデル 検証残差'}
        Report = []
    end
    properties (Access = private)
        Actual
        Inputs
        SourceRows
        InputNames
        Message
    end
    methods
        function view = KernelComparisonView(parent, kernels, default_kernel, run_callback, save_callback)
            view.Tab = uitab(parent, 'Title', 'カーネル比較');
            layout = uigridlayout(view.Tab, [4, 1]); layout.RowHeight = {166, 36, 54, '1x'};
            controls = uigridlayout(layout, [4, 3]); controls.Padding = [0, 0, 0, 0];
            controls.ColumnWidth = {'1.3x', '1x', '1x'}; controls.RowHeight = {30, 30, 34, 42};
            chosen = unique([{default_kernel}, {'matern32'}], 'stable');
            if numel(chosen) < 2, chosen = kernels(1:2); end
            view.Kernels = uilistbox(controls, 'Items', kernels, 'Multiselect', 'on', 'Value', chosen, ...
                'Tooltip', 'Ctrl（MacはCommand）を押しながら2個以上選択。Shiftで範囲選択。', 'ValueChangedFcn', @(~, ~) view.clear());
            view.Kernels.Layout.Row = [1, 4]; view.Kernels.Layout.Column = 1;
            label = uilabel(controls, 'Text', '検証の分割数（2〜10）'); label.Layout.Row = 1; label.Layout.Column = 2;
            view.Folds = uieditfield(controls, 'numeric', 'Value', 5, 'Limits', [2, 10], 'RoundFractionalValues', 'on', 'ValueChangedFcn', @(~, ~) view.clear());
            view.Folds.Layout.Row = 1; view.Folds.Layout.Column = 3;
            label = uilabel(controls, 'Text', '比較用 seed'); label.Layout.Row = 2; label.Layout.Column = 2;
            view.Seed = uieditfield(controls, 'numeric', 'Value', 0, 'Limits', [0, 2^32 - 1], 'RoundFractionalValues', 'on', 'ValueChangedFcn', @(~, ~) view.clear());
            view.Seed.Layout.Row = 2; view.Seed.Layout.Column = 3;
            view.Start = uibutton(controls, 'Text', '選択したカーネルを一括比較', 'FontWeight', 'bold', 'ButtonPushedFcn', @(~, ~) run_callback());
            view.Start.Layout.Row = 3; view.Start.Layout.Column = [2, 3];
            label = uilabel(controls, 'Text', 'Ctrl / Command で複数選択。fit_methodは左欄を共通使用。', 'WordWrap', 'on');
            label.Layout.Row = 4; label.Layout.Column = [2, 3];
            selection_row = uigridlayout(layout, [1, 3]); selection_row.Padding = [0, 0, 0, 0]; selection_row.ColumnWidth = {70, '1x', 160};
            uilabel(selection_row, 'Text', '採用候補');
            view.Selection = uidropdown(selection_row, 'Items', {'比較を実行してください'}, 'Enable', 'off', 'ValueChangedFcn', @(~, ~) view.select());
            view.Save = uibutton(selection_row, 'Text', '選択モデルをMAT保存', 'Enable', 'off', 'ButtonPushedFcn', @(~, ~) save_callback());
            view.Message = uilabel(layout, 'WordWrap', 'on', 'Text', '同じ分割の未使用行で8指標を評価します。順位は検証RMSEの小さい順です。通常の「実行」は左欄の1種類だけを学習します。');
            view.Tabs = uitabgroup(layout);
            view.Summary = view.tableTab('比較一覧'); view.Metrics = view.tableTab('全評価指標');
            view.Predictions = view.tableTab('検証予測'); view.FoldMetrics = view.tableTab('分割別'); view.ColumnSummary = view.tableTab('選択モデル要約');
            charts_tab = uitab(view.Tabs, 'Title', '比較グラフ'); chart_layout = uigridlayout(charts_tab, [1, 1]);
            chart_tabs = uitabgroup(chart_layout); view.Charts = cell(1, 3);
            for index = 1:3
                tab = uitab(chart_tabs, 'Title', view.ChartNames{index}); grid = uigridlayout(tab, [1, 1]); view.Charts{index} = uiaxes(grid);
            end
        end
        function clear(view)
            view.Report = []; view.Actual = []; view.Inputs = []; view.SourceRows = []; view.InputNames = [];
            for field = {'Summary', 'Metrics', 'Predictions', 'FoldMetrics', 'ColumnSummary'}, view.(field{1}).Data = table(); end
            set(view.Selection, 'Items', {'比較を実行してください'}, 'ItemsData', [], 'Enable', 'off'); view.Save.Enable = 'off';
            for index = 1:numel(view.Charts), cla(view.Charts{index}, 'reset'); end
            view.Message.Text = '同じ分割の未使用行で8指標を評価します。順位は検証RMSEの小さい順です。通常の「実行」は左欄の1種類だけを学習します。';
        end
        function showReport(view, report, inputs, actual, source_rows, input_names)
            view.clear(); view.Report = report; view.Inputs = inputs; view.Actual = actual(:);
            view.SourceRows = source_rows(:); view.InputNames = string(input_names(:))';
            view.Summary.Data = sortrows(report.Summary, 'Rank');
            view.Metrics.Data = report.Metrics; view.FoldMetrics.Data = report.FoldMetrics;
            successful = find(report.Summary.Status == "成功");
            [~, order] = sort(report.Summary.Rank(successful)); successful = successful(order);
            view.Message.Text = sprintf('%d分割・seed=%d：成功 %d / %d。順位は検証RMSE。選定にも使った検証値なので、採用後は独立データで確認してください。', ...
                report.Folds, report.Seed, numel(successful), height(report.Summary));
            if isempty(successful), return; end
            set(view.Selection, 'Items', cellstr(report.Summary.Kernel(successful)), 'ItemsData', successful', 'Value', successful(1), 'Enable', 'on');
            view.Save.Enable = 'on';
            ax = view.Charts{1}; bar(ax, report.Summary.RMSE(successful)); ax.XTick = 1:numel(successful);
            ax.XTickLabel = report.Summary.Kernel(successful); ax.XTickLabelRotation = 25; ax.TickLabelInterpreter = 'none';
            ylabel(ax, '検証RMSE'); title(ax, '未使用行への予測誤差（小さい順）'); grid(ax, 'on'); view.select();
        end
        function index = selectedIndex(view)
            if isempty(view.Report) || strcmp(view.Selection.Enable, 'off')
                error('KernelComparisonView:noModel', '比較に成功したモデルを選択してください。');
            end
            index = view.Selection.Value;
        end
        function data = currentTable(view)
            table_view = findobj(view.Tabs.SelectedTab, 'Type', 'uitable');
            data = table(); if ~isempty(table_view), data = table_view(1).Data; end
        end
        function setBusy(view, busy)
            enabled = matlab.lang.OnOffSwitchState(~busy);
            view.Start.Enable = enabled; view.Kernels.Enable = enabled; view.Folds.Enable = enabled; view.Seed.Enable = enabled;
            view.Selection.Enable = matlab.lang.OnOffSwitchState(~busy && ~isempty(view.Report) && any(view.Report.Summary.Status == "成功"));
            view.Save.Enable = view.Selection.Enable;
        end
    end
    methods (Access = private)
        function table_view = tableTab(view, title_text)
            tab = uitab(view.Tabs, 'Title', title_text); layout = uigridlayout(tab, [1, 1]); table_view = uitable(layout, 'Data', table());
        end
        function select(view)
            index = view.selectedIndex(); report = view.Report;
            oof = report.OOFPredictions(:, index); training = report.TrainingPredictions(:, index); residual = view.Actual - oof;
            view.Predictions.Data = table(view.SourceRows, report.FoldId, view.Actual, oof, residual, training, view.Actual - training, ...
                'VariableNames', {'SourceRow', 'Fold', 'Actual', 'ValidationPredicted', 'ValidationResidual', 'TrainingPredicted', 'TrainingResidual'});
            view.ColumnSummary.Data = summarize_model_columns([view.Inputs, view.Actual, oof, residual, training, view.Actual - training], ...
                [view.InputNames, "Actual", "ValidationPredicted", "ValidationResidual", "TrainingPredicted", "TrainingResidual"]);
            ax = view.Charts{2}; cla(ax, 'reset'); scatter(ax, view.Actual, oof, 20, 'filled'); hold(ax, 'on');
            limits = [min([view.Actual; oof]), max([view.Actual; oof])]; plot(ax, limits, limits, '--');
            xlabel(ax, 'Actual'); ylabel(ax, 'Validation predicted'); title(ax, char(report.Summary.Kernel(index)), 'Interpreter', 'none'); grid(ax, 'on');
            ax = view.Charts{3}; cla(ax, 'reset'); scatter(ax, oof, residual, 20, 'filled'); yline(ax, 0, '--');
            xlabel(ax, 'Validation predicted'); ylabel(ax, 'Actual - predicted'); title(ax, '選択モデルの検証残差'); grid(ax, 'on');
        end
    end
end
