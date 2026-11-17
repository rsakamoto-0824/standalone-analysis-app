classdef ModelingPage < AppPage
    % APC・Swing Curve・汎用回帰の学習画面。
    % ① データ → ② 変数 → ③ 条件・実行 → ④ 結果の比較・保存 の順に、上のタブを左から進む。
    properties (SetAccess = private)
        Kind
        Steps
        StepTabs = struct()
        Source
        Preview
        Targets
        Mapper = []
        SwingMode = []
        ResistColumn = []
        Underlayers = []
        Predictors = []
        Order = {}
        OrderInfo = []
        MappingTable
        ConfirmState
        Confirmed = false
        Regressors = struct()
        PlsComponents = []
        Kernels
        FitInfo
        Period = struct()
        Folds
        Seed
        AlwaysValidate
        ComputeShap
        Plan
        RunButton
        ModelTable
        ResultGrid
        ExpandButton
        Result
        Records = {}
        SelectedRow = 0
        RunSequence = 0
    end
    properties (Access = private)
        SelectedOrderRow = 0
    end
    properties (Constant)
        TITLES = struct('apc', 'APC 学習', 'swing', 'Swing Curve学習', 'generic', '汎用回帰学習')
        SAMPLE_SHEETS = struct('apc', 'APC', 'swing', 'Swing_Base', 'generic', 'Generic')
        SAMPLE_FILE = 'ProcessInsight_Samples.xlsx'
        MODE_WITHOUT = '下地なし（膜厚のみ）'
        MODE_WITH = '下地あり（膜厚＋下地の説明変数）'
        DEFAULT_TARGET_NAMES = ["cd", "y", "膜厚", "屈折率"]
        DEFAULT_FOLDS = 5
        MODEL_TABLE_HEIGHT = 150
        SELECTED_ROW_COLOR = [0.80, 0.90, 1.00]
        CHART_COMPARISON = '条件の比較（RMSE）'
        CHART_PERIOD = '周期探索（周辺尤度）'
        TABLE_VERIFICATION = '保存後検証'
        TABLE_OUTPUT = '予測・SHAPの出力（入力と並べた表）'
        OUTPUT_FILE_PREFIX = 'Prediction_SHAP'
    end
    methods
        function page = ModelingPage(app, parent, kind)
            page@AppPage(app, parent);
            page.Kind = kind;
            page.Steps = uitabgroup(page.Body);
            page.buildDataStep(); page.buildVariableStep(); page.buildConditionStep(); page.buildResultStep();
            page.updateConfirmState(); page.refreshPlan();
            page.message('「① データを開く」から始めます。手元にデータがない場合は「サンプルデータを開く」で試せます。');
        end

        % ---------- ② 変数（テストからも使う操作の入口） ----------
        function selectTargets(page, names)
            page.Targets.Value = cellstr(string(names(:)')); page.variablesChanged();
        end
        function setSwingVariables(page, mode, resist_column, underlayers)
            if nargin < 4, underlayers = {}; end
            page.SwingMode.Value = mode; page.ResistColumn.Value = resist_column;
            page.Underlayers.Value = cellstr(string(underlayers(:)')); page.variablesChanged();
        end
        function selectPredictors(page, names)
            page.Predictors.Value = cellstr(string(names(:)')); page.Order = {}; page.variablesChanged();
        end
        function movePredictor(page, row, step)
            % 汎用回帰の説明変数の順序を、1行ずつ上（-1）または下（+1）へ動かす。
            target = row + step;
            if row < 1 || row > numel(page.Order) || target < 1 || target > numel(page.Order), return; end
            page.Order([row, target]) = page.Order([target, row]); page.SelectedOrderRow = target;
            page.variablesChanged();
        end
        function confirm(page)
            try
                page.validateVariables();
                page.Confirmed = true; page.updateConfirmState(); page.refreshPlan();
                page.message('列対応を確認しました。「③ 条件を決めて実行」へ進めます。');
            catch err
                page.Confirmed = false; page.updateConfirmState(); page.showError(err);
            end
        end

        % ---------- ③ 実行 ----------
        function runModeling(page)
            dialog = [];
            try
                if ~page.Confirmed
                    page.Steps.SelectedTab = page.StepTabs.Variables;
                    error('AnalysisApp:unconfirmed', '「② 変数を選ぶ」で列対応を確認してから実行してください。');
                end
                % ボタンを押したらすぐに進捗バーを表示する（入力の読取りにも時間がかかる場合があるため）。
                dialog = page.App.startProgress('モデリング・SHAP評価', '入力データと条件を確認しています。', true);
                data = page.Source.Data; settings = page.settings();
                if settings.Bins > 0, validate_bin_count(settings.Bins, 'AnalysisApp'); end
                [inputs, responses, names, targets] = modeling_input_data(data, page.currentMapping(), page.Targets.Value);
                conditions = page.conditions(numel(names));
                folds = page.validationFolds(numel(conditions));
                page.checkRowCount(size(inputs, 1), folds);
                period_options = page.periodOptions();
                options = struct('Folds', folds, 'Seed', page.Seed.Value, 'Bins', settings.Bins, 'ComputeShap', page.ComputeShap.Value);
                kind = page.Kind; trainer = page.App.Services.Trainer;
                services = struct('Trainer', @(x, y, condition, callback) trainer(kind, x, y, names, condition, period_options, callback), ...
                    'Predictor', page.App.Services.Predictor, 'Shap', page.App.Services.Shap);
                started = tic;
                dialog.Indeterminate = 'off'; dialog.Value = 0;
                dialog.Message = sprintf('学習を始めます（目的変数 %d列 × 条件 %d）。', numel(targets), numel(conditions));
                records = evaluate_modeling_batch(inputs, responses, names, targets, conditions, options, services, ...
                    @(event) page.reportProgress(dialog, event, started));
                AnalysisController.closeProgress(dialog);
                page.acceptRecords(records, data, period_options, toc(started));
            catch err
                AnalysisController.closeProgress(dialog); page.showError(err);
            end
        end

        % ---------- ④ 結果 ----------
        function selectRow(page, row)
            if row < 1 || row > numel(page.Records), return; end
            page.SelectedRow = row; page.highlightSelectedRow(); page.showRecord(page.Records{row});
        end
        function computeShapForSelected(page)
            dialog = [];
            try
                [record, row] = page.selectedRecord();
                dialog = page.App.startProgress('SHAP 解析', 'SHAP値を計算しています。');
                limit = min(size(record.Inputs, 1), page.App.Constants.MAX_SHAP_POINTS);
                [explainer, values] = page.App.Services.Shap(record.Model, record.Inputs(1:limit, :));
                if ~isequal(size(values), [limit, size(record.Inputs, 2)]) || any(~isfinite(values(:)))
                    error('modeling:shapShape', 'SHAP値の形状または数値が不正です。');
                end
                record.Shap = struct('Explainer', explainer, 'Values', values, 'Inputs', record.Inputs(1:limit, :));
                record.ShapStatus = '成功';
                page.Records{row} = record; page.App.Models.setRecord(record.Id, record);
                AnalysisController.closeProgress(dialog);
                page.refreshModelTable(); page.selectRow(row); page.Result.showCharts();
                page.message(sprintf('SHAPを計算しました（先頭%d行）: %s', limit, page.recordLabel(record)));
            catch err
                AnalysisController.closeProgress(dialog); page.showError(err);
            end
        end
        function saveSelected(page)
            try
                record = page.selectedRecord();
                kind = page.Kind; if isa(record.Model, 'ProcessRegressionModel'), kind = 'regression'; end
                path = page.App.chooseSaveFile({'*.mat', '学習済みモデル（*.mat）'}, ['選択モデルを保存: ' record.Target], ...
                    default_model_filename(kind, record.Target));
                if isempty(path), return; end
                page.saveSelectedTo(path);
            catch err
                page.showError(err);
            end
        end
        function report = saveSelectedTo(page, path)
            % 選んだ1モデルだけを、再学習せずに保存して検証する。
            [record, row] = page.selectedRecord();
            if isa(record.Model, 'ProcessRegressionModel')
                report = save_regression_model(record.Model, path);
            else
                save_train_model(record.Model, path);
                expected = struct('KernelFunction', record.Condition.Kernel, 'FitMethod', record.Condition.FitMethod, ...
                    'BasisFunction', 'constant', 'NumObservations', size(record.Inputs, 1));
                report = verify_saved_model(path, record.Model, page.Kind, expected);
            end
            record.Verification = report.Checks; record.SavedPath = path;
            page.Records{row} = record; page.App.Models.setRecord(record.Id, record);
            page.Result.setTable(page.TABLE_VERIFICATION, report.Checks); page.Result.showTable(page.TABLE_VERIFICATION);
            page.refreshModelTable(); page.highlightSelectedRow(); page.App.applyTheme();
            [~, base, extension] = fileparts(path);
            entry = page.logEntry(record); entry.SavePath = path; entry.Verification = table2struct(report.Checks);
            entry.Status = 'saved'; if ~report.Success, entry.Status = 'verification_failed'; end
            page.App.logTraining(page, entry);
            if ~report.Success
                error('AnalysisApp:verificationFailed', '%s（%s）。「%s」の表で不一致の項目を確認してください。', ...
                    page.App.Constants.INVALID_MODEL_MESSAGE, [base extension], page.TABLE_VERIFICATION);
            end
            page.message(sprintf('保存して検証に成功しました: %s（%s）', [base extension], page.recordLabel(record)));
            notice = page.App.releaseNotice();
            if ~isempty(notice), page.message(notice); end
        end
        function exportOutput(page)
            try
                record = page.selectedRecord();
                default_name = sprintf('%s_%s_%s.csv', page.OUTPUT_FILE_PREFIX, matlab.lang.makeValidName(record.Target), ...
                    matlab.lang.makeValidName(modeling_condition_label(record.Condition)));
                path = page.App.chooseSaveFile({'*.csv', 'CSV'; '*.xlsx', 'Excel'}, '予測・SHAPの出力を保存', default_name);
                if isempty(path), return; end
                page.exportOutputTo(path);
            catch err
                page.showError(err);
            end
        end
        function exportOutputTo(page, path)
            record = page.selectedRecord();
            write_result_table(page.outputTable(record), path);
            [~, base, extension] = fileparts(path);
            page.message(sprintf('予測・SHAPの出力を保存しました: %s（%s）', [base extension], page.recordLabel(record)));
            if isempty(record.Shap)
                page.message('このモデルはSHAPを計算していないため、SHAPの列はありません。「選択モデルのSHAPを計算」の後に保存すると含まれます。');
            elseif size(record.Shap.Values, 1) < numel(record.SourceRows)
                page.message(sprintf('SHAPは先頭%d行だけ計算しているため、それ以降の行のSHAPは空欄です。', size(record.Shap.Values, 1)));
            end
        end
        function exportModelList(page)
            try
                if isempty(page.Records), error('modeling:noRecord', '保存する一覧がありません。先に③で実行してください。'); end
                path = page.App.chooseSaveFile({'*.csv', 'CSV'; '*.xlsx', 'Excel'}, 'モデルの一覧を保存', 'model_list.csv');
                if isempty(path), return; end
                write_result_table(page.ModelTable.Data, path); page.message('モデルの一覧を保存しました。');
            catch err
                page.showError(err);
            end
        end
        function openSample(page)
            path = page.App.resourcePath('samples', page.SAMPLE_FILE);
            if ~isfile(path)
                page.showError(MException('modeling:noSample', 'サンプルファイルが見つかりません: %s', path)); return;
            end
            page.Source.open(path, page.SAMPLE_SHEETS.(page.Kind), 1);
        end
        function onSettingsChanged(page)
            page.FitInfo.Text = page.fitMethodText(); page.refreshPlan();
        end
    end

    methods (Access = private)
        % ================= 画面の作成 =================
        function buildDataStep(page)
            tab = uitab(page.Steps, 'Title', '① データを開く'); page.StepTabs.Data = tab;
            grid = uigridlayout(tab, [4, 1]); grid.RowHeight = {40, 70, '1x', 32};
            AppPage.hint(grid, ['学習に使う Excel（.xlsx）または CSV を開きます。1行目が列名でない場合は「ヘッダー行」を変更してください。' ...
                '数値の列だけを学習に使用でき、空欄を含む行があると確認時にお知らせします。']);
            page.Source = DataSourceControl(page, grid);
            page.Preview = uitable(grid, 'RowName', 'numbered');
            page.Source.PreviewTable = page.Preview; page.Source.LoadedFcn = @(data) page.dataLoaded(data);
            row = uigridlayout(grid, [1, 3]); row.Padding = [0, 0, 0, 0]; row.ColumnWidth = {'1x', 190, 220};
            uilabel(row, 'Text', sprintf('表は先頭%d行の表示です。学習には全行を使用します。', DataSourceControl.PREVIEW_ROWS));
            uibutton(row, 'Text', 'サンプルデータを開く', 'ButtonPushedFcn', @(~, ~) page.openSample(), ...
                'Tooltip', '同梱の合成データ（samples フォルダ）を開いて操作を試せます。');
            AppPage.primaryButton(row, '次へ：② 変数を選ぶ ▶', @(~, ~) page.goTo('Variables'));
        end
        function buildVariableStep(page)
            tab = uitab(page.Steps, 'Title', '② 変数を選ぶ'); page.StepTabs.Variables = tab;
            grid = uigridlayout(tab, [2, 2]); grid.RowHeight = {'1x', 36}; grid.ColumnWidth = {'1x', '1.6x'};
            left = AppPage.section(grid, '目的変数（予測したい列）');
            left_grid = uigridlayout(left, [2, 1]); left_grid.RowHeight = {62, '1x'};
            AppPage.hint(left_grid, sprintf(['複数選ぶと、列ごとに別のモデルを作ります（最大%d列）。' ...
                '複数選択は Ctrl（Mac は Command）を押しながらクリックします。'], page.App.Constants.MAX_TARGETS));
            page.Targets = uilistbox(left_grid, 'Items', {}, 'Value', {}, 'Multiselect', 'on', 'Enable', 'off', ...
                'ValueChangedFcn', @(~, ~) page.variablesChanged());
            right = AppPage.section(grid, '説明変数（モデルへの入力）');
            switch page.Kind
                case 'apc', right_grid = page.buildApcVariables(right);
                case 'swing', right_grid = page.buildSwingVariables(right);
                otherwise, right_grid = page.buildGenericVariables(right);
            end
            uilabel(right_grid, 'Text', 'モデルへ渡す順序（学習の前に確認してください）', 'FontWeight', 'bold');
            page.MappingTable = uitable(right_grid, 'Data', cell(0, 3), 'RowName', {}, ...
                'ColumnName', {'順序', 'モデルの変数名', '入力ファイルの列'}, 'ColumnWidth', {50, 'auto', 'auto'});
            if strcmp(page.Kind, 'generic')
                page.MappingTable.CellSelectionCallback = @(~, event) page.orderRowSelected(event);
                row = uigridlayout(right_grid, [1, 3]); row.Padding = [0, 0, 0, 0]; row.ColumnWidth = {'1x', 90, 90};
                page.OrderInfo = uilabel(row, 'Text', '順序を変える場合は、上の表で行を選んでから移動します。');
                uibutton(row, 'Text', '▲ 上へ', 'ButtonPushedFcn', @(~, ~) page.moveOrder(-1));
                uibutton(row, 'Text', '▼ 下へ', 'ButtonPushedFcn', @(~, ~) page.moveOrder(1));
            end
            bottom = uigridlayout(grid, [1, 3]); bottom.Layout.Row = 2; bottom.Layout.Column = [1, 2];
            bottom.Padding = [0, 0, 0, 0]; bottom.ColumnWidth = {'1x', 170, 240};
            page.ConfirmState = AppPage.stateLabel(bottom);
            uibutton(bottom, 'Text', '列対応を確認', 'FontWeight', 'bold', 'ButtonPushedFcn', @(~, ~) page.confirm(), ...
                'Tooltip', '選んだ列が数値か、重複や空欄がないかを調べます。確認するまで学習は実行できません。');
            AppPage.primaryButton(bottom, '次へ：③ 条件を決めて実行 ▶', @(~, ~) page.goTo('Conditions'));
        end
        function grid = buildApcVariables(page, parent)
            grid = uigridlayout(parent, [4, 1]); grid.RowHeight = {44, 132, 22, '1x'};
            AppPage.hint(grid, ['APCモデルの4変数に、入力ファイルの列を割り当てます。列名が同じ場合は自動で選びます。' ...
                '保存するモデルの変数名と順序は固定です（制御側との互換のため）。']);
            holder = uigridlayout(grid, [1, 1]); holder.Padding = [0, 0, 0, 0];
            page.Mapper = ColumnMapper(holder); page.Mapper.ChangedFcn = @() page.variablesChanged();
        end
        function grid = buildSwingVariables(page, parent)
            grid = uigridlayout(parent, [6, 1]); grid.RowHeight = {30, 30, 22, 110, 22, '1x'};
            row = uigridlayout(grid, [1, 2]); row.Padding = [0, 0, 0, 0]; row.ColumnWidth = {150, '1x'};
            uilabel(row, 'Text', 'モード');
            page.SwingMode = uidropdown(row, 'Items', {page.MODE_WITHOUT, page.MODE_WITH}, 'Value', page.MODE_WITHOUT, ...
                'ValueChangedFcn', @(~, ~) page.variablesChanged());
            row = uigridlayout(grid, [1, 2]); row.Padding = [0, 0, 0, 0]; row.ColumnWidth = {150, '1x'};
            uilabel(row, 'Text', 'レジスト膜厚の列（nm）');
            page.ResistColumn = uidropdown(row, 'Items', {ColumnMapper.NONE}, 'Enable', 'off', ...
                'ValueChangedFcn', @(~, ~) page.variablesChanged());
            uilabel(grid, 'Text', '下地の説明変数（「下地あり」のとき選択。複数選択は Ctrl / Command）');
            page.Underlayers = uilistbox(grid, 'Items', {}, 'Value', {}, 'Multiselect', 'on', 'Enable', 'off', ...
                'ValueChangedFcn', @(~, ~) page.variablesChanged());
        end
        function grid = buildGenericVariables(page, parent)
            grid = uigridlayout(parent, [5, 1]); grid.RowHeight = {44, 130, 22, '1x', 30};
            AppPage.hint(grid, ['モデルの入力に使う列を選びます（複数選択は Ctrl / Command）。' ...
                'GPRのMATは列名を持たないため、下の表の順序（1列目、2列目…）で入力と対応します。']);
            page.Predictors = uilistbox(grid, 'Items', {}, 'Value', {}, 'Multiselect', 'on', 'Enable', 'off', ...
                'ValueChangedFcn', @(~, ~) page.variablesChanged());
        end
        function buildConditionStep(page)
            tab = uitab(page.Steps, 'Title', '③ 条件を決めて実行'); page.StepTabs.Conditions = tab;
            grid = uigridlayout(tab, [2, 2]); grid.RowHeight = {'1x', 44}; grid.ColumnWidth = {'1x', '1x'};
            page.buildModelConditions(AppPage.section(grid, 'モデルの条件'));
            page.buildEvaluationConditions(AppPage.section(grid, '評価とSHAPの条件'));
            bottom = uigridlayout(grid, [1, 2]); bottom.Layout.Row = 2; bottom.Layout.Column = [1, 2];
            bottom.Padding = [0, 0, 0, 0]; bottom.ColumnWidth = {'1x', 280};
            page.Plan = AppPage.stateLabel(bottom);
            page.RunButton = AppPage.primaryButton(bottom, 'モデリング・SHAP評価を実行', @(~, ~) page.runModeling());
        end
        function buildModelConditions(page, parent)
            settings = page.settings(); constants = page.App.Constants;
            kernels = constants.KERNELS; default_kernel = settings.Kernel;
            if strcmp(page.Kind, 'swing'), kernels = constants.SWING_KERNELS; default_kernel = settings.SwingKernel; end
            heights = {22, 190, 44};
            if strcmp(page.Kind, 'generic'), heights = [{22, 30, 30}, heights]; end
            grid = uigridlayout(parent, [numel(heights) + 1, 1]); grid.RowHeight = [heights, {'1x'}];
            if strcmp(page.Kind, 'generic')
                uilabel(grid, 'Text', '回帰方式（複数選ぶと比較します）', 'FontWeight', 'bold');
                row = uigridlayout(grid, [1, 3]); row.Padding = [0, 0, 0, 0];
                page.Regressors.gpr = uicheckbox(row, 'Text', 'ガウス過程回帰（GPR）', 'Value', true, 'ValueChangedFcn', @(~, ~) page.conditionsChanged());
                page.Regressors.linear = uicheckbox(row, 'Text', '重回帰', 'Value', false, 'ValueChangedFcn', @(~, ~) page.conditionsChanged());
                page.Regressors.pls = uicheckbox(row, 'Text', 'PLS回帰', 'Value', false, 'ValueChangedFcn', @(~, ~) page.conditionsChanged());
                row = uigridlayout(grid, [1, 3]); row.Padding = [0, 0, 0, 0]; row.ColumnWidth = {150, 90, '1x'};
                [~, page.PlsComponents] = AppPage.numberField(row, 'PLSの成分数', 2, [1, 100], true);
                page.PlsComponents.Enable = 'off'; page.PlsComponents.ValueChangedFcn = @(~, ~) page.conditionsChanged();
                uilabel(row, 'Text', '（説明変数の数以下。PLSを選ぶと入力できます）');
            end
            uilabel(grid, 'Text', 'GPRのカーネル（複数選ぶと比較します。Ctrl / Command で複数選択）', 'FontWeight', 'bold');
            page.Kernels = uilistbox(grid, 'Items', kernels, 'Value', {default_kernel}, 'Multiselect', 'on', ...
                'ValueChangedFcn', @(~, ~) page.conditionsChanged());
            page.FitInfo = AppPage.hint(grid, page.fitMethodText());
            if strcmp(page.Kind, 'swing')
                AppPage.hint(grid, ['swingperiodic はレジスト膜厚の周期を持つ Swing Curve 専用カーネルです。' ...
                    '周期は右の「周期の探索範囲」の中から、当てはまり（周辺尤度）が最も良い値を自動で選びます。候補ごとに学習し直すため時間がかかります。']);
            else
                AppPage.fillLastRow(grid);
            end
        end
        function buildEvaluationConditions(page, parent)
            heights = {60, 30, 30, 30, 30};
            if strcmp(page.Kind, 'swing'), heights = [heights, {26, 30, 30, 26, 30, 30, 30}]; end
            grid = uigridlayout(parent, [numel(heights) + 1, 2]); grid.RowHeight = [heights, {'1x'}]; grid.ColumnWidth = {'1.3x', '1x'};
            label = AppPage.hint(grid, ['条件を2つ以上選ぶと、同じ分割の交差検証（学習に使っていない行での予測）で比べます。' ...
                '条件が1つのときは学習データでの当てはまりを表示します。下のチェックで1条件でも交差検証できます。']);
            label.Layout.Column = [1, 2];
            [~, page.Folds] = AppPage.numberField(grid, '交差検証の分割数（2〜10）', page.DEFAULT_FOLDS, [2, 10], true);
            [~, page.Seed] = AppPage.numberField(grid, '分割の乱数seed', 0, [0, 2^32 - 1], true);
            page.AlwaysValidate = uicheckbox(grid, 'Text', '条件が1つでも交差検証で評価する（時間は増えます）', 'Value', false);
            page.AlwaysValidate.Layout.Column = [1, 2];
            page.ComputeShap = uicheckbox(grid, 'Text', sprintf('SHAPも計算する（先頭最大%d行。後から計算もできます）', page.App.Constants.MAX_SHAP_POINTS), ...
                'Value', page.settings().ShowPlots);
            page.ComputeShap.Layout.Column = [1, 2];
            fields = {page.Folds, page.Seed, page.AlwaysValidate, page.ComputeShap};
            for index = 1:numel(fields), fields{index}.ValueChangedFcn = @(~, ~) page.conditionsChanged(); end
            if strcmp(page.Kind, 'swing'), page.buildPeriodOptions(grid); end
            AppPage.fillLastRow(grid);
        end
        function buildPeriodOptions(page, grid)
            defaults = swing_period_options();
            label = uilabel(grid, 'Text', '周期の探索範囲（swingperiodic と SHAP のカーブ評価で使用）', 'FontWeight', 'bold');
            label.Layout.Column = [1, 2];
            [~, page.Period.Wavelength] = AppPage.numberField(grid, '露光波長（nm）', defaults.Wavelength, [eps, Inf], false);
            [~, page.Period.RefractiveIndex] = AppPage.numberField(grid, 'レジスト屈折率', defaults.RefractiveIndex, [eps, Inf], false);
            page.Period.Reference = uilabel(grid, 'Text', '', 'Interpreter', 'none'); page.Period.Reference.Layout.Column = [1, 2];
            page.Period.Custom = uicheckbox(grid, 'Text', '探索範囲を自分で指定する（未指定は基準周期の75〜125%）', 'Value', false);
            page.Period.Custom.Layout.Column = [1, 2];
            [~, page.Period.Lower] = AppPage.numberField(grid, '周期の下限（nm）', defaults.PeriodBounds(1), [eps, Inf], false);
            [~, page.Period.Upper] = AppPage.numberField(grid, '周期の上限（nm）', defaults.PeriodBounds(2), [eps, Inf], false);
            names = {'Wavelength', 'RefractiveIndex', 'Custom', 'Lower', 'Upper'};
            for index = 1:numel(names), page.Period.(names{index}).ValueChangedFcn = @(~, ~) page.periodChanged(); end
            page.periodChanged();
        end
        function buildResultStep(page)
            tab = uitab(page.Steps, 'Title', '④ 結果を比べて保存'); page.StepTabs.Results = tab;
            grid = uigridlayout(tab, [4, 1]); grid.RowHeight = {22, page.MODEL_TABLE_HEIGHT, 34, '1x'}; page.ResultGrid = grid;
            uilabel(grid, 'Text', '学習したモデルの一覧（行をクリックすると、下に評価とグラフを表示します。以前の実行結果も残ります。比較は同じ目的変数・同じ評価データの中で行います）', 'FontWeight', 'bold');
            page.ModelTable = uitable(grid, 'Data', table(), 'RowName', {}, 'CellSelectionCallback', @(~, event) page.modelRowSelected(event));
            row = uigridlayout(grid, [1, 6]); row.Padding = [0, 0, 0, 0]; row.ColumnWidth = {150, '1x', '1x', '1x', '1.2x', 100};
            page.ExpandButton = uibutton(row, 'state', 'Text', 'グラフを大きく表示', 'ValueChangedFcn', @(~, ~) page.toggleExpand(), ...
                'Tooltip', 'モデルの一覧をたたみ、評価とグラフの表示を広げます。もう一度押すと戻ります。');
            AppPage.primaryButton(row, '選択モデルをMAT保存', @(~, ~) page.saveSelected());
            uibutton(row, 'Text', '選択モデルのSHAPを計算', 'ButtonPushedFcn', @(~, ~) page.computeShapForSelected(), ...
                'Tooltip', 'SHAPをまだ計算していないモデル、または失敗したモデルで計算し直します。MAT保存は不要です。');
            uibutton(row, 'Text', '予測・SHAPを1ファイルに保存', 'ButtonPushedFcn', @(~, ~) page.exportOutput(), ...
                'Tooltip', '選んだモデルについて、元データの説明変数・目的変数と、予測値・残差・SHAP値を並べた1つの表を CSV / Excel で保存します。');
            uibutton(row, 'Text', '一覧を保存', 'ButtonPushedFcn', @(~, ~) page.exportModelList());
            holder = uigridlayout(grid, [1, 1]); holder.Padding = [0, 0, 0, 0];
            page.Result = ResultPanel(page, holder, '①〜③を進めて実行すると、ここにモデルの評価とグラフを表示します。');
        end

        % ================= ① データ =================
        function dataLoaded(page, data)
            headers = data.Headers;
            selected = intersect(cellstr(string(page.Targets.Value)), headers, 'stable');
            if isempty(selected)
                % 判別できないときは選択しない（最終列などを勝手に目的変数にしない）。
                candidates = headers(ismember(lower(string(headers)), page.DEFAULT_TARGET_NAMES));
                if ~isempty(candidates), selected = candidates(1); end
            end
            set(page.Targets, 'Items', headers, 'Value', selected, 'Enable', 'on');
            switch page.Kind
                case 'apc'
                    page.Mapper.setRoles(page.App.Constants.PREDICTOR_NAMES, headers);
                case 'swing'
                    resist = ColumnMapper.NONE; match = find(strcmpi(headers, 'RESIST_TH'), 1);
                    if any(strcmp(headers, page.ResistColumn.Value)), resist = page.ResistColumn.Value;
                    elseif ~isempty(match), resist = headers{match}; end
                    set(page.ResistColumn, 'Items', [{ColumnMapper.NONE}, headers], 'Value', resist, 'Enable', 'on');
                    layers = intersect(cellstr(string(page.Underlayers.Value)), headers, 'stable');
                    if isempty(layers), layers = headers(ismember(headers, page.App.Constants.PREDICTOR_NAMES(1:3))); end
                    set(page.Underlayers, 'Items', headers, 'Value', layers);
                otherwise
                    kept = intersect(cellstr(string(page.Predictors.Value)), headers, 'stable');
                    set(page.Predictors, 'Items', headers, 'Value', kept, 'Enable', 'on');
                    page.Order = page.Order(ismember(page.Order, kept));
            end
            page.variablesChanged();
            page.message(sprintf('%s を読み込みました（%d行）。次に「② 変数を選ぶ」で目的変数と説明変数を選びます。', ...
                page.Source.fileName(), size(data.Cells, 1)));
        end
        function goTo(page, step)
            page.Steps.SelectedTab = page.StepTabs.(step);
        end

        % ================= ② 変数 =================
        function variablesChanged(page)
            if strcmp(page.Kind, 'swing')
                with_base = strcmp(page.SwingMode.Value, page.MODE_WITH) && ~isempty(page.Source.Data);
                page.Underlayers.Enable = matlab.lang.OnOffSwitchState(with_base);
            end
            if strcmp(page.Kind, 'generic'), page.updateOrder(); end
            page.MappingTable.Data = page.currentMapping();
            page.Confirmed = false; page.updateConfirmState(); page.refreshPlan();
        end
        function mapping = currentMapping(page)
            % {順序, モデルの変数名, 入力ファイルの列} の表を作る。
            mapping = cell(0, 3);
            if isempty(page.Source.Data), return; end
            switch page.Kind
                case 'apc'
                    mapping = page.Mapper.mapping();
                case 'swing'
                    columns = {}; names = {};
                    if strcmp(page.SwingMode.Value, page.MODE_WITH)
                        columns = cellstr(string(page.Underlayers.Value)); columns = columns(:)';
                        columns(strcmp(columns, page.ResistColumn.Value)) = [];
                        % 膜厚の変数名 RESIST_TH と重ならない、有効な変数名にする。
                        names = matlab.lang.makeUniqueStrings(matlab.lang.makeValidName(columns), {'RESIST_TH'});
                    end
                    columns{end + 1} = page.ResistColumn.Value; names{end + 1} = 'RESIST_TH';
                    mapping = [num2cell((1:numel(columns))'), names(:), columns(:)];
                otherwise
                    mapping = [num2cell((1:numel(page.Order))'), page.Order(:), page.Order(:)];
            end
        end
        function updateOrder(page)
            % 既に選んだ列の順序は保ち、新しく選んだ列を後ろへ加える。
            selected = cellstr(string(page.Predictors.Value)); selected = selected(:)';
            kept = page.Order(ismember(page.Order, selected));
            page.Order = [kept, selected(~ismember(selected, kept))];
            page.SelectedOrderRow = min(page.SelectedOrderRow, numel(page.Order));
            page.updateOrderInfo();
        end
        function orderRowSelected(page, event)
            if isempty(event.Indices), return; end
            page.SelectedOrderRow = event.Indices(1, 1); page.updateOrderInfo();
        end
        function moveOrder(page, step)
            if page.SelectedOrderRow < 1
                page.message('順序を変える行を、上の表でクリックして選んでください。'); return;
            end
            page.movePredictor(page.SelectedOrderRow, step);
        end
        function updateOrderInfo(page)
            if isempty(page.OrderInfo), return; end
            if page.SelectedOrderRow >= 1 && page.SelectedOrderRow <= numel(page.Order)
                page.OrderInfo.Text = sprintf('移動する行: %d. %s', page.SelectedOrderRow, page.Order{page.SelectedOrderRow});
            else
                page.OrderInfo.Text = '順序を変える場合は、上の表で行を選んでから移動します。';
            end
        end
        function validateVariables(page)
            data = page.Source.Data; constants = page.App.Constants;
            if isempty(data), page.goTo('Data'); error('modeling:noData', '「① データを開く」で入力ファイルを開いてください。'); end
            targets = cellstr(string(page.Targets.Value));
            if isempty(targets), error('modeling:targets', '目的変数（予測したい列）を左の一覧から選んでください。'); end
            mapping = page.currentMapping();
            if isempty(mapping), error('modeling:predictors', '説明変数を選んでください。'); end
            unassigned = strcmp(mapping(:, 3), ColumnMapper.NONE);
            if any(unassigned), error('modeling:predictors', '入力列を選んでいない説明変数があります: %s', strjoin(mapping(unassigned, 2), ', ')); end
            if strcmp(page.Kind, 'swing') && strcmp(page.SwingMode.Value, page.MODE_WITH) && size(mapping, 1) < 2
                error('modeling:underlayers', '「下地あり」では、膜厚以外の説明変数を1列以上選んでください。膜厚だけで学習する場合は「下地なし」を選びます。');
            end
            inputs = modeling_input_data(data, mapping, targets);
            if strcmp(page.Kind, 'apc') && size(inputs, 1) < constants.MIN_TRAIN_ROWS
                error('modeling:tooFewRows', 'APC学習には%d行以上のデータが必要です（現在 %d行）。', constants.MIN_TRAIN_ROWS, size(inputs, 1));
            end
        end
        function updateConfirmState(page)
            if page.Confirmed
                page.setState(page.ConfirmState, sprintf('✓ 確認済み：目的変数 %d列 / 説明変数 %d列 / %d行', ...
                    numel(page.Targets.Value), size(page.MappingTable.Data, 1), size(page.Source.Data.Cells, 1)), true);
            elseif isempty(page.Source.Data)
                page.setState(page.ConfirmState, '未確認：先に「① データを開く」でファイルを開いてください。', false);
            else
                page.setState(page.ConfirmState, '未確認：目的変数と説明変数を選び、「列対応を確認」を押してください。', false);
            end
        end

        % ================= ③ 条件 =================
        function conditionsChanged(page)
            if strcmp(page.Kind, 'generic')
                page.PlsComponents.Enable = matlab.lang.OnOffSwitchState(page.Regressors.pls.Value);
                page.Kernels.Enable = matlab.lang.OnOffSwitchState(page.Regressors.gpr.Value);
            end
            page.refreshPlan();
        end
        function periodChanged(page)
            % 表示も学習と同じ swing_period_options で求める（式を1か所にまとめる）。
            defaults = swing_period_options(page.Period.Wavelength.Value, page.Period.RefractiveIndex.Value);
            page.Period.Reference.Text = sprintf('基準周期 = 波長 ÷ 屈折率 ÷ 2 = %.4f nm（探索範囲の既定 %.2f〜%.2f nm）', ...
                defaults.ReferencePeriod, defaults.PeriodBounds(1), defaults.PeriodBounds(2));
            enabled = matlab.lang.OnOffSwitchState(page.Period.Custom.Value);
            page.Period.Lower.Enable = enabled; page.Period.Upper.Enable = enabled;
        end
        function options = periodOptions(page)
            options = swing_period_options();
            if ~strcmp(page.Kind, 'swing'), return; end
            bounds = [];
            if page.Period.Custom.Value, bounds = [page.Period.Lower.Value, page.Period.Upper.Value]; end
            options = swing_period_options(page.Period.Wavelength.Value, page.Period.RefractiveIndex.Value, bounds);
        end
        function regressors = selectedRegressors(page)
            regressors = {'gpr'};
            if ~strcmp(page.Kind, 'generic'), return; end
            names = {'gpr', 'linear', 'pls'};
            regressors = names(cellfun(@(name) page.Regressors.(name).Value, names));
        end
        function conditions = conditions(page, predictor_count)
            regressors = page.selectedRegressors();
            if isempty(regressors), error('modeling:regressors', '回帰方式を1つ以上選んでください。'); end
            kernels = cellstr(string(page.Kernels.Value));
            if any(strcmp(regressors, 'gpr')) && isempty(kernels), error('modeling:kernels', 'GPRのカーネルを1つ以上選んでください。'); end
            components = 2;
            if strcmp(page.Kind, 'generic')
                components = page.PlsComponents.Value;
                if any(strcmp(regressors, 'pls')) && components > predictor_count
                    error('modeling:components', 'PLSの成分数（%d）は説明変数の数（%d）以下にしてください。', components, predictor_count);
                end
            end
            conditions = modeling_conditions(kernels(:)', regressors, page.settings().FitMethod, components);
        end
        function count = conditionCount(page)
            regressors = page.selectedRegressors(); count = numel(regressors);
            if any(strcmp(regressors, 'gpr')), count = count - 1 + numel(page.Kernels.Value); end
        end
        function folds = validationFolds(page, condition_count)
            folds = 0;
            if condition_count >= 2 || page.AlwaysValidate.Value, folds = page.Folds.Value; end
        end
        function checkRowCount(page, rows, folds)
            % 交差検証では各分割の学習行が減るため、APCの最少行数を先に確認する。
            if folds < 2 || ~strcmp(page.Kind, 'apc'), return; end
            minimum = page.App.Constants.MIN_TRAIN_ROWS; training_rows = rows - ceil(rows / folds);
            if training_rows < minimum
                error('modeling:foldRows', ['APCは各分割の学習に%d行以上必要です（現在は %d行）。' ...
                    '分割数を増やすか、条件を1つにして学習データで評価してください。'], minimum, training_rows);
            end
        end
        function text = fitMethodText(page)
            text = sprintf('GPRの Fit method: %s（変更は「9 設定」で行います。全GPR共通）', page.settings().FitMethod);
        end
        function refreshPlan(page)
            if isempty(page.Plan), return; end
            if ~page.Confirmed
                page.setState(page.Plan, '「② 変数を選ぶ」で列対応を確認すると実行できます。', false); return;
            end
            targets = numel(page.Targets.Value); count = page.conditionCount(); folds = page.validationFolds(count);
            evaluation = '学習データでの当てはまりを表示';
            if folds >= 2, evaluation = sprintf('%d分割の交差検証で評価', folds); end
            shap = 'SHAPは計算しない'; if page.ComputeShap.Value, shap = 'SHAPも計算'; end
            page.setState(page.Plan, sprintf('目的変数 %d列 × 条件 %d = %d モデルを学習します。%s、%s。', ...
                targets, count, targets * count, evaluation, shap), true);
        end
        function reportProgress(~, dialog, event, started)
            [fraction, summary] = format_progress(event.Done, event.Total, toc(started));
            dialog.Indeterminate = 'off'; dialog.Value = fraction;
            where = sprintf('目的変数 %s（%d / %d）', event.Target, event.TargetIndex, event.Targets);
            if event.Condition > 0
                where = sprintf('%s・条件 %d / %d', where, event.Condition, event.Conditions);
            end
            dialog.Message = sprintf('%s\n%s：%s', summary, where, event.Stage);
            drawnow;
            if dialog.CancelRequested
                error('AnalysisApp:cancelled', 'モデリングを中止しました。今回の結果は一覧へ追加していません。以前の結果は残っています。');
            end
        end

        % ================= ④ 結果 =================
        function toggleExpand(page)
            % 一覧をたたんで、グラフ（特にPro版のカーブ評価）を広く表示する。
            if page.ExpandButton.Value
                page.ResultGrid.RowHeight{1} = 0; page.ResultGrid.RowHeight{2} = 0; page.ExpandButton.Text = '一覧を表示する';
            else
                page.ResultGrid.RowHeight{1} = 22; page.ResultGrid.RowHeight{2} = page.MODEL_TABLE_HEIGHT; page.ExpandButton.Text = 'グラフを大きく表示';
            end
        end
        function acceptRecords(page, records, data, period_options, seconds)
            page.RunSequence = page.RunSequence + 1; first_row = numel(page.Records) + 1; succeeded = 0;
            for index = 1:numel(records)
                record = records{index};
                record.Id = 0; record.Run = page.RunSequence; record.Kind = page.Kind; record.Source = data;
                record.SourceRows = data.RowNumbers; record.Bins = page.settings().Bins; record.PeriodOptions = period_options;
                record.Mode = ''; if strcmp(page.Kind, 'swing'), record.Mode = page.SwingMode.Value; end
                record.Columns = page.MappingTable.Data(:, 3)'; record.Verification = table(); record.SavedPath = '';
                if ~isempty(record.Model)
                    record.Id = page.App.Models.count() + 1; succeeded = succeeded + 1;
                    page.App.Models.add(record.Model, page.recordLabel(record), page.Kind, record);
                end
                page.Records{end + 1} = record;
                entry = page.logEntry(record); entry.Status = 'evaluated'; if isempty(record.Model), entry.Status = 'failed'; end
                page.App.logTraining(page, entry);
            end
            page.refreshModelTable(); page.goTo('Results');
            page.selectRow(page.bestRow(first_row));
            page.message(sprintf('実行%d：%d モデル中 %d モデルの学習に成功しました（%.1f秒）。一覧から選んで比較し、採用するモデルを保存します。', ...
                page.RunSequence, numel(records), succeeded, seconds));
            failed = numel(records) - succeeded;
            if failed > 0, page.message(sprintf('%d モデルは学習に失敗しました。一覧の「備考」で理由を確認してください。', failed)); end
            page.showWarnings(page.runWarnings(records));
        end
        function warnings = runWarnings(page, records)
            % 学習時の注意（行数が少ない、SHAPの件数制限・失敗など）は、ダイアログと状況欄の両方へ残す。
            % 同じ注意が複数のモデルで出た場合は、1つにまとめて対象のモデル数を示す。
            notes = strings(0, 1); limit = page.App.Constants.MAX_SHAP_POINTS;
            for index = 1:numel(records)
                record = records{index};
                if ~isempty(record.Model) && ~isempty(strtrim(record.Note)), notes(end + 1, 1) = string(strtrim(record.Note)); end %#ok<AGROW>
            end
            [warnings, ~, group] = unique(notes, 'stable');
            for index = 1:numel(warnings)
                count = sum(group == index);
                if count > 1, warnings(index) = sprintf('%s（%dモデル）', warnings(index), count); end
            end
            if page.ComputeShap.Value && ~isempty(records) && size(records{1}.Inputs, 1) > limit
                warnings(end + 1, 1) = sprintf('SHAPは先頭%d行で計算しました。評価指標は全行で計算しています。', limit);
            end
        end
        function row = bestRow(page, first_row)
            % 今回の実行の最初の目的変数で、RMSEが最も小さいモデルを最初に表示する。
            row = first_row; best = Inf; target = page.Records{first_row}.Target;
            for index = first_row:numel(page.Records)
                record = page.Records{index};
                if isempty(record.Model) || ~strcmp(record.Target, target), continue; end
                rmse = record.Metrics.Value(2);
                if rmse < best, best = rmse; row = index; end
            end
        end
        function entry = logEntry(page, record)
            entry = struct('Function', page.Kind, 'InputFile', page.fileNameOf(record.Source), 'Rows', size(record.Inputs, 1), ...
                'Kernel', modeling_condition_label(record.Condition), 'FitMethod', record.Condition.FitMethod, ...
                'ElapsedSeconds', record.Seconds, 'Seed', page.Seed.Value);
            entry.Folds = 0; if ~isempty(record.FoldId), entry.Folds = max(record.FoldId); end
            if ~isempty(record.Model)
                entry.PredictorNames = record.Model.PredictorNames; entry.ResponseName = record.Model.ResponseName;
            end
        end
        function refreshModelTable(page)
            count = numel(page.Records); rows = cell(count, 14); ranks = page.ranks();
            for index = 1:count
                record = page.Records{index}; r2 = NaN; rmse = NaN;
                if ~isempty(record.Metrics), r2 = record.Metrics.Value(1); rmse = record.Metrics.Value(2); end
                saved = ''; if ~isempty(record.SavedPath), [~, base, extension] = fileparts(record.SavedPath); saved = [base extension]; end
                rows(index, :) = {record.Id, record.Run, record.Target, modeling_condition_label(record.Condition), ranks(index), r2, rmse, ...
                    record.Scope, record.ShapStatus, record.Status, saved, strjoin(record.InputNames, ', '), ...
                    page.fileNameOf(record.Source), record.Note};
            end
            page.ModelTable.Data = cell2table(rows, 'VariableNames', ...
                {'ID', '実行', '目的変数', 'モデル', '順位', 'R2', 'RMSE', '評価データ', 'SHAP', '状態', '保存先', '説明変数', '入力ファイル', '備考'});
            page.ModelTable.ColumnWidth = {40, 44, 90, 150, 44, 80, 90, 120, 60, 54, 150, 200, 160, 'auto'};
        end
        function ranks = ranks(page)
            % 同じ実行・同じ目的変数の中で、RMSEの小さい順に順位を付ける。
            count = numel(page.Records); ranks = NaN(count, 1); groups = strings(count, 1); rmse = NaN(count, 1);
            for index = 1:count
                record = page.Records{index}; groups(index) = sprintf('%d/%s', record.Run, record.Target);
                if ~isempty(record.Model), rmse(index) = record.Metrics.Value(2); end
            end
            names = unique(groups);
            for group = 1:numel(names)
                members = find(groups == names(group) & isfinite(rmse)); [~, order] = sort(rmse(members));
                ranks(members(order)) = 1:numel(members);
            end
        end
        function modelRowSelected(page, event)
            if isempty(event.Indices), return; end
            row = event.Indices(1, 1);
            if row ~= page.SelectedRow, page.selectRow(row); end
        end
        function highlightSelectedRow(page)
            removeStyle(page.ModelTable);
            if page.SelectedRow >= 1 && page.SelectedRow <= numel(page.Records)
                addStyle(page.ModelTable, uistyle('BackgroundColor', page.SELECTED_ROW_COLOR, 'FontColor', [0, 0, 0], 'FontWeight', 'bold'), ...
                    'row', page.SelectedRow);
            end
        end
        function [record, row] = selectedRecord(page)
            row = page.SelectedRow;
            if row < 1 || row > numel(page.Records)
                error('modeling:noRecord', '「④ 結果を比べて保存」の一覧で、対象のモデルを選んでください。');
            end
            record = page.Records{row};
            if isempty(record.Model), error('modeling:failedRecord', '学習に失敗したモデルは選べません。「状態」が成功の行を選んでください。'); end
        end
        function label = recordLabel(page, record)
            label = sprintf('%s / %s / %s', page.TITLES.(page.Kind), record.Target, modeling_condition_label(record.Condition));
        end
        function name = fileNameOf(~, source)
            [~, base, extension] = fileparts(source.FileName); name = [base extension];
        end
        function showRecord(page, record)
            panel = page.Result; panel.clear();
            if isempty(record.Model)
                panel.setHeadline(sprintf('%s / %s：学習に失敗しました。\n理由: %s', record.Target, modeling_condition_label(record.Condition), record.Note));
                return;
            end
            actual = record.Actual; predicted = record.Prediction; residual = actual - predicted;
            caution = '';
            if isempty(record.FoldId), caution = '（学習に使ったデータでの当てはまりです。未知データでの精度ではありません）'; end
            panel.setHeadline(sprintf('%s / %s / 評価データ: %s%s\nRMSE: %.6g    R²: %.6g    n = %d', record.Target, ...
                modeling_condition_label(record.Condition), record.Scope, caution, record.Metrics.Value(2), record.Metrics.Value(1), numel(actual)));
            view = EvaluationScatterView(panel.ChartTabs, actual, predicted, record.Source);
            [charts, chart_names] = view.charts(); panel.registerCharts(charts, chart_names);
            page.drawComparison(record);
            panel.setTable('評価指標', display_metric_names(page.metricTable(record)));
            if ~isempty(record.FoldId), panel.setTable('検証分割', record.FoldMetrics); end
            panel.setTable(page.TABLE_OUTPUT, page.outputTable(record));
            panel.setTable('列の要約', summarize_model_columns([record.Inputs, actual, predicted, residual], ...
                [string(record.InputNames), "Actual", "Predicted", "Residual"]));
            if ~isempty(record.Details), page.showPeriodSearch(record.Details); end
            if ~isempty(record.Shap)
                page.showShap(record);
            end
            if ~isempty(record.Verification), panel.setTable(page.TABLE_VERIFICATION, record.Verification); end
            panel.showCharts(); page.App.applyTheme();
        end
        function metrics = metricTable(~, record)
            metrics = addvars(record.Metrics, repmat(string(record.Scope), height(record.Metrics), 1), 'Before', 1, 'NewVariableNames', 'Scope');
            if ~isempty(record.FoldId)
                training = addvars(record.TrainingMetrics, repmat("学習データ", height(record.TrainingMetrics), 1), 'Before', 1, 'NewVariableNames', 'Scope');
                metrics = [metrics; training];
            end
        end
        function drawComparison(page, record)
            % 同じ実行・同じ目的変数の条件を、RMSEで比べる棒グラフ。
            labels = {}; values = []; selected = 0;
            for index = 1:numel(page.Records)
                other = page.Records{index};
                if isempty(other.Model) || other.Run ~= record.Run || ~strcmp(other.Target, record.Target), continue; end
                labels{end + 1} = modeling_condition_label(other.Condition); values(end + 1) = other.Metrics.Value(2); %#ok<AGROW>
                if other.Id == record.Id, selected = numel(values); end
            end
            if numel(values) < 2, return; end
            ax = page.Result.addAxes(page.CHART_COMPARISON);
            bars = bar(ax, values, 'FaceColor', 'flat'); bars.CData = repmat([0.55, 0.70, 0.85], numel(values), 1);
            if selected > 0, bars.CData(selected, :) = [0.12, 0.35, 0.58]; end
            ax.XTick = 1:numel(values); ax.XTickLabel = labels; ax.XTickLabelRotation = 20; ax.TickLabelInterpreter = 'none';
            ylabel(ax, sprintf('RMSE（%s）', record.Scope)); grid(ax, 'on');
            title(ax, sprintf('%s：条件ごとのRMSE（濃い色が選択中。小さいほど良い）', record.Target), 'Interpreter', 'none');
        end
        function showPeriodSearch(page, details)
            panel = page.Result; panel.setTable('周期の最適化', details.Trace);
            ax = panel.addAxes(page.CHART_PERIOD);
            valid = details.Trace.Succeeded; [periods, order] = sort(details.Trace.Period(valid));
            likelihood = details.Trace.LogLikelihood(valid);
            plot(ax, periods, likelihood(order), '.-', 'DisplayName', '評価した候補'); hold(ax, 'on');
            scatter(ax, details.Period, details.LogLikelihood, 60, 'filled', 'DisplayName', '採用した周期');
            xlabel(ax, '周期（nm）'); ylabel(ax, details.Criterion);
            title(ax, sprintf('採用した周期 %.6g nm（尤度が最も大きい候補）', details.Period));
            legend(ax, 'Location', 'best'); grid(ax, 'on');
        end
        function output = outputTable(~, record)
            % 元データの説明変数（入力ファイルの列名）・目的変数と、予測値・残差・SHAP値を1つの表へまとめる。
            % 交差検証では「予測値」は学習に使っていない分割での予測で、全データで学習したモデルの値も並べる。
            parts = struct('SourceRows', record.SourceRows, 'InputColumns', {record.Columns}, 'Inputs', record.Inputs, ...
                'TargetName', record.Target, 'Actual', record.Actual, 'Predicted', record.Prediction, 'Extra', table());
            if ~isempty(record.FoldId)
                parts.Extra = table(record.FoldId, record.TrainingPrediction, ...
                    'VariableNames', {'検証分割', [record.Target '_全データモデルの予測値']});
            end
            if ~isempty(record.Shap)
                parts.ShapColumns = strcat('SHAP_', record.InputNames); parts.ShapValues = record.Shap.Values;
            end
            output = combine_model_outputs(parts);
        end
        function showShap(page, record)
            panel = page.Result; names = record.InputNames; values = record.Shap.Values;
            options = struct('Edition', page.App.Edition, 'AllowSwingFit', ~strcmp(page.Kind, 'apc'), ...
                'PeriodOptions', record.PeriodOptions, 'Explainer', record.Shap.Explainer);
            [charts, chart_names] = plot_shap_figures(panel.ChartTabs, values, record.Shap.Inputs, names, options);
            panel.registerCharts(charts, chart_names);
        end
    end
end
