classdef SobolPage < AppPage
    % Sobol 感度解析の画面（Pro 版、「データを解析する」）。
    % 解析の対象は2通り：
    %   データ（Excel / CSV）：入力の列と出力の列を選ぶ。データで代替モデル（GPR またはランダムフォレスト）を学習し、
    %                         そのモデルで Sobol 指数を求める。モデルを使わずデータから直接求めた1次の指数も並べる。
    %   保存モデル           ：MAT または起動中に学習したモデルで求める（範囲の初期値は学習データの最小〜最大）。
    % 左で ① 対象 → ② 入力の範囲 → ③ 条件 → ④ 実行、右に結果を表示する。
    properties (SetAccess = private)
        SourceKind = 'data'
        SourceButtons
        DataPanel
        ModelPanel
        Source
        Output
        Inputs
        ModelChoice
        ModelInfo
        Ranges
        Distribution
        Surrogate
        SampleSize
        Bootstrap
        SigmaMultiple
        Plan
        RunButton
        Result
        Model = []
        ModelEntry = []
        DataValues = []
        LastSurrogate = []
    end
    properties (Access = private)
        ModelListener
    end
    properties (Constant)
        LEFT_WIDTH = 470
        NO_MODEL = 0
        NONE = '(未選択)'
        SOURCE_NAMES = {'データ（Excel / CSV）から', '保存モデル（MAT など）で'}
        SOURCE_CODES = {'data', 'model'}
        SELECTED_COLOR = [0.12, 0.35, 0.58]
        SELECTED_TEXT = [1, 1, 1]
        UNSELECTED_COLOR = [0.82, 0.85, 0.89]
        UNSELECTED_TEXT = [0.12, 0.17, 0.25]
        DISTRIBUTION_NAMES = {'データの分布（経験分布）', '一様（下限〜上限）'}
        DISTRIBUTION_CODES = {'empirical', 'uniform'}
        SURROGATE_NAMES = {'ガウス過程回帰（GPR、ARD）', 'ランダムフォレスト（200本）'}
        SURROGATE_CODES = {'gpr', 'forest'}
        SURROGATE_TREES = 200
        CV_FOLDS = 5
        DEFAULT_SAMPLES = 1024
        DEFAULT_BOOTSTRAP = 200
        DEFAULT_SIGMA = 3
        SAMPLE_LIMITS = [64, 65536]
        TABLE_INDICES = 'Sobol指数'
        TABLE_DISTRIBUTION = '予測値の分布の統計'
        TABLE_SURROGATE = '代替モデルの当てはまり'
        CHART_INDICES = 'Sobol指数（1次・全効果）'
        CHART_PREDICTIONS = '予測値の分布'
        KIND_CONTINUOUS = '連続'
        KIND_CATEGORICAL = '質的'
    end
    methods
        function page = SobolPage(app, parent)
            page@AppPage(app, parent);
            page.Body.ColumnWidth = {page.LEFT_WIDTH, '1x'}; page.Body.RowHeight = {'1x'};
            % 文字を大きくしても欄が切れないよう、各欄に固定の高さを持たせ、入りきらないときは左の列ごと上下にスクロールする。
            left = uigridlayout(page.Body, [6, 1], 'Scrollable', 'on'); left.Padding = [0, 0, 6, 0]; left.RowHeight = {68, 236, 190, 250, 48, 40};
            % 解析の対象（データ／保存モデル）は、どちらも使えることが一目で分かるよう、2つのボタンで選ぶ。
            row = uigridlayout(left, [2, 2]); row.Padding = [0, 0, 0, 0]; row.RowHeight = {22, '1x'};
            label = uilabel(row, 'Text', '① 解析の対象（データから、または保存モデルで）', 'FontWeight', 'bold'); label.Layout.Column = [1, 2];
            for index = 1:numel(page.SOURCE_CODES)
                code = page.SOURCE_CODES{index};
                page.SourceButtons.(code) = uibutton(row, 'state', 'Text', page.SOURCE_NAMES{index}, 'Tag', 'keep-color', ...
                    'ValueChangedFcn', @(~, ~) page.selectSource(code));
            end
            page.SourceButtons.data.Tooltip = 'Excel / CSV の列から代替モデルを学習して解析します。';
            page.SourceButtons.model.Tooltip = '保存したモデル（MAT）や、学習画面で作ったモデルで解析します。';
            holder = uigridlayout(left, [1, 1]); holder.Padding = [0, 0, 0, 0];
            page.buildDataPanel(holder); page.buildModelPanel(holder);
            panel = AppPage.section(left, '② 入力の範囲（下限・上限を編集できます）');
            grid = uigridlayout(panel, [2, 1]); grid.RowHeight = {48, '1x'};
            AppPage.hint(grid, '初期値はデータ（保存モデルでは学習データ）の最小〜最大です。範囲の外（外挿）は予測の信頼性が下がります。質的変数は全水準を同じ割合で使います。');
            page.Ranges = uitable(grid, 'RowName', {}, 'ColumnName', {'入力', '種類', '下限', '上限'}, ...
                'ColumnEditable', [false, false, true, true], 'ColumnWidth', {140, 50, 'auto', 'auto'}, ...
                'CellEditCallback', @(~, ~) page.refreshPlan());
            page.buildConditions(AppPage.section(left, '③ 条件'));
            page.Plan = AppPage.stateLabel(left);
            page.RunButton = AppPage.primaryButton(left, '④ Sobol感度解析を実行', @(~, ~) page.run());
            holder = uigridlayout(page.Body, [1, 1]); holder.Padding = [0, 0, 0, 0];
            page.Result = ResultPanel(page, holder, '左の①〜④を進めると、各入力の Sobol 指数（1次・全効果）と、予測値の分布を表示します。');
            page.ModelListener = addlistener(app.Models, 'Changed', @(~, ~) page.refreshModelChoices());
            page.refreshModelChoices(); page.sourceChanged();
            page.message(['① 対象を選ぶ（データなら入力・出力の列、保存モデルならモデル）→ ② 範囲を確認 → ③ 条件 → ④ 実行。' ...
                '各入力が出力のばらつきにどれだけ効くかを調べます。']);
        end
        function delete(page)
            delete(page.ModelListener);
        end
        % ---------- テストや他の画面から使う操作の入口 ----------
        function selectSource(page, code)
            if ~any(strcmp(page.SOURCE_CODES, code)), error('sobol:source', 'data または model を指定してください。'); end
            page.SourceKind = code; page.sourceChanged();
        end
        function selectColumns(page, output, inputs)
            page.Output.Value = output; page.Inputs.Value = cellstr(string(inputs(:)')); page.dataColumnsChanged();
        end
        function openModel(page, path)
            model = page.App.Services.LoadModel(path); [~, base, extension] = fileparts(path);
            id = page.App.Models.add(model, ['MAT: ' base extension], 'loaded'); page.selectSource('model'); page.selectModel(id);
            page.message(['モデルを読み込みました: ' base extension]);
        end
        function selectModel(page, id)
            page.refreshModelChoices(); page.ModelChoice.Value = id; page.modelChanged();
        end
        function setRange(page, row, lower, upper)
            page.Ranges.Data{row, 3} = lower; page.Ranges.Data{row, 4} = upper; page.refreshPlan();
        end
        function run(page)
            dialog = [];
            try
                require_pro_feature('Sobol感度解析');
                data = page.Ranges.Data;
                if isempty(data), error('sobol:noInput', '①で解析の対象（データの列、またはモデル）を選んでください。'); end
                lower = cell2mat(data(:, 3))'; upper = cell2mat(data(:, 4))'; names = data(:, 1)';
                categorical = strcmp(data(:, 2), page.KIND_CATEGORICAL)';
                levels = zeros(1, numel(lower)); levels(categorical) = upper(categorical);
                options = struct('SampleSize', page.SampleSize.Value, 'Bootstrap', page.Bootstrap.Value, 'Seed', page.settings().Seed, ...
                    'Categorical', categorical, 'LevelCounts', levels);
                dialog = page.App.startProgress('Sobol感度解析', '準備しています。');
                given = []; fit = table();
                if strcmp(page.SourceKind, 'data')
                    [inputs, response] = page.dataMatrices();
                    dialog.Message = '代替モデルを学習しています（交差検証で当てはまりも確かめます）。'; drawnow;
                    [predictor, fit] = page.trainSurrogate(inputs, response);
                    if strcmp(page.Distribution.Value, 'empirical'), options.Marginals = num2cell(inputs, 1); end
                    given = calc_sobol_given_data(inputs, response);
                    label = sprintf('データ %s（代替モデル：%s）', page.Source.fileName(), page.SURROGATE_NAMES{strcmp(page.SURROGATE_CODES, page.Surrogate.Value)});
                else
                    if isempty(page.Model), error('sobol:noModel', '①でモデルを選んでください。'); end
                    predictor = @(x) page.App.Services.Predictor(page.Model, x); label = page.ModelEntry.Label;
                end
                dialog.Message = sprintf('予測を %d 回計算しています。', page.SampleSize.Value * (numel(names) + 2)); drawnow;
                result = calc_sobol_indices(predictor, lower, upper, names, options);
                AnalysisController.closeProgress(dialog);
                page.showResult(result, given, fit, label);
            catch err
                AnalysisController.closeProgress(dialog); page.showError(err);
            end
        end
        function onShown(page)
            page.refreshModelChoices();
        end
    end
    methods (Access = private)
        % ================= 画面 =================
        function buildDataPanel(page, holder)
            page.DataPanel = AppPage.section(holder, 'データと列'); page.DataPanel.Layout.Row = 1; page.DataPanel.Layout.Column = 1;
            grid = uigridlayout(page.DataPanel, [4, 2]); grid.RowHeight = {64, 30, 22, '1x'}; grid.ColumnWidth = {110, '1x'};
            source_holder = uigridlayout(grid, [1, 1]); source_holder.Padding = [0, 0, 0, 0]; source_holder.Layout.Column = [1, 2];
            page.Source = DataSourceControl(page, source_holder); page.Source.LoadedFcn = @(data) page.dataLoaded(data);
            uilabel(grid, 'Text', '出力（目的変数）');
            page.Output = uidropdown(grid, 'Items', {page.NONE}, 'ValueChangedFcn', @(~, ~) page.dataColumnsChanged());
            label = uilabel(grid, 'Text', '入力（数値の列。複数選択は Ctrl キー）'); label.Layout.Column = [1, 2];
            page.Inputs = uilistbox(grid, 'Items', {}, 'Value', {}, 'Multiselect', 'on', 'ValueChangedFcn', @(~, ~) page.dataColumnsChanged());
            page.Inputs.Layout.Column = [1, 2];
        end
        function buildModelPanel(page, holder)
            page.ModelPanel = AppPage.section(holder, 'モデル'); page.ModelPanel.Layout.Row = 1; page.ModelPanel.Layout.Column = 1;
            grid = uigridlayout(page.ModelPanel, [3, 2]); grid.RowHeight = {30, 30, '1x'}; grid.ColumnWidth = {150, '1x'};
            uibutton(grid, 'Text', '学習済みMATを開く', 'ButtonPushedFcn', @(~, ~) page.chooseModel());
            uilabel(grid, 'Text', '信頼できる作成元のMATだけを開いてください。', 'WordWrap', 'on');
            uilabel(grid, 'Text', '使用するモデル');
            page.ModelChoice = uidropdown(grid, 'Items', {'(モデル未選択)'}, 'ItemsData', page.NO_MODEL, 'Value', page.NO_MODEL, ...
                'ValueChangedFcn', @(~, ~) page.modelChanged());
            page.ModelInfo = uitextarea(grid, 'Editable', 'off', 'Value', {'モデルを選ぶと、説明変数と範囲の初期値を表示します。'});
            page.ModelInfo.Layout.Column = [1, 2];
        end
        function buildConditions(page, parent)
            % 文字の大きさを既定（12）にしても説明が切れないよう、行の高さに余裕を持たせる。
            grid = uigridlayout(parent, [7, 2]); grid.RowHeight = {30, 30, 30, 30, 30, '1x', 0}; grid.ColumnWidth = {200, '1x'};
            uilabel(grid, 'Text', '入力の分布');
            page.Distribution = uidropdown(grid, 'Items', page.DISTRIBUTION_NAMES, 'ItemsData', page.DISTRIBUTION_CODES, ...
                'Tooltip', 'データから解析するとき、入力をデータと同じ分布で動かすか、範囲内で一様に動かすかを選びます。');
            uilabel(grid, 'Text', '代替モデル');
            page.Surrogate = uidropdown(grid, 'Items', page.SURROGATE_NAMES, 'ItemsData', page.SURROGATE_CODES, ...
                'Tooltip', 'データから解析するとき、入力から出力を予測するモデルです。当てはまりは交差検証で確かめます。');
            [~, page.SampleSize] = AppPage.numberField(grid, sprintf('基本の標本数 N（%d〜%d）', page.SAMPLE_LIMITS), page.DEFAULT_SAMPLES, page.SAMPLE_LIMITS, true);
            [~, page.Bootstrap] = AppPage.numberField(grid, '信頼区間のブートストラップ回数', page.DEFAULT_BOOTSTRAP, [20, 2000], true);
            [~, page.SigmaMultiple] = AppPage.numberField(grid, '分布図の範囲 平均 ± nσ の n', page.DEFAULT_SIGMA, [1, 6], true);
            page.SampleSize.ValueChangedFcn = @(~, ~) page.refreshPlan();
            label = AppPage.hint(grid, '準乱数（Sobol列）を使い、乱数seedは「設定」の値です。N を増やすほど推定が安定し、時間がかかります。');
            label.Layout.Column = [1, 2];
        end
        function sourceChanged(page)
            % 選んだボタンを押した状態・強調の色にする（もう一度押しても選択は外れない）。
            for index = 1:numel(page.SOURCE_CODES)
                code = page.SOURCE_CODES{index}; button = page.SourceButtons.(code); chosen = strcmp(code, page.SourceKind);
                button.Value = chosen;
                if chosen
                    set(button, 'BackgroundColor', page.SELECTED_COLOR, 'FontColor', page.SELECTED_TEXT, 'FontWeight', 'bold');
                else
                    set(button, 'BackgroundColor', page.UNSELECTED_COLOR, 'FontColor', page.UNSELECTED_TEXT, 'FontWeight', 'normal');
                end
            end
            data_mode = strcmp(page.SourceKind, 'data');
            page.DataPanel.Visible = matlab.lang.OnOffSwitchState(data_mode); page.ModelPanel.Visible = matlab.lang.OnOffSwitchState(~data_mode);
            page.Distribution.Enable = matlab.lang.OnOffSwitchState(data_mode); page.Surrogate.Enable = matlab.lang.OnOffSwitchState(data_mode);
            if data_mode, page.dataColumnsChanged(); else, page.modelChanged(); end
        end
        % ================= データ =================
        function dataLoaded(page, data)
            headers = data.Headers; numeric = headers(cellfun(@(name) data_column(data, name).IsNumeric, headers));
            previous = page.Output.Value; page.Output.Items = [{page.NONE}, numeric];
            if any(strcmp(numeric, previous)), page.Output.Value = previous; else, page.Output.Value = page.NONE; end
            set(page.Inputs, 'Items', numeric, 'Value', intersect(cellstr(string(page.Inputs.Value)), numeric, 'stable'));
            page.dataColumnsChanged();
            page.message(sprintf('%s を読み込みました（%d行）。数値の列だけを一覧に出します。', page.Source.fileName(), size(data.Cells, 1)));
        end
        function dataColumnsChanged(page)
            if ~strcmp(page.SourceKind, 'data'), return; end
            page.Ranges.Data = cell(0, 4); page.DataValues = [];
            names = page.selectedInputs();
            if isempty(page.Source.Data) || isempty(names), page.refreshPlan(); return; end
            try
                values = extract_numeric_columns(page.Source.Data, names);
            catch err
                page.refreshPlan(); page.showError(err); return;
            end
            rows = cell(numel(names), 4);
            for column = 1:numel(names), rows(column, :) = {names{column}, page.KIND_CONTINUOUS, min(values(:, column)), max(values(:, column))}; end
            page.Ranges.Data = rows; page.DataValues = values; page.refreshPlan();
        end
        function names = selectedInputs(page)
            names = cellstr(string(page.Inputs.Value)); names = names(:)';
            names = names(~strcmp(names, page.Output.Value));
        end
        function [inputs, response] = dataMatrices(page)
            if isempty(page.Source.Data), error('sobol:noData', '①でデータを開いてください。'); end
            if strcmp(page.Output.Value, page.NONE), error('sobol:output', '①で出力（目的変数）の列を選んでください。'); end
            names = page.selectedInputs();
            if isempty(names), error('sobol:inputs', '①で入力の列を1列以上選んでください（出力と同じ列は除きます）。'); end
            inputs = extract_numeric_columns(page.Source.Data, names); response = extract_numeric_columns(page.Source.Data, {page.Output.Value});
            if size(inputs, 1) < page.CV_FOLDS * 2, error('sobol:rows', 'データから解析するには %d 行以上が必要です。', page.CV_FOLDS * 2); end
        end
        function [predictor, fit] = trainSurrogate(page, inputs, response)
            % 代替モデルを全データで学習し、交差検証（5分割、乱数は設定の seed）で当てはまりを確かめる。
            method = page.Surrogate.Value; seed = page.settings().Seed;
            train = @(x, y) page.fitSurrogate(method, x, y);
            stream = RandStream('twister', 'Seed', seed); rows = size(inputs, 1);
            fold = zeros(rows, 1); fold(randperm(stream, rows)) = mod(0:rows - 1, page.CV_FOLDS) + 1; predicted = NaN(rows, 1);
            for index = 1:page.CV_FOLDS
                held = fold == index; model = train(inputs(~held, :), response(~held)); predicted(held) = predict(model, inputs(held, :));
            end
            model = train(inputs, response); page.LastSurrogate = model; training = predict(model, inputs);
            r2 = @(estimate) 1 - sum((response - estimate).^2) / sum((response - mean(response)).^2);
            rmse = @(estimate) sqrt(mean((response - estimate).^2));
            fit = table(["交差検証（" + page.CV_FOLDS + "分割）"; "学習データ"], [r2(predicted); r2(training)], [rmse(predicted); rmse(training)], ...
                'VariableNames', {'評価', 'R2', 'RMSE'});
            predictor = @(x) predict(model, x);
        end
        function model = fitSurrogate(page, method, x, y)
            if strcmp(method, 'gpr')
                model = fitrgp(x, y, 'KernelFunction', 'ardsquaredexponential', 'Standardize', true);
            else
                template = templateTree('MinLeafSize', 5, 'Reproducible', true);
                model = fitrensemble(x, y, 'Method', 'Bag', 'NumLearningCycles', page.SURROGATE_TREES, 'Learners', template);
            end
        end
        % ================= モデル =================
        function chooseModel(page)
            try
                path = page.App.chooseOpenFile({'*.mat', '学習済みモデル（*.mat）'}, '学習済みモデルを選択');
                if isempty(path), return; end
                page.openModel(path);
            catch err
                page.showError(err);
            end
        end
        function refreshModelChoices(page)
            [labels, ids] = page.App.Models.list(); selected = page.ModelChoice.Value;
            if isempty(ids)
                set(page.ModelChoice, 'Items', {'(モデル未選択：MATを開くか、学習画面でモデルを作ります)'}, 'ItemsData', page.NO_MODEL, 'Value', page.NO_MODEL); return;
            end
            data = [page.NO_MODEL, ids]; if ~ismember(selected, data), selected = page.NO_MODEL; end
            set(page.ModelChoice, 'Items', [{'(モデル未選択)'}, labels], 'ItemsData', data, 'Value', selected);
        end
        function modelChanged(page)
            if ~strcmp(page.SourceKind, 'model'), return; end
            id = page.ModelChoice.Value; page.Model = []; page.ModelEntry = []; page.Ranges.Data = cell(0, 4);
            if id ~= page.NO_MODEL
                page.ModelEntry = page.App.Models.get(id); page.Model = page.ModelEntry.Model;
                names = page.displayNames(); training = page.trainingInputs();
                categorical = false(1, numel(names)); levels = cell(1, numel(names));
                if isa(page.Model, 'ProcessRegressionModel') && isfield(page.Model.GPOptions, 'Categorical') && ~isempty(page.Model.GPOptions.Categorical)
                    categorical = page.Model.GPOptions.Categorical; levels = page.Model.GPOptions.Levels;
                end
                rows = cell(numel(names), 4);
                for column = 1:numel(names)
                    if categorical(column)
                        rows(column, :) = {names{column}, page.KIND_CATEGORICAL, 1, numel(levels{column})};
                    else
                        rows(column, :) = {names{column}, page.KIND_CONTINUOUS, min(training(:, column)), max(training(:, column))};
                    end
                end
                page.Ranges.Data = rows;
                page.ModelInfo.Value = {page.ModelEntry.Label; ['説明変数: ' strjoin(names, ', ')]; ...
                    sprintf('学習データ %d行（範囲の初期値はこの最小〜最大）', size(training, 1))};
            else
                page.ModelInfo.Value = {'モデルを選ぶと、説明変数と範囲の初期値を表示します。'};
            end
            page.refreshPlan();
        end
        function names = displayNames(page)
            names = page.Model.PredictorNames; record = page.ModelEntry.Record;
            if ~isempty(record) && isfield(record, 'InputNames') && numel(record.InputNames) == numel(names), names = record.InputNames; end
            names = cellstr(string(names(:)'));
        end
        function values = trainingInputs(page)
            values = page.Model.X;
            if istable(values), values = table2array(values); end
            values = double(values);
        end
        % ================= 結果 =================
        function refreshPlan(page)
            count = size(page.Ranges.Data, 1);
            if count == 0
                if strcmp(page.SourceKind, 'data')
                    page.setState(page.Plan, '①でデータを開き、出力の列と入力の列を選んでください。', false);
                else
                    page.setState(page.Plan, '①でモデルを選んでください。', false);
                end
                return;
            end
            page.setState(page.Plan, sprintf('入力 %d個 × 予測 %d 回（N × (入力の数＋2)）で計算します。', ...
                count, page.SampleSize.Value * (count + 2)), true);
        end
        function showResult(page, result, given, fit, label)
            panel = page.Result; panel.clear(); table_data = result.Table;
            if ~isempty(given), table_data.("S1_データから直接") = given(:); end
            panel.setTable(page.TABLE_INDICES, table_data);
            if ~isempty(fit), panel.setTable(page.TABLE_SURROGATE, fit); end
            ax = panel.addAxes(page.CHART_INDICES); hold(ax, 'on');
            values = [table_data.S1, table_data.ST]; bars = bar(ax, values, 'grouped');
            bars(1).DisplayName = '1次の指数 S1（単独の効果）'; bars(2).DisplayName = '全効果の指数 ST（交互作用を含む）';
            centres = [bars(1).XEndPoints; bars(2).XEndPoints]';
            low = [table_data.S1 - table_data.("S1_下限"), table_data.ST - table_data.("ST_下限")];
            high = [table_data.("S1_上限") - table_data.S1, table_data.("ST_上限") - table_data.ST];
            errorbar(ax, centres(:), values(:), low(:), high(:), 'k', 'LineStyle', 'none', 'HandleVisibility', 'off');
            if ~isempty(given)
                plot(ax, centres(:, 1), given(:), 'kd', 'MarkerFaceColor', [0.95, 0.75, 0.10], 'MarkerSize', 8, 'DisplayName', 'S1（データから直接）');
            end
            ax.XTick = 1:height(table_data); ax.XTickLabel = table_data.("説明変数"); ax.TickLabelInterpreter = 'none';
            ylabel(ax, '出力のばらつきに占める割合'); grid(ax, 'on'); legend(ax, 'Location', 'best');
            title(ax, 'Sobol指数（ひげは95%信頼区間。ST − S1 が大きい入力は交互作用が強い）'); hold(ax, 'off');
            page.drawDistribution(result.Predictions);
            [~, top] = max(table_data.ST);
            caution = '';
            if ~isempty(fit) && fit.R2(1) < 0.5
                caution = sprintf(' 代替モデルの交差検証 R² が %.2f と低いため、指数の信頼性は低めです。', fit.R2(1));
            end
            panel.setHeadline(sprintf('%s / 予測 %d 回。最も効く入力は %s（ST = %.3f）、S1 の合計 %.3f。%s', label, result.Evaluations, ...
                table_data.("説明変数")(top), table_data.ST(top), sum(table_data.S1), caution));
            panel.showCharts(); page.App.applyTheme();
            if ~isempty(caution), page.showWarnings(string(strtrim(caution))); end
            page.message('Sobol感度解析が終わりました。');
        end
        function drawDistribution(page, predictions)
            % 予測値の分布：ヒストグラムに、平均・最頻値・95%区間・平均 ± nσ を重ね、表にも出す。
            summary = calc_distribution_summary(predictions, page.SigmaMultiple.Value);
            page.Result.setTable(page.TABLE_DISTRIBUTION, summary.Table);
            ax = page.Result.addAxes(page.CHART_PREDICTIONS); hold(ax, 'on');
            histogram(ax, predictions, 'DisplayName', sprintf('予測値（%d点）', numel(predictions)), 'FaceColor', [0.55, 0.70, 0.85]);
            limits = ylim(ax); n = summary.SigmaMultiple;
            patch(ax, [summary.Interval(1), summary.Interval(2), summary.Interval(2), summary.Interval(1)], [0, 0, limits(2), limits(2)], ...
                [0.30, 0.60, 0.30], 'FaceAlpha', 0.12, 'EdgeColor', 'none', 'DisplayName', sprintf('95%%区間 %.4g〜%.4g', summary.Interval));
            xline(ax, summary.Average, '-', 'LineWidth', 2, 'Color', [0.12, 0.35, 0.58], 'DisplayName', sprintf('平均 %.4g', summary.Average));
            xline(ax, summary.Mode, '--', 'LineWidth', 2, 'Color', [0.85, 0.33, 0.10], 'DisplayName', sprintf('最頻値 %.4g', summary.Mode));
            xline(ax, summary.SigmaLower(end), ':', 'LineWidth', 1.8, 'Color', [0.45, 0.15, 0.55], ...
                'DisplayName', sprintf('平均 ± %dσ（%.4g〜%.4g）', n, summary.SigmaLower(end), summary.SigmaUpper(end)));
            xline(ax, summary.SigmaUpper(end), ':', 'LineWidth', 1.8, 'Color', [0.45, 0.15, 0.55], 'HandleVisibility', 'off');
            ylim(ax, limits); xlabel(ax, '予測値'); ylabel(ax, '件数'); grid(ax, 'on'); legend(ax, 'Location', 'bestoutside');
            title(ax, sprintf('入力を動かしたときの予測値の分布（σ = %.4g）', summary.Deviation)); hold(ax, 'off');
        end
    end
end
