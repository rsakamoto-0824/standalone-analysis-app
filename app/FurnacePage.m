classdef FurnacePage < AppPage
    % 炉内補間の画面。LP-CVDのBoatSlotと膜厚・屈折率などの関係を、成膜Run（バッチ）ごとに補間する。
    % 学習画面と同じく、① データ → ② 列 → ③ 条件・実行 → ④ 結果の比較・保存 の順に進む。
    properties (SetAccess = private)
        Steps
        StepTabs = struct()
        Source
        Preview
        Wafer
        Slot
        Batch
        Targets
        ConfirmState
        Confirmed = false
        Methods
        Minimum
        Maximum
        Step
        Extrapolate
        SettingInfo
        Plan
        RunButton
        Selection
        ColorColumn
        Result
        Charts = {}
        Report = []
        ReportSource = []
    end
    properties (Access = private)
        Constants
    end
    properties (Constant)
        NONE = '(未選択)'
        NO_BATCH = '(バッチ列なし：ファイル全体を1Runとして扱う)'
        SINGLE_COLOR = '(単色)'
        WAFER_NAMES = {'WaferId', 'WaferID', 'Wafer_Id'}
        SLOT_NAMES = {'BoatSlot', 'Boat_Slot'}
        BATCH_NAMES = {'バッチ', 'Batch', 'BatchId', 'RunId'}
        TARGET_PATTERN = '膜厚|屈折率|thickness|refractive'
        SAMPLE_FILE = 'ProcessInsight_Samples.xlsx'
        SAMPLE_SHEET = 'Furnace'
        CHART_NAMES = {'炉内プロファイル比較', '内部Slot検証のRMSE', '選択モデルの検証残差'}
        TABLE_PREDICTIONS = '予測結果'
        TABLE_COMPARISON = 'モデル比較'
        TABLE_METRICS = '全評価指標'
        TABLE_VALIDATION = '検証予測'
        TABLE_SUMMARY = '選択モデル要約'
    end
    methods
        function page = FurnacePage(app, parent)
            page@AppPage(app, parent);
            page.Constants = furnace_constants();
            page.Steps = uitabgroup(page.Body);
            page.buildDataStep(); page.buildColumnStep(); page.buildConditionStep(); page.buildResultStep();
            page.updateConfirmState();
            page.message('「① データを開く」から始めます。入力は WaferId・BoatSlot・計測値の列です。計測値の空欄は未計測として扱います。');
        end

        % ---------- 操作の入口（テストからも使う） ----------
        function selectColumns(page, wafer, slot, targets, batch)
            if nargin < 5 || isempty(batch), batch = page.NO_BATCH; end
            page.Wafer.Value = wafer; page.Slot.Value = slot; page.Batch.Value = batch;
            page.Targets.Value = cellstr(string(targets(:)')); page.slotChanged();
        end
        function confirm(page)
            try
                data = page.preparedData(); page.querySlots();
                if isempty(page.Methods.Value), error('furnace:method', '「③ 条件を決めて実行」で、比べる方式を1つ以上選んでください。'); end
                page.Confirmed = true; page.updateConfirmState();
                page.message(sprintf('確認しました：%dバッチ（Run）・計測項目 %d個。各Runを別々に補間します。', ...
                    numel(unique(data.Batch)), numel(data.TargetNames)));
            catch err
                page.Confirmed = false; page.updateConfirmState(); page.showError(err);
            end
        end
        function run(page)
            started = tic; dialog = []; entry = struct('Function', 'furnace_interpolation', 'Status', 'started');
            try
                require_r2025b();
                if ~page.Confirmed
                    page.Steps.SelectedTab = page.StepTabs.Columns;
                    error('furnace:unconfirmed', '「② 列を選ぶ」で列とバッチ区分を確認してから実行してください。');
                end
                data = page.preparedData(); query = page.querySlots(); options = page.evaluationOptions();
                methods_selected = cellstr(string(page.Methods.Value));
                if isempty(methods_selected), error('furnace:method', '比べる方式を1つ以上選んでください。'); end
                entry.InputFile = page.Source.fileName(); entry.Rows = numel(data.Slots); entry.Kernel = strjoin(methods_selected, ',');
                entry.FitMethod = options.FitMethod;
                dialog = page.App.startProgress('炉内補間', 'バッチごとの計測データを準備しています。', true);
                progress_started = tic;
                report = interpolate_furnace_batches(data, query, methods_selected, options, @(event) page.reportProgress(dialog, event, progress_started));
                AnalysisController.closeProgress(dialog);
                page.ReportSource = page.Source.Data;
                page.showReport(report); entry.Status = 'completed';
            catch err
                AnalysisController.closeProgress(dialog); entry.Status = ['failed:' err.identifier]; page.showError(err);
            end
            entry.ElapsedSeconds = toc(started); page.App.logTraining(page, entry);
        end
        function saveSelected(page)
            try
                item = page.selectedItem();
                target = char(item.Batch + "_" + item.Target + "_" + item.Method);
                path = page.App.chooseSaveFile({'*.mat', '炉内補間モデル（*.mat）'}, '選択した炉内補間モデルを保存', ...
                    default_model_filename('furnace', target));
                if isempty(path), return; end
                page.saveSelectedTo(path);
            catch err
                page.showError(err);
            end
        end
        function report = saveSelectedTo(page, path)
            item = page.selectedItem();
            report = save_furnace_model(item, page.Report.Options, path);
            [~, base, extension] = fileparts(path);
            page.message(sprintf('保存して、保存前後の予測が一致することを確認しました: %s（専用の Furnace_Model 形式。制御用 Train_Model とは別です）', [base extension]));
        end
        function openSample(page)
            path = page.App.resourcePath('samples', page.SAMPLE_FILE);
            if ~isfile(path)
                page.showError(MException('furnace:noSample', 'サンプルファイルが見つかりません: %s', path)); return;
            end
            page.Source.open(path, page.SAMPLE_SHEET, 1);
        end
        function onSettingsChanged(page)
            page.SettingInfo.Text = page.settingText();
        end
    end

    methods (Access = private)
        % ================= 画面の作成 =================
        function buildDataStep(page)
            tab = uitab(page.Steps, 'Title', '① データを開く'); page.StepTabs.Data = tab;
            grid = uigridlayout(tab, [4, 1]); grid.RowHeight = {40, 70, '1x', 32};
            AppPage.hint(grid, ['WaferId・BoatSlot・計測値（膜厚、屈折率など）の列を持つ Excel / CSV を開きます。' ...
                '異なる成膜Runをまとめたファイルは、Runを区別するバッチ列を含めてください。対応付けたい未計測のWaferは、計測列だけ空欄にして含めます。']);
            page.Source = DataSourceControl(page, grid, @read_furnace_data);
            page.Preview = uitable(grid, 'RowName', 'numbered');
            page.Source.PreviewTable = page.Preview; page.Source.LoadedFcn = @(data) page.dataLoaded(data);
            row = uigridlayout(grid, [1, 3]); row.Padding = [0, 0, 0, 0]; row.ColumnWidth = {'1x', 190, 220};
            uilabel(row, 'Text', sprintf('表は先頭%d行の表示です。', DataSourceControl.PREVIEW_ROWS));
            uibutton(row, 'Text', 'サンプルデータを開く', 'ButtonPushedFcn', @(~, ~) page.openSample());
            AppPage.primaryButton(row, '次へ：② 列を選ぶ ▶', @(~, ~) page.goTo('Columns'));
        end
        function buildColumnStep(page)
            tab = uitab(page.Steps, 'Title', '② 列を選ぶ'); page.StepTabs.Columns = tab;
            grid = uigridlayout(tab, [2, 2]); grid.RowHeight = {'1x', 36}; grid.ColumnWidth = {'1x', '1x'};
            left = AppPage.section(grid, '識別する列');
            left_grid = uigridlayout(left, [5, 2]); left_grid.RowHeight = {30, 30, 30, 70, '1x'}; left_grid.ColumnWidth = {170, '1x'};
            uilabel(left_grid, 'Text', 'WaferId の列'); page.Wafer = uidropdown(left_grid, 'Items', {page.NONE}, 'Enable', 'off');
            uilabel(left_grid, 'Text', 'BoatSlot の列'); page.Slot = uidropdown(left_grid, 'Items', {page.NONE}, 'Enable', 'off');
            uilabel(left_grid, 'Text', 'バッチ（Run）の列'); page.Batch = uidropdown(left_grid, 'Items', {page.NO_BATCH}, 'Enable', 'off');
            label = AppPage.hint(left_grid, ['同時に処理した複数Lotは同じRunのプロファイルとして扱い、バッチの値が異なる行は別々に補間します。' ...
                'BoatSlot は正の整数です。同じバッチ内で WaferId・BoatSlot を重複させないでください。']);
            label.Layout.Column = [1, 2];
            AppPage.fillLastRow(left_grid);
            right = AppPage.section(grid, '目的変数（補間したい計測値の列）');
            right_grid = uigridlayout(right, [2, 1]); right_grid.RowHeight = {44, '1x'};
            AppPage.hint(right_grid, sprintf('複数選択は Ctrl キーを押しながらクリックします。各バッチ・各項目で%d点以上の計測Slotが必要です。', ...
                page.Constants.MinimumMeasuredSlots));
            page.Targets = uilistbox(right_grid, 'Items', {}, 'Value', {}, 'Multiselect', 'on', 'Enable', 'off');
            fields = {page.Wafer, page.Batch, page.Targets};
            for index = 1:numel(fields), fields{index}.ValueChangedFcn = @(~, ~) page.inputsChanged(); end
            page.Slot.ValueChangedFcn = @(~, ~) page.slotChanged();
            bottom = uigridlayout(grid, [1, 3]); bottom.Layout.Row = 2; bottom.Layout.Column = [1, 2];
            bottom.Padding = [0, 0, 0, 0]; bottom.ColumnWidth = {'1x', 170, 240};
            page.ConfirmState = AppPage.stateLabel(bottom);
            uibutton(bottom, 'Text', '列・バッチ区分を確認', 'FontWeight', 'bold', 'ButtonPushedFcn', @(~, ~) page.confirm());
            AppPage.primaryButton(bottom, '次へ：③ 条件を決めて実行 ▶', @(~, ~) page.goTo('Conditions'));
        end
        function buildConditionStep(page)
            tab = uitab(page.Steps, 'Title', '③ 条件を決めて実行'); page.StepTabs.Conditions = tab;
            grid = uigridlayout(tab, [2, 2]); grid.RowHeight = {'1x', 44}; grid.ColumnWidth = {'1x', '1x'};
            left = AppPage.section(grid, '比べる方式');
            left_grid = uigridlayout(left, [3, 1]); left_grid.RowHeight = {44, 150, '1x'};
            AppPage.hint(left_grid, '複数選ぶと、内部Slotを1点ずつ外した検証で比べます（Ctrl キーを押しながら複数選択）。GPRだけが予測区間を表示できます。');
            page.Methods = uilistbox(left_grid, 'Items', page.Constants.Labels, 'ItemsData', page.Constants.Methods, ...
                'Value', page.Constants.Methods, 'Multiselect', 'on', 'ValueChangedFcn', @(~, ~) page.inputsChanged());
            page.SettingInfo = AppPage.hint(left_grid, page.settingText());
            right = AppPage.section(grid, '予測するSlotの範囲');
            right_grid = uigridlayout(right, [6, 2]); right_grid.RowHeight = {44, 30, 30, 30, 30, '1x'}; right_grid.ColumnWidth = {'1.3x', '1x'};
            label = AppPage.hint(right_grid, 'BoatSlot の列を選ぶと、計測値の範囲を自動で入れます。必要に応じて変更してください。');
            label.Layout.Column = [1, 2];
            limits = [1, page.Constants.MaximumSlot];
            [~, page.Minimum] = AppPage.numberField(right_grid, '予測Slotの下限', 1, limits, true);
            [~, page.Maximum] = AppPage.numberField(right_grid, '予測Slotの上限', 1, limits, true);
            [~, page.Step] = AppPage.numberField(right_grid, 'Slotの間隔', 1, limits, true);
            page.Extrapolate = uicheckbox(right_grid, 'Text', '計測範囲の外側も予測する（外挿。精度は保証されません）', 'Value', false);
            page.Extrapolate.Layout.Column = [1, 2];
            fields = {page.Minimum, page.Maximum, page.Step, page.Extrapolate};
            for index = 1:numel(fields), fields{index}.ValueChangedFcn = @(~, ~) page.inputsChanged(); end
            AppPage.fillLastRow(right_grid);
            bottom = uigridlayout(grid, [1, 2]); bottom.Layout.Row = 2; bottom.Layout.Column = [1, 2];
            bottom.Padding = [0, 0, 0, 0]; bottom.ColumnWidth = {'1x', 280};
            page.Plan = AppPage.stateLabel(bottom);
            page.RunButton = AppPage.primaryButton(bottom, 'バッチごとに比較・補間を実行', @(~, ~) page.run());
        end
        function buildResultStep(page)
            tab = uitab(page.Steps, 'Title', '④ 結果を比べて保存'); page.StepTabs.Results = tab;
            grid = uigridlayout(tab, [2, 1]); grid.RowHeight = {30, '1x'};
            row = uigridlayout(grid, [1, 5]); row.Padding = [0, 0, 0, 0]; row.ColumnWidth = {110, '1.4x', 120, '1x', 200};
            uilabel(row, 'Text', '表示するモデル');
            page.Selection = uidropdown(row, 'Items', {'（③で実行すると選べます）'}, 'Enable', 'off', 'ValueChangedFcn', @(~, ~) page.select());
            uilabel(row, 'Text', '散布図の色の列', 'HorizontalAlignment', 'right');
            page.ColorColumn = uidropdown(row, 'Items', {page.SINGLE_COLOR}, 'ValueChangedFcn', @(~, ~) page.select());
            AppPage.primaryButton(row, '選択モデルをMAT保存', @(~, ~) page.saveSelected());
            holder = uigridlayout(grid, [1, 1]); holder.Padding = [0, 0, 0, 0];
            page.Result = ResultPanel(page, holder, '①〜③を進めて実行すると、ここに補間の結果を表示します。');
        end
        function text = settingText(page)
            settings = page.settings();
            text = sprintf('RBFの幅: %.6g（0＝自動） / 正則化: %.6g / GPRの Fit method: %s\n変更は「9 設定」で行います。', ...
                settings.RBFWidth, settings.RBFRidge, settings.FitMethod);
        end
        function goTo(page, step)
            page.Steps.SelectedTab = page.StepTabs.(step);
        end

        % ================= ① データ・② 列 =================
        function dataLoaded(page, data)
            headers = data.Headers; choices = [{page.NONE}, headers];
            set(page.Wafer, 'Items', choices, 'Value', page.matchColumn(headers, page.WAFER_NAMES, page.NONE), 'Enable', 'on');
            set(page.Slot, 'Items', choices, 'Value', page.matchColumn(headers, page.SLOT_NAMES, page.NONE), 'Enable', 'on');
            set(page.Batch, 'Items', [{page.NO_BATCH}, headers], 'Value', page.matchColumn(headers, page.BATCH_NAMES, page.NO_BATCH), 'Enable', 'on');
            selected = headers(~cellfun(@isempty, regexpi(headers, page.TARGET_PATTERN)));
            set(page.Targets, 'Items', headers, 'Value', selected, 'Enable', 'on');
            page.slotChanged();
            page.message(sprintf('%s を読み込みました（%d行）。次に「② 列を選ぶ」で列を確認します。', page.Source.fileName(), size(data.Cells, 1)));
        end
        function name = matchColumn(~, headers, candidates, fallback)
            name = fallback;
            for index = 1:numel(candidates)
                match = find(strcmpi(headers, candidates{index}), 1);
                if ~isempty(match), name = headers{match}; return; end
            end
        end
        function slotChanged(page)
            % BoatSlot の列が決まったら、計測範囲を予測範囲の初期値にする。
            if ~isempty(page.Source.Data) && ~strcmp(page.Slot.Value, page.NONE)
                try
                    slots = extract_numeric_columns(page.Source.Data, {page.Slot.Value});
                    page.Minimum.Value = min(slots); page.Maximum.Value = max(slots);
                catch
                    % 列の不備は「確認」でまとめて知らせる。
                end
            end
            page.inputsChanged();
        end
        function inputsChanged(page)
            page.Confirmed = false; page.updateConfirmState();
        end
        function updateConfirmState(page)
            if page.Confirmed
                page.setState(page.ConfirmState, sprintf('✓ 確認済み：目的変数 %d列 / %d行', numel(page.Targets.Value), size(page.Source.Data.Cells, 1)), true);
                page.setState(page.Plan, sprintf('方式 %d個で、バッチ・目的変数ごとに比べます。', numel(page.Methods.Value)), true);
            else
                text = '未確認：列を選び、「列・バッチ区分を確認」を押してください。';
                if isempty(page.Source.Data), text = '未確認：先に「① データを開く」でファイルを開いてください。'; end
                page.setState(page.ConfirmState, text, false);
                page.setState(page.Plan, '「② 列を選ぶ」で列とバッチ区分を確認すると実行できます。', false);
            end
        end
        function data = preparedData(page)
            if isempty(page.Source.Data), page.goTo('Data'); error('furnace:noInput', '「① データを開く」で入力ファイルを開いてください。'); end
            if strcmp(page.Wafer.Value, page.NONE) || strcmp(page.Slot.Value, page.NONE)
                error('furnace:columns', 'WaferId の列と BoatSlot の列を選んでください。');
            end
            if isempty(page.Targets.Value), error('furnace:targets', '目的変数（補間したい計測値の列）を選んでください。'); end
            batch = page.Batch.Value; if strcmp(batch, page.NO_BATCH), batch = ''; end
            data = prepare_furnace_data(page.Source.Data, page.Wafer.Value, page.Slot.Value, page.Targets.Value, batch);
        end
        function query = querySlots(page)
            if page.Minimum.Value > page.Maximum.Value, error('furnace:range', '予測Slotの下限を上限以下にしてください。'); end
            count = floor((page.Maximum.Value - page.Minimum.Value) / page.Step.Value) + 1;
            if count > page.Constants.MaximumQuerySlots
                error('furnace:querySize', '予測位置は%d Slotまでです。範囲を狭めるか、間隔を広げてください。', page.Constants.MaximumQuerySlots);
            end
            query = (page.Minimum.Value:page.Step.Value:page.Maximum.Value)';
        end
        function options = evaluationOptions(page)
            settings = page.settings();
            options = struct('RBFWidth', settings.RBFWidth, 'RBFRidge', settings.RBFRidge, 'FitMethod', settings.FitMethod, ...
                'AllowExtrapolation', page.Extrapolate.Value, 'Bins', settings.Bins);
        end
        function reportProgress(~, dialog, event, started)
            % バッチの順番と、そのバッチ内の学習回数から全体の進み具合を求める。
            within = 0; if event.Total > 0, within = min(event.Index / event.Total, 1); end
            [fraction, summary] = format_progress((event.BatchIndex - 1) + within, event.BatchCount, toc(started));
            dialog.Indeterminate = 'off'; dialog.Value = fraction;
            dialog.Message = sprintf('%s\nバッチ %d / %d：%s / %s / %s\n%s（学習 %d / 最大%d）', summary, ...
                event.BatchIndex, event.BatchCount, event.Batch, event.Target, event.Method, event.Stage, event.Index, event.Total);
            drawnow;
            if dialog.CancelRequested, error('AnalysisApp:cancelled', '炉内補間を中止しました。今回の結果は表示しません。'); end
        end

        % ================= ④ 結果 =================
        function showReport(page, report)
            panel = page.Result; panel.clear(); page.Report = report; page.Charts = cell(1, numel(page.CHART_NAMES));
            for index = 1:numel(page.CHART_NAMES), page.Charts{index} = panel.addAxes(page.CHART_NAMES{index}); end
            panel.setTable(page.TABLE_COMPARISON, display_metric_names(sortrows(report.Comparison, {'Batch', 'Target', 'Rank'})));
            panel.setTable(page.TABLE_PREDICTIONS, report.Predictions);
            panel.setTable(page.TABLE_METRICS, display_metric_names(report.Metrics));
            panel.setTable(page.TABLE_VALIDATION, report.Validation);
            valid = find(~cellfun(@isempty, report.Series)); labels = cell(numel(valid), 1);
            for index = 1:numel(valid)
                item = report.Series{valid(index)}; labels{index} = char(item.Batch + " / " + item.Target + " / " + item.Method);
            end
            set(page.ColorColumn, 'Items', [{page.SINGLE_COLOR}, page.ReportSource.Headers], 'Value', page.SINGLE_COLOR);
            page.goTo('Results');
            if isempty(valid)
                set(page.Selection, 'Items', {'（成功したモデルがありません）'}, 'ItemsData', [], 'Enable', 'off');
                panel.setHeadline(sprintf('成功したモデルがありません。「%s」の Note で理由を確認してください。', page.TABLE_COMPARISON));
                panel.showTable(page.TABLE_COMPARISON); page.App.applyTheme(); return;
            end
            first = report.Series{valid(1)};
            best = find(report.Comparison.Batch == first.Batch & report.Comparison.Target == first.Target & report.Comparison.Rank == 1, 1);
            selected = valid(1); if ~isempty(best) && ismember(best, valid), selected = best; end
            set(page.Selection, 'Items', labels, 'ItemsData', valid', 'Value', selected, 'Enable', 'on');
            page.select(); panel.showCharts();
            page.message(sprintf('成功 %d / %d。順位はバッチ・目的変数ごとです。両端の計測Slotを残し、内部Slotを1点ずつ外して検証しました。', ...
                numel(valid), height(report.Comparison)));
            page.message('入力にないSlotの WaferId は空欄です。GPRの95%区間は応答の予測区間です。採用前に別の実測でも確認してください。');
        end
        function item = selectedItem(page)
            if isempty(page.Report) || strcmp(page.Selection.Enable, 'off')
                error('furnace:noModel', '先に③で実行し、「④ 結果を比べて保存」で保存するモデルを選んでください。');
            end
            item = page.Report.Series{page.Selection.Value};
        end
        function select(page)
            if isempty(page.Report) || strcmp(page.Selection.Enable, 'off'), return; end
            try
                page.drawSelected(page.Report.Series{page.Selection.Value});
            catch err
                page.showError(err);
            end
        end
        function drawSelected(page, item)
            % 結果の表示には、実行時に使ったデータを使う（その後に別のファイルを開いても表示を保つ）。
            comparison = page.Report.Comparison; data = page.ReportSource; panel = page.Result;
            selected = comparison.Batch == item.Batch & comparison.Target == item.Target & comparison.Method == item.Method;
            panel.setHeadline(sprintf('%s / %s / %s\n内部Slot検証 RMSE: %.6g    R²: %.6g（n = %d）', ...
                item.Batch, item.Target, item.Method, comparison.RMSE(selected), comparison.R2(selected), comparison.ValidationSlots(selected)));
            panel.setTable(page.TABLE_SUMMARY, summarize_model_columns( ...
                [item.Slots, item.Actual, item.ValidationPrediction, item.Actual - item.ValidationPrediction, item.TrainingPrediction], ...
                ["BoatSlot", "Actual", "ValidationPredicted", "ValidationResidual", "TrainingPredicted"]));
            [known, row] = ismember(item.SourceRows, data.RowNumbers);
            if ~all(known), error('furnace:colorRows', '散布図の元ファイル行が見つかりません。③をもう一度実行してください。'); end
            source = struct('Headers', {data.Headers}, 'Cells', {data.Cells(row, :)});
            color_column = page.ColorColumn.Value;
            if ~any(strcmp([{page.SINGLE_COLOR}, data.Headers], color_column)), color_column = page.SINGLE_COLOR; end
            page.drawProfiles(page.Charts{1}, item, source, color_column);
            scores = sortrows(comparison(comparison.Batch == item.Batch & comparison.Target == item.Target & comparison.Status == "成功", :), 'Rank');
            ax = page.Charts{2}; cla(ax, 'reset'); bar(ax, scores.RMSE);
            ax.XTick = 1:height(scores); ax.XTickLabel = scores.Method; ax.XTickLabelRotation = 25; ax.TickLabelInterpreter = 'none';
            ylabel(ax, '内部Slot検証のRMSE（小さいほど良い）'); grid(ax, 'on');
            title(ax, char(item.Batch + " / " + item.Target), 'Interpreter', 'none');
            ax = page.Charts{3}; cla(ax, 'reset'); colorbar(ax, 'off'); hold(ax, 'on');
            color_scatter(ax, item.Slots, item.Actual - item.ValidationPrediction, source, color_column); yline(ax, 0, '--');
            xlabel(ax, '検証したBoatSlot（両端を除く）'); ylabel(ax, '実測 − 検証予測'); grid(ax, 'on');
            page.App.applyTheme();
        end
        function drawProfiles(page, ax, item, source, color_column)
            cla(ax, 'reset'); colorbar(ax, 'off'); hold(ax, 'on');
            for index = 1:numel(page.Report.Series)
                other = page.Report.Series{index};
                if isempty(other) || other.Batch ~= item.Batch || other.Target ~= item.Target, continue; end
                inside = other.Prediction; inside(other.Outside) = NaN;
                curve = plot(ax, other.Query, inside, '-', 'DisplayName', char(other.Method));
                if other.Method == item.Method, curve.LineWidth = 2; end
                % 計測範囲の外側（外挿）は破線で区別する。
                outside = other.Prediction; outside(~other.Outside) = NaN;
                plot(ax, other.Query, outside, '--', 'Marker', '.', 'Color', curve.Color, 'HandleVisibility', 'off');
            end
            finite = all(isfinite(item.Interval), 2);
            if any(finite)
                x = item.Query(finite); lower = item.Interval(finite, 1); upper = item.Interval(finite, 2);
                fill(ax, [x; flipud(x)], [lower; flipud(upper)], [0.3, 0.5, 0.8], 'FaceAlpha', 0.12, 'EdgeColor', 'none', ...
                    'DisplayName', '選択GPRの応答95%予測区間');
            end
            if strcmp(color_column, page.SINGLE_COLOR)
                measurement_color = [0.1, 0.1, 0.1];
                if strcmp(page.settings().Theme, 'ダーク'), measurement_color = [0.95, 0.95, 0.95]; end
                scatter(ax, item.Slots, item.Actual, 36, measurement_color, 'filled', 'DisplayName', '計測値');
            else
                points = color_scatter(ax, item.Slots, item.Actual, source, color_column); points.DisplayName = '計測値';
            end
            xline(ax, min(item.Slots), ':', 'HandleVisibility', 'off'); xline(ax, max(item.Slots), ':', 'HandleVisibility', 'off');
            xlabel(ax, 'BoatSlot'); ylabel(ax, char(item.Target), 'Interpreter', 'none');
            title(ax, char(item.Batch + " / " + item.Target + "（太線が選択中の方式）"), 'Interpreter', 'none');
            legend(ax, 'Location', 'best', 'Interpreter', 'none'); grid(ax, 'on');
        end
    end
end
