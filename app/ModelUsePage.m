classdef ModelUsePage < AppPage
    % 学習済みモデルを使う画面（保存モデルで推定 / SHAP 解析）。
    % 左で ① モデル → ② データ → ③ 列の割当 → ④ 実行 の順に進み、右に結果を表示する。
    properties (SetAccess = private)
        Kind
        ModelChoice
        ModelInfo
        Source
        Mode
        Mapper
        Actual
        ShowPlots = []
        SelectionState
        RunButton
        Views
        ResultTab
        PreviewTab
        Preview
        Result
        Model = []
        ModelEntry = []
    end
    properties (Access = private)
        ModelListener
    end
    properties (Constant)
        LEFT_WIDTH = 440
        NO_MODEL = 0
        NO_ACTUAL = '(実測値なし)'
        MODE_GENERAL = '汎用推定（APC・Swing Curve・汎用回帰のモデル）'
        MODE_IN_PLANE = '面内推定（既存の面内モデル。X・Y座標の2列）'
        MODE_DEPENDENCE = 'SHAP依存確認（全説明変数のSHAP）'
        MODE_DENOISE = 'ノイズ除去用SHAP（Swing Curve：膜厚のSHAPだけを出力）'
        IN_PLANE_ROLES = {'X', 'Y'}
        TABLE_OUTPUT = '出力（入力・予測・SHAPを並べた表）'
    end
    methods
        function page = ModelUsePage(app, parent, kind)
            page@AppPage(app, parent);
            page.Kind = kind;
            page.Body.ColumnWidth = {page.LEFT_WIDTH, '1x'}; page.Body.RowHeight = {'1x'};
            page.buildInputs(); page.buildResults();
            page.ModelListener = addlistener(app.Models, 'Changed', @(~, ~) page.refreshModelChoices());
            page.refreshModelChoices(); page.updateSelectionState();
            if strcmp(kind, 'predict')
                page.message('① 学習済みMATを開く（または起動中に学習したモデルを選ぶ）→ ② 推定したいデータを開く → ③ 列を割り当てて確認 → ④ 実行。');
            else
                page.message('① モデルを選ぶ（MATを保存していない学習直後のモデルも選べます）→ ② データを開く → ③ 列を割り当てて確認 → ④ 実行。');
            end
        end
        function delete(page)
            delete(page.ModelListener);
        end

        % ---------- 操作の入口（テストからも使う） ----------
        function openModel(page, path)
            % MATを読み込み、起動中のモデル一覧へ加えて選択する。
            model = page.App.Services.LoadModel(path);
            [~, base, extension] = fileparts(path);
            id = page.App.Models.add(model, ['MAT: ' base extension], 'loaded');
            page.selectModel(id);
            page.message(['モデルを読み込みました: ' base extension]);
        end
        function selectModel(page, id)
            page.refreshModelChoices(); page.ModelChoice.Value = id; page.modelChanged();
        end
        function run(page)
            dialog = [];
            try
                % 列の割当は実行のたびに自動で確認する（確認ボタンはない）。
                page.validateInputs();
                settings = page.settings();
                if settings.Bins > 0, validate_bin_count(settings.Bins, 'AnalysisApp'); end
                matrix = page.mappedInput(); rows = page.Source.Data.RowNumbers;
                page.Result.clear();
                if strcmp(page.Kind, 'predict')
                    dialog = page.App.startProgress('保存モデルで推定', '推定しています。');
                    prediction = page.runPrediction(matrix, rows);
                else
                    dialog = page.App.startProgress('SHAP 解析', 'SHAP値を計算しています。行数が多いと時間がかかります。');
                    prediction = page.runShap(matrix, rows);
                end
                page.evaluate(matrix, prediction);
                AnalysisController.closeProgress(dialog);
                page.Views.SelectedTab = page.ResultTab; page.App.applyTheme();
                page.message('処理が終わりました。右の結果を確認してください。');
            catch err
                AnalysisController.closeProgress(dialog); page.showError(err);
            end
        end
        function onSettingsChanged(page)
            if ~isempty(page.ShowPlots) && isempty(page.Result.Charts), page.ShowPlots.Value = page.settings().ShowPlots; end
        end
        function onShown(page)
            page.refreshModelChoices();
        end
    end

    methods (Access = private)
        % ================= 画面の作成 =================
        function buildInputs(page)
            left = uigridlayout(page.Body, [5, 1]); left.Padding = [0, 0, 0, 0];
            left.RowHeight = {158, 104, '1x', 30, 38};
            panel = AppPage.section(left, '① モデルを選ぶ');
            grid = uigridlayout(panel, [3, 2]); grid.RowHeight = {30, 30, '1x'}; grid.ColumnWidth = {150, '1x'};
            uibutton(grid, 'Text', '学習済みMATを開く', 'ButtonPushedFcn', @(~, ~) page.chooseModel());
            uilabel(grid, 'Text', '信頼できる作成元のMATだけを開いてください。', 'WordWrap', 'on');
            uilabel(grid, 'Text', '使用するモデル');
            page.ModelChoice = uidropdown(grid, 'Items', {'(モデル未選択)'}, 'ItemsData', page.NO_MODEL, 'Value', page.NO_MODEL, ...
                'ValueChangedFcn', @(~, ~) page.modelChanged(), 'Tooltip', '読み込んだMATと、この起動中に学習したモデルから選べます。');
            page.ModelInfo = uitextarea(grid, 'Editable', 'off', 'Value', {'モデルを選ぶと、説明変数の名前と順序を表示します。'});
            page.ModelInfo.Layout.Column = [1, 2];

            panel = AppPage.section(left, '② データを開く');
            grid = uigridlayout(panel, [1, 1]); grid.Padding = [8, 6, 8, 6];
            page.Source = DataSourceControl(page, grid); page.Source.LoadedFcn = @(data) page.dataLoaded(data);

            panel = AppPage.section(left, '③ 列を割り当てる');
            rows = {30, '1x', 30}; if strcmp(page.Kind, 'shap'), rows{end + 1} = 26; end
            grid = uigridlayout(panel, [numel(rows), 2]); grid.RowHeight = rows; grid.ColumnWidth = {150, '1x'};
            uilabel(grid, 'Text', '処理の種類');
            modes = {page.MODE_GENERAL, page.MODE_IN_PLANE};
            if strcmp(page.Kind, 'shap'), modes = {page.MODE_DEPENDENCE, page.MODE_DENOISE}; end
            page.Mode = uidropdown(grid, 'Items', modes, 'ValueChangedFcn', @(~, ~) page.refreshRoles());
            holder = uigridlayout(grid, [1, 1]); holder.Padding = [0, 0, 0, 0]; holder.Layout.Column = [1, 2];
            page.Mapper = ColumnMapper(holder); page.Mapper.ChangedFcn = @() page.inputsChanged();
            uilabel(grid, 'Text', '評価用の実測列（任意）', 'Tooltip', '選ぶと、推定値との誤差（RMSE・R²など）も計算します。');
            page.Actual = uidropdown(grid, 'Items', {page.NO_ACTUAL}, 'Enable', 'off', 'ValueChangedFcn', @(~, ~) page.inputsChanged());
            if strcmp(page.Kind, 'shap')
                page.ShowPlots = uicheckbox(grid, 'Text', 'SHAPのグラフも表示する', 'Value', page.settings().ShowPlots);
                page.ShowPlots.Layout.Column = [1, 2];
            end

            page.SelectionState = AppPage.stateLabel(left);
            label = '④ 推定を実行'; if strcmp(page.Kind, 'shap'), label = '④ SHAPを計算'; end
            page.RunButton = AppPage.primaryButton(left, label, @(~, ~) page.run());
        end
        function buildResults(page)
            page.Views = uitabgroup(page.Body);
            page.ResultTab = uitab(page.Views, 'Title', '結果'); grid = uigridlayout(page.ResultTab, [1, 1]);
            page.Result = ResultPanel(page, grid, '左の①〜④を進めると、ここに結果を表示します。');
            page.PreviewTab = uitab(page.Views, 'Title', '入力プレビュー'); grid = uigridlayout(page.PreviewTab, [1, 1]);
            page.Preview = uitable(grid, 'RowName', 'numbered'); page.Source.PreviewTable = page.Preview;
        end

        % ================= ① モデル =================
        function chooseModel(page)
            try
                path = page.App.chooseOpenFile({'*.mat', '学習済みモデル（*.mat）'}, '学習済みモデルを選択');
                if isempty(path), page.message('学習済モデルの選択がキャンセルされました'); return; end
                page.openModel(path);
            catch err
                page.showError(err);
            end
        end
        function refreshModelChoices(page)
            [labels, ids] = page.App.Models.list();
            if isempty(ids)
                set(page.ModelChoice, 'Items', {'(モデル未選択：MATを開くか、学習画面でモデルを作ります)'}, 'ItemsData', page.NO_MODEL, 'Value', page.NO_MODEL);
                return;
            end
            selected = page.ModelChoice.Value;
            items = [{'(モデル未選択)'}, labels]; data = [page.NO_MODEL, ids];
            if ~ismember(selected, data), selected = page.NO_MODEL; end
            set(page.ModelChoice, 'Items', items, 'ItemsData', data, 'Value', selected);
        end
        function modelChanged(page)
            id = page.ModelChoice.Value; page.Model = []; page.ModelEntry = [];
            if id == page.NO_MODEL
                page.ModelInfo.Value = {'モデルを選ぶと、説明変数の名前と順序を表示します。'};
            else
                page.ModelEntry = page.App.Models.get(id); page.Model = page.ModelEntry.Model;
                page.ModelInfo.Value = page.describeModel();
            end
            page.refreshRoles();
        end
        function lines = describeModel(page)
            model = page.Model; names = page.displayNames();
            lines = {page.ModelEntry.Label; ['説明変数（順序どおり）: ' strjoin(names, ', ')]};
            if ~isequal(names, model.PredictorNames)
                lines{end + 1} = ['モデル内の変数名: ' strjoin(model.PredictorNames, ', ')];
            end
            if isa(model, 'ProcessRegressionModel')
                lines{end + 1} = sprintf('学習データ %d行 / 方式: %s', model.NumObservations, model.methodLabel());
            else
                lines{end + 1} = sprintf('学習データ %d行 / ResponseName: %s / kernel: %s', model.NumObservations, ...
                    char(string(model.ResponseName)), model_kernel_name(model.KernelFunction));
            end
            periodic = swing_kernel_info(model.KernelFunction);
            if ~isempty(periodic), lines{end + 1} = sprintf('swingperiodic の周期: %.8g nm', periodic.Period); end
        end
        function names = displayNames(page)
            % 起動中に学習したモデルは、学習時の列名を表示に使う（汎用GPRのMAT内は x1, x2…）。
            names = page.Model.PredictorNames;
            record = page.ModelEntry.Record;
            if ~isempty(record) && isfield(record, 'InputNames') && numel(record.InputNames) == numel(names)
                names = record.InputNames;
            end
            names = cellstr(string(names(:)'));
        end

        % ================= ② データ・③ 割当 =================
        function dataLoaded(page, data)
            selected = page.NO_ACTUAL;
            if any(strcmp(data.Headers, page.Actual.Value)), selected = page.Actual.Value; end
            set(page.Actual, 'Items', [{page.NO_ACTUAL}, data.Headers], 'Value', selected, 'Enable', 'on');
            page.Views.SelectedTab = page.PreviewTab; page.refreshRoles();
            page.message(sprintf('%s を読み込みました（%d行）。', page.Source.fileName(), size(data.Cells, 1)));
        end
        function refreshRoles(page)
            roles = {}; headers = {};
            if ~isempty(page.Source.Data), headers = page.Source.Data.Headers; end
            if ~isempty(page.Model)
                roles = page.displayNames();
                if strcmp(page.Mode.Value, page.MODE_IN_PLANE), roles = page.IN_PLANE_ROLES; end
            end
            page.Mapper.setRoles(roles, headers, 'モデルと入力ファイルを選ぶと、モデルの説明変数ごとに入力列を選ぶ欄を表示します。');
            page.inputsChanged();
        end
        function inputsChanged(page)
            page.updateSelectionState();
        end
        function updateSelectionState(page)
            % 確認ボタンはない。準備の状況を表示し、列の中身は実行時に自動で確認する。
            if isempty(page.Model)
                page.setState(page.SelectionState, '①でモデルを選んでください。', false);
            elseif isempty(page.Source.Data)
                page.setState(page.SelectionState, '②でデータを開いてください。', false);
            elseif any(strcmp(page.Mapper.selection(), ColumnMapper.NONE))
                page.setState(page.SelectionState, '③で、すべての説明変数に入力列を選んでください。', false);
            else
                page.setState(page.SelectionState, sprintf('準備ができました（%d行 × %d列）。列の中身は実行時に自動で確認します。', ...
                    size(page.Source.Data.Cells, 1), numel(page.Mapper.Roles)), true);
            end
        end
        function validateInputs(page)
            if isempty(page.Model), error('AnalysisApp:noModel', '①でモデルを選んでください。'); end
            if isempty(page.Source.Data), error('AnalysisApp:noInput', '②で入力ファイルを開いてください。'); end
            names = page.Model.PredictorNames;
            if strcmp(page.Mode.Value, page.MODE_IN_PLANE) && numel(names) ~= 3
                error('AnalysisApp:inPlaneModel', '面内推定は、X・Y・半径の3変数で学習した面内モデルで使用します（選択中のモデルは%d変数）。', numel(names));
            end
            if strcmp(page.Mode.Value, page.MODE_DENOISE) && (~istable(page.Model.X) || ~strcmp(names{end}, 'RESIST_TH'))
                error('AnalysisApp:denoiseModel', 'ノイズ除去用SHAPは、最後の説明変数が RESIST_TH の Swing Curve モデルで使用します。');
            end
            page.mappedInput();
        end
        function matrix = mappedInput(page)
            page.Mapper.requireComplete(); mapping = page.Mapper.mapping();
            if ~strcmp(page.Actual.Value, page.NO_ACTUAL)
                if any(strcmp(mapping(:, 3), page.Actual.Value))
                    error('AnalysisApp:responseLeak', '実測列に、説明変数と同じ列は指定できません。');
                end
                extract_numeric_columns(page.Source.Data, {page.Actual.Value});
            end
            matrix = assign_required_columns(page.Source.Data, mapping(:, 2), mapping(:, 3));
        end

        % ================= ④ 実行 =================
        function prediction = runPrediction(page, matrix, rows)
            extra = table();
            if strcmp(page.Mode.Value, page.MODE_IN_PLANE)
                [prediction, outside, warnings] = predict_in_plane(page.Model, matrix);
                extra = table(outside, 'VariableNames', {'OutsideTrainingRange'});
                page.showWarnings(warnings);
            else
                prediction = page.App.Services.Predictor(page.Model, matrix);
            end
            page.Result.setTable(page.TABLE_OUTPUT, page.outputTable(matrix, rows, prediction, extra, {}, []));
        end
        function prediction = runShap(page, matrix, rows)
            names = page.displayNames(); services = page.App.Services;
            prediction = services.Predictor(page.Model, matrix);
            if strcmp(page.Mode.Value, page.MODE_DENOISE)
                [resist, explainer, values] = services.Denoise(page.Model, matrix(:, 1:end-1), matrix(:, end));
                shap_columns = {'shap_resist'}; shap_values = resist;
            else
                [explainer, values] = services.Shap(page.Model, matrix);
                shap_columns = strcat('SHAP_', names); shap_values = values;
            end
            page.Result.setTable(page.TABLE_OUTPUT, page.outputTable(matrix, rows, prediction, table(), shap_columns, shap_values));
            if page.ShowPlots.Value
                % APC学習で作ったモデルには、Swing Curveのカーブ評価を付けない。
                allow_fit = ~strcmp(page.ModelEntry.Kind, 'apc'); period_options = swing_period_options();
                record = page.ModelEntry.Record;
                if ~isempty(record) && isfield(record, 'PeriodOptions'), period_options = record.PeriodOptions; end
                options = struct('Edition', page.App.Edition, 'AllowSwingFit', allow_fit, 'PeriodOptions', period_options, 'Explainer', explainer);
                [charts, chart_names] = plot_shap_figures(page.Result.ChartTabs, values, matrix, names, options);
                page.Result.registerCharts(charts, chart_names);
            end
        end
        function output = outputTable(page, matrix, rows, prediction, extra, shap_columns, shap_values)
            % 元データの説明変数（割り当てた入力列）と実測列、予測値・残差・SHAP値を1つの表へまとめる。
            mapping = page.Mapper.mapping(); target = ''; actual = [];
            if ~strcmp(page.Actual.Value, page.NO_ACTUAL)
                target = page.Actual.Value; actual = extract_numeric_columns(page.Source.Data, {target});
            end
            parts = struct('SourceRows', rows, 'InputColumns', {mapping(:, 3)'}, 'Inputs', matrix, 'TargetName', target, ...
                'Actual', actual, 'Predicted', prediction, 'Extra', extra, 'ShapColumns', {shap_columns}, 'ShapValues', shap_values);
            output = combine_model_outputs(parts);
        end
        function evaluate(page, matrix, prediction)
            names = string(page.Mapper.Roles); panel = page.Result; label = page.ModelEntry.Label;
            if ~strcmp(page.Actual.Value, page.NO_ACTUAL) && numel(prediction) >= 2
                actual = extract_numeric_columns(page.Source.Data, {page.Actual.Value});
                metrics = evaluate_predictions(actual, prediction, page.settings().Bins);
                panel.setTable('評価指標', display_metric_names(metrics));
                panel.setTable('列の要約', summarize_model_columns([matrix, actual, prediction, actual - prediction], ...
                    [names, "Actual", "Predicted", "Residual"]));
                view = EvaluationScatterView(panel.ChartTabs, actual, prediction, page.Source.Data);
                [charts, chart_names] = view.charts(); panel.registerCharts(charts, chart_names);
                panel.setHeadline(sprintf('%s\nRMSE: %.6g    R²: %.6g    n = %d（読み込んだデータで評価。学習に未使用かは利用者が確認）', ...
                    label, metrics.Value(2), metrics.Value(1), numel(actual)));
            elseif numel(prediction) >= 2
                panel.setTable('列の要約', summarize_model_columns([matrix, prediction], [names, "Predicted"]));
                panel.setHeadline(sprintf('%s\n%d件を処理しました。実測列を選んでいないため、RMSE・R² は計算していません。', label, numel(prediction)));
            else
                panel.setHeadline(sprintf('%s\n1件の結果です。評価と要約には2件以上が必要です。', label));
            end
            if isempty(panel.validCharts())
                panel.showTable(page.TABLE_OUTPUT);
            else
                panel.showCharts();
            end
        end
    end
end
