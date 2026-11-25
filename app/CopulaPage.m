classdef CopulaPage < AppPage
    % コピュラによる乱数生成の画面（Pro 版、「データを解析する」）。
    % 作り方は2通り：
    %   データの関係をまねる：Excel / CSV から列を選び、列どうしの関係（コピュラ）と各列の分布（周辺分布）を当てはめて、
    %                         その関係を保った乱数を作る。
    %   関係を指定して作る  ：変数ごとの分布と、変数どうしの順位相関（Kendall τ または Spearman ρ）を入れて作る。
    % 左で ① 作り方と入力 → ② コピュラ・周辺分布・個数 → ③ 実行、右に乱数の表・関係の比較・散布図・分布を表示する。
    properties (SetAccess = private)
        Mode
        DataPanel
        SpecPanel
        Source
        Columns
        VariableCount
        Measure
        Variables
        Dependence
        Family
        Marginal
        SampleCount
        Seed
        Plan
        RunButton
        Result
        Model = []
        Samples = []
    end
    properties (Constant)
        LEFT_WIDTH = 480
        MODE_NAMES = {'データの関係をまねる（Excel / CSV）', '関係を指定して作る（データなし）'}
        MODE_CODES = {'data', 'spec'}
        MEASURE_NAMES = {'Spearman ρ（順位の相関）', 'Kendall τ（順位の一致の度合い）'}
        MEASURE_CODES = {'spearman', 'kendall'}
        DEFAULT_COUNT = 1000
        COUNT_LIMITS = [10, 1e6]
        MAX_COLUMNS = 20
        DEFAULT_VARIABLES = 2
        DEFAULT_CORRELATION = 0.5
        MAX_SCATTER_POINTS = 3000
        MAX_HISTOGRAMS = 12
        TABLE_SAMPLES = '生成した乱数'
        TABLE_DEPENDENCE = '順位相関の比較'
        TABLE_SUMMARY = '列の要約'
        TABLE_PARAMETERS = 'コピュラのパラメータ'
        CHART_SCATTER = '散布図（元と生成）'
        ORIGINAL_COLOR = [0.65, 0.65, 0.65]
        GENERATED_COLOR = [0.12, 0.35, 0.58]
    end
    methods
        function page = CopulaPage(app, parent)
            page@AppPage(app, parent);
            page.Body.ColumnWidth = {page.LEFT_WIDTH, '1x'}; page.Body.RowHeight = {'1x'};
            left = uigridlayout(page.Body, [5, 1]); left.Padding = [0, 0, 0, 0]; left.RowHeight = {30, '1x', 168, 44, 38};
            row = uigridlayout(left, [1, 2]); row.Padding = [0, 0, 0, 0]; row.ColumnWidth = {110, '1x'};
            uilabel(row, 'Text', '① 作り方', 'FontWeight', 'bold');
            page.Mode = uidropdown(row, 'Items', page.MODE_NAMES, 'ItemsData', page.MODE_CODES, 'ValueChangedFcn', @(~, ~) page.modeChanged());
            holder = uigridlayout(left, [1, 1]); holder.Padding = [0, 0, 0, 0];
            page.buildDataPanel(holder); page.buildSpecPanel(holder);
            page.buildConditions(AppPage.section(left, '② コピュラ・周辺分布・個数'));
            page.Plan = AppPage.stateLabel(left);
            page.RunButton = AppPage.primaryButton(left, '③ 乱数を生成', @(~, ~) page.run());
            holder = uigridlayout(page.Body, [1, 1]); holder.Padding = [0, 0, 0, 0];
            page.Result = ResultPanel(page, holder, '左の①〜③を進めると、生成した乱数の表と、元（指定）の関係との比較・散布図・分布を表示します。');
            page.resizeSpec(page.DEFAULT_VARIABLES); page.modeChanged();
            page.message(['① 作り方を選ぶ（データの列、または分布と順位相関の指定）→ ② コピュラの種類と個数 → ③ 生成。' ...
                '生成した乱数は「生成した乱数」の表を選んで「表を保存（CSV / Excel）」で保存できます。']);
        end
        % ---------- テストや他の画面から使う操作の入口 ----------
        function selectMode(page, code)
            page.Mode.Value = code; page.modeChanged();
        end
        function selectColumns(page, names)
            page.Columns.Value = cellstr(string(names(:)')); page.refreshPlan();
        end
        function setSpec(page, variables, dependence, measure)
            % variables は {名前, 分布名（画面の名前）, パラメータ1, パラメータ2, パラメータ3} の行、dependence は順位相関の行列。
            page.resizeSpec(size(variables, 1));
            for row = 1:size(variables, 1), page.Variables.Data(row, 1:5) = variables(row, 1:5); end
            page.refreshParameterHelp(); page.refreshDependenceNames(); page.Dependence.Data = num2cell(dependence); page.Measure.Value = measure; page.refreshPlan();
        end
        function run(page)
            dialog = [];
            try
                require_pro_feature('コピュラによる乱数生成');
                dialog = page.App.startProgress('コピュラによる乱数生成', 'コピュラを当てはめて、乱数を作っています。');
                if strcmp(page.Mode.Value, 'data')
                    names = cellstr(string(page.Columns.Value)); names = names(:)';
                    if isempty(page.Source.Data), error('copula:noData', '①でデータを開いてください。'); end
                    if numel(names) < 2 || numel(names) > page.MAX_COLUMNS, error('copula:columns', '①で数値の列を2〜%d列選んでください（現在 %d列）。', page.MAX_COLUMNS, numel(names)); end
                    values = extract_numeric_columns(page.Source.Data, names);
                    model = copula_fit_data(values, names, page.Family.Value, page.Marginal.Value);
                else
                    [names, marginals, dependence] = page.specification();
                    model = copula_from_spec(names, marginals, dependence, page.Measure.Value, page.Family.Value);
                end
                samples = copula_generate(model, page.SampleCount.Value, page.Seed.Value);
                AnalysisController.closeProgress(dialog);
                page.Model = model; page.Samples = samples; page.showResult(model, samples);
            catch err
                AnalysisController.closeProgress(dialog); page.showError(err);
            end
        end
        function onSettingsChanged(page)
            page.Seed.Value = page.settings().Seed;
        end
    end
    methods (Access = private)
        % ================= 画面 =================
        function buildDataPanel(page, holder)
            page.DataPanel = AppPage.section(holder, 'データと列'); page.DataPanel.Layout.Row = 1; page.DataPanel.Layout.Column = 1;
            grid = uigridlayout(page.DataPanel, [3, 1]); grid.RowHeight = {64, 22, '1x'};
            page.Source = DataSourceControl(page, grid); page.Source.LoadedFcn = @(data) page.dataLoaded(data);
            uilabel(grid, 'Text', sprintf('関係をまねる列（数値の列を2〜%d列。複数選択は Ctrl キー）', page.MAX_COLUMNS));
            page.Columns = uilistbox(grid, 'Items', {}, 'Value', {}, 'Multiselect', 'on', 'ValueChangedFcn', @(~, ~) page.refreshPlan());
        end
        function buildSpecPanel(page, holder)
            page.SpecPanel = AppPage.section(holder, '分布と順位相関の指定'); page.SpecPanel.Layout.Row = 1; page.SpecPanel.Layout.Column = 1;
            grid = uigridlayout(page.SpecPanel, [6, 2]); grid.RowHeight = {30, 30, 22, '1x', 22, '1x'}; grid.ColumnWidth = {150, '1x'};
            [~, page.VariableCount] = AppPage.numberField(grid, '変数の数（2〜10）', page.DEFAULT_VARIABLES, [2, 10], true);
            page.VariableCount.ValueChangedFcn = @(field, ~) page.resizeSpec(field.Value);
            uilabel(grid, 'Text', '順位相関の測り方');
            page.Measure = uidropdown(grid, 'Items', page.MEASURE_NAMES, 'ItemsData', page.MEASURE_CODES, 'ValueChangedFcn', @(~, ~) page.refreshPlan());
            label = uilabel(grid, 'Text', '変数ごとの分布（分布の欄をクリックして選び、パラメータを入れる）'); label.Layout.Column = [1, 2];
            info = copula_families();
            page.Variables = uitable(grid, 'RowName', {}, 'ColumnName', {'変数名', '分布', 'パラメータ1', 'パラメータ2', 'パラメータ3', 'パラメータの意味'}, ...
                'ColumnEditable', [true, true, true, true, true, false], 'ColumnFormat', {'char', {info.SpecMarginals.Name}, 'numeric', 'numeric', 'numeric', 'char'}, ...
                'ColumnWidth', {70, 70, 62, 62, 62, 'auto'}, 'CellEditCallback', @(~, ~) page.variablesEdited());
            page.Variables.Layout.Column = [1, 2];
            label = uilabel(grid, 'Text', '変数どうしの順位相関（−1〜1。i 行 j 列を変えると j 行 i 列も同じ値になります）'); label.Layout.Column = [1, 2];
            page.Dependence = uitable(grid, 'ColumnEditable', true, 'CellEditCallback', @(~, event) page.dependenceEdited(event));
            page.Dependence.Layout.Column = [1, 2];
        end
        function buildConditions(page, parent)
            grid = uigridlayout(parent, [4, 2]); grid.RowHeight = {30, 30, 30, 30}; grid.ColumnWidth = {150, '1x'};
            info = copula_families();
            uilabel(grid, 'Text', 'コピュラの種類');
            page.Family = uidropdown(grid, 'Items', {info.Families.Name}, 'ItemsData', {info.Families.Code}, 'ValueChangedFcn', @(~, ~) page.refreshPlan(), ...
                'Tooltip', '列どうしの関係の形です。t は大きい値・小さい値が同時に出やすい関係、Clayton・Frank・Gumbel は2列だけで使えます。');
            uilabel(grid, 'Text', '周辺分布（データ）');
            page.Marginal = uidropdown(grid, 'Items', {info.DataMarginals.Name}, 'ItemsData', {info.DataMarginals.Code}, ...
                'Tooltip', 'データの関係をまねるとき、各列の値の分布をどう表すかです。経験分布はデータの範囲の外の値を出しません。');
            [~, page.SampleCount] = AppPage.numberField(grid, sprintf('生成する個数（%d〜%d）', page.COUNT_LIMITS), page.DEFAULT_COUNT, page.COUNT_LIMITS, true);
            [~, page.Seed] = AppPage.numberField(grid, '乱数seed（同じ値なら同じ乱数）', page.settings().Seed, [0, 2^32 - 1], true);
            page.SampleCount.ValueChangedFcn = @(~, ~) page.refreshPlan();
        end
        function modeChanged(page)
            data_mode = strcmp(page.Mode.Value, 'data');
            page.DataPanel.Visible = matlab.lang.OnOffSwitchState(data_mode); page.SpecPanel.Visible = matlab.lang.OnOffSwitchState(~data_mode);
            page.Marginal.Enable = matlab.lang.OnOffSwitchState(data_mode); page.refreshPlan();
        end
        function dataLoaded(page, data)
            headers = data.Headers; numeric = headers(cellfun(@(name) data_column(data, name).IsNumeric, headers));
            kept = intersect(cellstr(string(page.Columns.Value)), numeric, 'stable');
            if isempty(kept), kept = numeric(1:min(numel(numeric), 3)); end
            set(page.Columns, 'Items', numeric, 'Value', kept); page.refreshPlan();
            page.message(sprintf('%s を読み込みました（%d行）。数値の列だけを一覧に出します。', page.Source.fileName(), size(data.Cells, 1)));
        end
        % ================= 指定 =================
        function resizeSpec(page, count)
            % 変数の数を変えるときは、今の値を残し、足した変数は「正規分布（平均0・標準偏差1）」、相関は0にする。
            page.VariableCount.Value = count; old = page.Variables.Data; old_dependence = page.Dependence.Data;
            rows = cell(count, 6); dependence = num2cell(eye(count));
            for row = 1:count
                if row <= size(old, 1), rows(row, :) = old(row, :); else, rows(row, :) = {sprintf('X%d', row), '正規', 0, 1, [], ''}; end
            end
            if isempty(old_dependence) && count >= 2
                dependence{1, 2} = page.DEFAULT_CORRELATION; dependence{2, 1} = page.DEFAULT_CORRELATION;
            else
                kept = min(count, size(old_dependence, 1)); dependence(1:kept, 1:kept) = old_dependence(1:kept, 1:kept);
            end
            page.Variables.Data = rows; page.Dependence.Data = dependence; page.refreshDependenceNames(); page.refreshParameterHelp(); page.refreshPlan();
        end
        function variablesEdited(page)
            page.refreshParameterHelp(); page.refreshDependenceNames(); page.refreshPlan();
        end
        function refreshParameterHelp(page)
            info = copula_families(); data = page.Variables.Data;
            for row = 1:size(data, 1)
                spec = info.SpecMarginals(strcmp({info.SpecMarginals.Name}, data{row, 2}));
                if ~isempty(spec), data{row, 6} = spec.Help; end
            end
            page.Variables.Data = data;
        end
        function refreshDependenceNames(page)
            names = cellstr(string(page.Variables.Data(:, 1)))';
            page.Dependence.ColumnName = names; page.Dependence.RowName = names;
        end
        function dependenceEdited(page, event)
            % 行列を対称に保ち、対角は1に戻す。
            row = event.Indices(1); column = event.Indices(2); data = page.Dependence.Data;
            if row == column, data{row, column} = 1; else, data{column, row} = data{row, column}; end
            page.Dependence.Data = data; page.refreshPlan();
        end
        function [names, marginals, dependence] = specification(page)
            info = copula_families(); data = page.Variables.Data; count = size(data, 1);
            names = cellstr(string(data(:, 1)))';
            if any(cellfun(@isempty, strtrim(names))) || numel(unique(names)) ~= count, error('copula:names', '変数名は空でない、重複しない名前にしてください。'); end
            marginals = cell(1, count);
            for row = 1:count
                spec = info.SpecMarginals(strcmp({info.SpecMarginals.Name}, data{row, 2}));
                if isempty(spec), error('copula:marginal', '変数「%s」の分布を選んでください。', names{row}); end
                parameters = cell2mat(data(row, 3:2 + numel(spec.Parameters)));
                if numel(parameters) ~= numel(spec.Parameters) || any(~isfinite(parameters))
                    error('copula:parameters', '変数「%s」の%s分布には、パラメータを %d 個（%s）入れてください。', names{row}, spec.Name, numel(spec.Parameters), spec.Help);
                end
                marginals{row} = struct('Code', spec.Code, 'Parameters', parameters);
            end
            dependence = cell2mat(page.Dependence.Data);
        end
        % ================= 結果 =================
        function refreshPlan(page)
            if strcmp(page.Mode.Value, 'data')
                count = numel(page.Columns.Value);
                if isempty(page.Source.Data) || count < 2
                    page.setState(page.Plan, '①でデータを開き、関係をまねる列を2列以上選んでください。', false); return;
                end
                page.setState(page.Plan, sprintf('%d列の関係をまねて、乱数を %d 行作ります。', count, page.SampleCount.Value), true);
            else
                page.setState(page.Plan, sprintf('指定した %d 変数の分布と順位相関で、乱数を %d 行作ります。', size(page.Variables.Data, 1), page.SampleCount.Value), true);
            end
        end
        function showResult(page, model, samples)
            panel = page.Result; panel.clear(); report = copula_compare(model, samples); names = model.Names;
            panel.setTable(page.TABLE_SAMPLES, array2table(samples, 'VariableNames', names));
            panel.setTable(page.TABLE_DEPENDENCE, report.Dependence); panel.setTable(page.TABLE_SUMMARY, report.Summary);
            panel.setTable(page.TABLE_PARAMETERS, page.parameterTable(model));
            page.addScatterView(model, samples);
            for column = 1:min(numel(names), page.MAX_HISTOGRAMS)
                ax = panel.addAxes(sprintf('分布: %s', names{column})); hold(ax, 'on');
                if ~isempty(model.Original)
                    histogram(ax, model.Original(:, column), 'Normalization', 'pdf', 'FaceColor', page.ORIGINAL_COLOR, 'FaceAlpha', 0.5, 'DisplayName', '元のデータ');
                end
                histogram(ax, samples(:, column), 'Normalization', 'pdf', 'FaceColor', page.GENERATED_COLOR, 'FaceAlpha', 0.5, 'DisplayName', '生成した乱数');
                xlabel(ax, names{column}, 'Interpreter', 'none'); ylabel(ax, '確率密度'); grid(ax, 'on'); legend(ax, 'Location', 'best');
                title(ax, sprintf('%s の分布（元と生成）', names{column}), 'Interpreter', 'none'); hold(ax, 'off');
            end
            info = copula_families(); family = info.Families(strcmp({info.Families.Code}, model.Family)).Name;
            difference = max(abs(report.Dependence{:, 4} - report.Dependence{:, 3}), [], 'omitnan');
            if all(isnan(report.Dependence{:, 3})), difference = max(abs(report.Dependence{:, 6} - report.Dependence{:, 5})); end
            panel.setHeadline(sprintf('%s / %d列 × %d行を生成しました。元（指定）と生成の順位相関の差は最大 %.3f。「%s」の表を「表を保存」で CSV / Excel に保存できます。', ...
                family, numel(names), size(samples, 1), difference, page.TABLE_SAMPLES));
            panel.showCharts(); page.App.applyTheme();
            page.message(sprintf('乱数を %d 行作りました（seed = %d）。', size(samples, 1), page.Seed.Value));
        end
        function output = parameterTable(~, model)
            switch model.Family
                case {'Gaussian', 't'}
                    output = array2table(model.Rho, 'VariableNames', model.Names, 'RowNames', model.Names);
                    if strcmp(model.Family, 't'), output.("自由度 ν") = repmat(model.Nu, height(output), 1); end
                otherwise
                    output = table(string(model.Family), model.Alpha, 'VariableNames', {'コピュラ', 'パラメータ α'});
            end
        end
        function addScatterView(page, model, samples)
            % 横軸・縦軸の列を選び直せる散布図。元のデータ（灰）と生成した乱数（青）を重ねる。
            tab = page.Result.addChartTab(page.CHART_SCATTER); grid = uigridlayout(tab, [2, 1]); grid.RowHeight = {32, '1x'}; grid.Padding = [4, 4, 4, 4];
            row = uigridlayout(grid, [1, 5]); row.Padding = [0, 0, 0, 0]; row.ColumnWidth = {50, 160, 50, 160, '1x'};
            names = model.Names; ax = uiaxes(grid);
            uilabel(row, 'Text', '横軸'); x_choice = uidropdown(row, 'Items', names, 'Value', names{1});
            uilabel(row, 'Text', '縦軸'); y_choice = uidropdown(row, 'Items', names, 'Value', names{2}); uilabel(row, 'Text', '');
            update = @(~, ~) drawPair(ax, model, samples, find(strcmp(names, x_choice.Value)), find(strcmp(names, y_choice.Value)), page);
            x_choice.ValueChangedFcn = update; y_choice.ValueChangedFcn = update; update();
            page.Result.registerCharts({ax}, {page.CHART_SCATTER});
        end
    end
end

function drawPair(ax, model, samples, x, y, page)
cla(ax); hold(ax, 'on');
shown = min(size(samples, 1), page.MAX_SCATTER_POINTS);
if ~isempty(model.Original)
    scatter(ax, model.Original(:, x), model.Original(:, y), 18, page.ORIGINAL_COLOR, 'filled', 'DisplayName', sprintf('元のデータ（%d点）', size(model.Original, 1)));
end
scatter(ax, samples(1:shown, x), samples(1:shown, y), 10, page.GENERATED_COLOR, 'filled', 'MarkerFaceAlpha', 0.4, ...
    'DisplayName', sprintf('生成した乱数（先頭 %d 点）', shown));
xlabel(ax, model.Names{x}, 'Interpreter', 'none'); ylabel(ax, model.Names{y}, 'Interpreter', 'none'); grid(ax, 'on');
legend(ax, 'Location', 'best'); title(ax, sprintf('%s と %s（Kendall τ：生成の先頭 %d 点で %.3f）', model.Names{x}, model.Names{y}, shown, corr(samples(1:shown, x), samples(1:shown, y), 'type', 'Kendall')), 'Interpreter', 'none');
hold(ax, 'off');
end
