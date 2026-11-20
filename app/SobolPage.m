classdef SobolPage < AppPage
    % Sobol 感度解析の画面（Pro 版）。左で ① モデル → ② 入力の範囲 → ③ 条件 → ④ 実行、右に結果を表示する。
    % 範囲の初期値は、モデルの学習データの最小〜最大。各説明変数は範囲内の一様分布で、互いに独立に動かす。
    properties (SetAccess = private)
        ModelChoice
        ModelInfo
        Ranges
        SampleSize
        Bootstrap
        Plan
        RunButton
        Result
        Model = []
        ModelEntry = []
    end
    properties (Access = private)
        ModelListener
    end
    properties (Constant)
        LEFT_WIDTH = 460
        NO_MODEL = 0
        DEFAULT_SAMPLES = 1024
        DEFAULT_BOOTSTRAP = 200
        SAMPLE_LIMITS = [64, 65536]
        TABLE_INDICES = 'Sobol指数'
        CHART_INDICES = 'Sobol指数（1次・全効果）'
        CHART_PREDICTIONS = '予測値の分布'
        KIND_CONTINUOUS = '連続'
        KIND_CATEGORICAL = '質的'
    end
    methods
        function page = SobolPage(app, parent)
            page@AppPage(app, parent);
            page.Body.ColumnWidth = {page.LEFT_WIDTH, '1x'}; page.Body.RowHeight = {'1x'};
            left = uigridlayout(page.Body, [5, 1]); left.Padding = [0, 0, 0, 0]; left.RowHeight = {150, '1x', 130, 44, 38};
            panel = AppPage.section(left, '① モデルを選ぶ');
            grid = uigridlayout(panel, [3, 2]); grid.RowHeight = {30, 30, '1x'}; grid.ColumnWidth = {150, '1x'};
            uibutton(grid, 'Text', '学習済みMATを開く', 'ButtonPushedFcn', @(~, ~) page.chooseModel());
            uilabel(grid, 'Text', '信頼できる作成元のMATだけを開いてください。', 'WordWrap', 'on');
            uilabel(grid, 'Text', '使用するモデル');
            page.ModelChoice = uidropdown(grid, 'Items', {'(モデル未選択)'}, 'ItemsData', page.NO_MODEL, 'Value', page.NO_MODEL, ...
                'ValueChangedFcn', @(~, ~) page.modelChanged());
            page.ModelInfo = uitextarea(grid, 'Editable', 'off', 'Value', {'モデルを選ぶと、説明変数と範囲の初期値を表示します。'});
            page.ModelInfo.Layout.Column = [1, 2];
            panel = AppPage.section(left, '② 入力の範囲（下限・上限を編集できます）');
            grid = uigridlayout(panel, [2, 1]); grid.RowHeight = {44, '1x'};
            AppPage.hint(grid, '初期値は学習データの最小〜最大です。学習範囲の外（外挿）は予測の信頼性が下がります。質的変数は全水準を同じ割合で使います。');
            page.Ranges = uitable(grid, 'RowName', {}, 'ColumnName', {'説明変数', '種類', '下限', '上限'}, ...
                'ColumnEditable', [false, false, true, true], 'ColumnWidth', {140, 50, 'auto', 'auto'}, ...
                'CellEditCallback', @(~, ~) page.refreshPlan());
            panel = AppPage.section(left, '③ 条件');
            grid = uigridlayout(panel, [3, 2]); grid.RowHeight = {30, 30, '1x'}; grid.ColumnWidth = {220, '1x'};
            [~, page.SampleSize] = AppPage.numberField(grid, sprintf('基本の標本数 N（%d〜%d）', page.SAMPLE_LIMITS), page.DEFAULT_SAMPLES, page.SAMPLE_LIMITS, true);
            [~, page.Bootstrap] = AppPage.numberField(grid, '信頼区間のブートストラップ回数', page.DEFAULT_BOOTSTRAP, [20, 2000], true);
            page.SampleSize.ValueChangedFcn = @(~, ~) page.refreshPlan();
            label = AppPage.hint(grid, '準乱数（Sobol列）を使い、乱数seedは「設定」の値です。N を増やすほど推定が安定し、時間がかかります。');
            label.Layout.Column = [1, 2];
            page.Plan = AppPage.stateLabel(left);
            page.RunButton = AppPage.primaryButton(left, '④ Sobol感度解析を実行', @(~, ~) page.run());
            holder = uigridlayout(page.Body, [1, 1]); holder.Padding = [0, 0, 0, 0];
            page.Result = ResultPanel(page, holder, '左の①〜④を進めると、各説明変数の Sobol 指数（1次・全効果）を表示します。');
            page.ModelListener = addlistener(app.Models, 'Changed', @(~, ~) page.refreshModelChoices());
            page.refreshModelChoices(); page.refreshPlan();
            page.message('① モデルを選ぶ → ② 範囲を確認 → ③ 標本数を決める → ④ 実行。各説明変数が予測のばらつきにどれだけ効くかを調べます。');
        end
        function delete(page)
            delete(page.ModelListener);
        end
        function openModel(page, path)
            model = page.App.Services.LoadModel(path); [~, base, extension] = fileparts(path);
            id = page.App.Models.add(model, ['MAT: ' base extension], 'loaded'); page.selectModel(id);
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
                if isempty(page.Model), error('sobol:noModel', '①でモデルを選んでください。'); end
                data = page.Ranges.Data; lower = cell2mat(data(:, 3))'; upper = cell2mat(data(:, 4))';
                categorical = strcmp(data(:, 2), page.KIND_CATEGORICAL)';
                levels = zeros(1, numel(lower)); levels(categorical) = upper(categorical);
                names = data(:, 1)';
                dialog = page.App.startProgress('Sobol感度解析', sprintf('予測を %d 回計算しています。', page.SampleSize.Value * (numel(names) + 2)));
                options = struct('SampleSize', page.SampleSize.Value, 'Bootstrap', page.Bootstrap.Value, 'Seed', page.settings().Seed, ...
                    'Categorical', categorical, 'LevelCounts', levels);
                predictor = @(x) page.App.Services.Predictor(page.Model, x);
                result = calc_sobol_indices(predictor, lower, upper, names, options);
                AnalysisController.closeProgress(dialog);
                page.showResult(result);
            catch err
                AnalysisController.closeProgress(dialog); page.showError(err);
            end
        end
        function onShown(page)
            page.refreshModelChoices();
        end
    end
    methods (Access = private)
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
        function refreshPlan(page)
            if isempty(page.Model)
                page.setState(page.Plan, '①でモデルを選んでください。', false); return;
            end
            count = size(page.Ranges.Data, 1);
            page.setState(page.Plan, sprintf('説明変数 %d個 × 予測 %d 回（N × (説明変数の数＋2)）で計算します。', ...
                count, page.SampleSize.Value * (count + 2)), true);
        end
        function showResult(page, result)
            panel = page.Result; panel.clear(); table_data = result.Table; panel.setTable(page.TABLE_INDICES, table_data);
            ax = panel.addAxes(page.CHART_INDICES); hold(ax, 'on');
            values = [table_data.S1, table_data.ST]; bars = bar(ax, values, 'grouped');
            bars(1).DisplayName = '1次の指数 S1（単独の効果）'; bars(2).DisplayName = '全効果の指数 ST（交互作用を含む）';
            centres = [bars(1).XEndPoints; bars(2).XEndPoints]';
            low = [table_data.S1 - table_data.("S1_下限"), table_data.ST - table_data.("ST_下限")];
            high = [table_data.("S1_上限") - table_data.S1, table_data.("ST_上限") - table_data.ST];
            errorbar(ax, centres(:), values(:), low(:), high(:), 'k', 'LineStyle', 'none', 'HandleVisibility', 'off');
            ax.XTick = 1:height(table_data); ax.XTickLabel = table_data.("説明変数"); ax.TickLabelInterpreter = 'none';
            ylabel(ax, '予測のばらつきに占める割合'); grid(ax, 'on'); legend(ax, 'Location', 'best');
            title(ax, 'Sobol指数（ひげは95%信頼区間。ST − S1 が大きい変数は交互作用が強い）'); hold(ax, 'off');
            ax = panel.addAxes(page.CHART_PREDICTIONS); histogram(ax, result.Predictions);
            xlabel(ax, '予測値'); ylabel(ax, '件数'); grid(ax, 'on'); title(ax, sprintf('範囲内で動かしたときの予測値の分布（%d点）', numel(result.Predictions)));
            [~, top] = max(table_data.ST);
            panel.setHeadline(sprintf(['%s / 予測 %d 回。最も効く変数は %s（ST = %.3f）。S1 の合計 %.3f（1に近いほど交互作用が小さい）。' ...
                '各説明変数を範囲内で独立・一様に動かしたときの値です。'], page.ModelEntry.Label, result.Evaluations, ...
                table_data.("説明変数")(top), table_data.ST(top), sum(table_data.S1)));
            panel.showCharts(); page.App.applyTheme();
            page.message('Sobol感度解析が終わりました。');
        end
    end
end
