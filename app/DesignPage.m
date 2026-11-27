classdef DesignPage < AppPage
    % 実験計画作成の画面。左で条件を決め、右に計画・交絡の表とグラフを表示する。
    % 既存の計画に点を追加する拡張計画（拡張 D最適・拡張 I最適）は Pro 版だけ。通常版では選択肢と「② 既存の計画」を出さない。
    properties (SetAccess = private)
        IsPro
        Method
        DesignModel
        Factors
        Levels
        Runs
        ExistingPanel = []
        Source = []
        Mapper = []
        ClearButton = []
        RunButton
        Result
    end
    properties (Constant)
        LEFT_WIDTH = 440
        METHODS = {'D最適', 'I最適', '直交表', '拡張 D最適（既存の計画に追加）', '拡張 I最適（既存の計画に追加）'}
        METHOD_CODES = {'D', 'I', 'orthogonal', 'D', 'I'}
        AUGMENTED = [false, false, false, true, true]
        MODEL_LABELS = {'2次（主効果＋交互作用＋2乗）', '交互作用（主効果＋2因子交互作用）', '1次（主効果のみ）'}
        MODEL_CODES = {'quadratic', 'interaction', 'linear'}
        LEVEL_CHOICES = {'2', '3', '4', '5'}
        DEFAULT_LEVELS = '3'
        MAX_FACTORS = 8
        MAX_RUNS = 300
        TABLE_DESIGN = '実験計画'
        TABLE_DEPENDENCY = '交絡の線形関係'
        TABLE_METRICS = '計画の評価指標'
        CHART_CONFOUNDING = '交絡の可視化'
        CHART_VARIANCE = '予測分散の分布（FDS）'
    end
    methods
        function page = DesignPage(app, parent)
            page@AppPage(app, parent);
            page.IsPro = strcmp(app.Edition, 'pro');
            page.Body.ColumnWidth = {page.LEFT_WIDTH, '1x'}; page.Body.RowHeight = {'1x'};
            page.buildInputs();
            holder = uigridlayout(page.Body, [1, 1]); holder.Padding = [0, 0, 0, 0];
            page.Result = ResultPanel(page, holder, '左で条件を決めて「実験計画を作成」を押すと、ここに計画と交絡の確認結果を表示します。');
            page.methodChanged();
            if page.IsPro
                page.message('値は −1〜1 の符号化値です（因子の下限を −1、上限を 1 とします）。既存の実験に追加する場合は「拡張」を選びます。');
            else
                page.message('値は −1〜1 の符号化値です（因子の下限を −1、上限を 1 とします）。');
            end
        end
        function run(page)
            dialog = [];
            try
                choice = find(strcmp(page.METHODS, page.Method.Value), 1); factors = page.Factors.Value;
                existing = zeros(0, factors);
                if page.AUGMENTED(choice)
                    if ~page.IsPro, error('doe:proOnly', '既存の計画に点を追加する拡張計画は Pro 版だけで使えます。'); end
                    if isempty(page.Source.Data), error('doe:noExisting', '「② 既存の計画」で、既存の実験点のファイルを開いてください。'); end
                    page.Mapper.requireComplete(); mapping = page.Mapper.mapping();
                    existing = assign_required_columns(page.Source.Data, mapping(:, 2), mapping(:, 3));
                end
                settings = page.settings(); model = page.DesignModel.Value;
                dialog = page.App.startProgress('実験計画作成', '計画を探索しています。', true);
                reporter = AnalysisController.progressReporter(dialog, '実験計画の作成を中止しました。今回の結果は表示していません。以前の結果は残っています。');
                [design, details] = create_experiment_design(page.METHOD_CODES{choice}, factors, page.Runs.Value, settings.Seed, ...
                    model, str2double(page.Levels.Value), existing, reporter);
                report = design_diagnostics(design, model); metrics = design_metrics(design, model);
                AnalysisController.closeProgress(dialog);
                page.showDesign(design, details, report, metrics);
            catch err
                AnalysisController.closeProgress(dialog); page.showError(err);
            end
        end
    end
    methods (Access = private)
        function buildInputs(page)
            settings = page.settings();
            left = uigridlayout(page.Body, [3, 1]); left.Padding = [0, 0, 0, 0]; left.RowHeight = {220, '1x', 38};
            if ~page.IsPro, left.RowHeight = {220, 38, '1x'}; end
            panel = AppPage.section(left, '① 計画の条件');
            grid = uigridlayout(panel, [5, 2]); grid.RowHeight = {30, 30, 30, 30, 30}; grid.ColumnWidth = {170, '1x'};
            uilabel(grid, 'Text', '方式');
            methods_shown = page.METHODS(~page.AUGMENTED | page.IsPro);
            page.Method = uidropdown(grid, 'Items', methods_shown, 'ValueChangedFcn', @(~, ~) page.methodChanged());
            uilabel(grid, 'Text', '評価するモデル');
            page.DesignModel = uidropdown(grid, 'Items', page.MODEL_LABELS, 'ItemsData', page.MODEL_CODES);
            [~, page.Factors] = AppPage.numberField(grid, sprintf('因子数（1〜%d）', page.MAX_FACTORS), settings.Factors, [1, page.MAX_FACTORS], true);
            page.Factors.ValueChangedFcn = @(~, ~) page.refreshRoles();
            uilabel(grid, 'Text', '水準数（2〜5）');
            page.Levels = uidropdown(grid, 'Items', page.LEVEL_CHOICES, 'Value', page.DEFAULT_LEVELS);
            runs_label = '実験数'; if page.IsPro, runs_label = '実験数（拡張では追加数）'; end
            [~, page.Runs] = AppPage.numberField(grid, runs_label, settings.Runs, [1, page.MAX_RUNS], true);

            if ~page.IsPro
                page.RunButton = AppPage.primaryButton(left, '実験計画を作成', @(~, ~) page.run());
                AppPage.fillLastRow(left);
                return;
            end
            page.ExistingPanel = AppPage.section(left, '② 既存の計画（「拡張」を選んだときに使用）');
            grid = uigridlayout(page.ExistingPanel, [4, 1]); grid.RowHeight = {40, 70, '1x', 30};
            AppPage.hint(grid, '既存の実験点（−1〜1に符号化した値）のファイルを開き、因子ごとに列を選びます。既存の点は値と順序を保ち、追加の点を後ろへ並べます。');
            page.Source = DataSourceControl(page, grid, [], '既存の計画を開く'); page.Source.LoadedFcn = @(~) page.refreshRoles();
            holder = uigridlayout(grid, [1, 1]); holder.Padding = [0, 0, 0, 0];
            page.Mapper = ColumnMapper(holder);
            page.ClearButton = uibutton(grid, 'Text', '既存の計画を解除', 'ButtonPushedFcn', @(~, ~) page.clearExisting());
            page.RunButton = AppPage.primaryButton(left, '実験計画を作成', @(~, ~) page.run());
        end
        function methodChanged(page)
            choice = find(strcmp(page.METHODS, page.Method.Value), 1);
            orthogonal = strcmp(page.METHOD_CODES{choice}, 'orthogonal');
            % 直交表は必要な実験数を自動で決めるため、実験数の入力を使わない。
            page.Runs.Enable = matlab.lang.OnOffSwitchState(~orthogonal);
            if ~page.IsPro, return; end
            enabled = matlab.lang.OnOffSwitchState(page.AUGMENTED(choice));
            page.Source.OpenButton.Enable = enabled; page.ClearButton.Enable = enabled;
            page.refreshRoles();
        end
        function refreshRoles(page)
            if ~page.IsPro, return; end
            headers = {};
            if ~isempty(page.Source.Data), headers = page.Source.Data.Headers; end
            roles = cellstr("F" + string(1:page.Factors.Value));
            page.Mapper.setRoles(roles, headers, '既存の計画を開くと、因子（F1, F2, …）ごとに列を選ぶ欄を表示します。');
        end
        function clearExisting(page)
            page.Source.clear(); page.refreshRoles(); page.message('既存の計画を解除しました。');
        end
        function showDesign(page, design, details, report, metrics)
            panel = page.Result; panel.clear();
            output = array2table(design, 'VariableNames', cellstr("F" + string(1:size(design, 2))));
            kind = repmat("追加", size(design, 1), 1); kind(1:details.FixedRows) = "既存";
            output = addvars(output, (1:size(design, 1))', kind, 'Before', 1, 'NewVariableNames', {'Run', 'Type'});
            % 既存・追加の区別は拡張計画（Pro 版）のときだけ意味を持つ。
            if ~page.IsPro, output = removevars(output, 'Type'); end
            panel.setTable(page.TABLE_DESIGN, output);
            panel.setTable(page.TABLE_METRICS, metrics.Table);
            if ~isempty(report.Dependencies)
                columns = cellstr("関係" + string(1:size(report.Dependencies, 2)));
                panel.setTable(page.TABLE_DEPENDENCY, array2table(report.Dependencies, 'VariableNames', columns, 'RowNames', cellstr(report.Names)));
            end
            ax = panel.addAxes(page.CHART_CONFOUNDING);
            image = imagesc(ax, report.Similarity, [0, 1]); image.AlphaData = isfinite(report.Similarity);
            colorbar(ax); ax.XTick = 1:numel(report.Names); ax.YTick = ax.XTick;
            ax.XTickLabel = report.Names; ax.YTickLabel = report.Names; ax.XTickLabelRotation = 60; ax.TickLabelInterpreter = 'none';
            axis(ax, 'tight'); ax.YDir = 'reverse';
            title(ax, sprintf('2次モデルの項どうしの重なり |cosθ|（1＝区別できない、0＝直交） ランク %d / %d', report.FullRank, report.FullTerms));
            if ~isempty(metrics.Variance)
                ax = panel.addAxes(page.CHART_VARIANCE); hold(ax, 'on');
                fraction = (1:numel(metrics.Variance))' / numel(metrics.Variance);
                plot(ax, fraction, metrics.Variance, 'LineWidth', 1.8, 'DisplayName', '予測分散');
                yline(ax, metrics.Values.ICriterion, '--', sprintf('I基準（平均） %.3g', metrics.Values.ICriterion), 'DisplayName', 'I基準（平均）');
                xlabel(ax, '領域のうち、予測分散がその値以下の割合'); ylabel(ax, '予測分散（誤差分散を1とした値）'); grid(ax, 'on');
                title(ax, '予測分散の分布（FDS：低く平らな線ほど、領域全体で予測が安定）'); hold(ax, 'off');
            end
            headline = sprintf('実験数 %d / 選んだモデルのランク %d / %d 項', size(design, 1), report.Rank, report.Terms);
            if page.IsPro
                headline = sprintf('実験数 %d（既存 %d ＋ 追加 %d） / 選んだモデルのランク %d / %d 項', ...
                    size(design, 1), details.FixedRows, details.AddedRows, report.Rank, report.Terms);
            end
            values = metrics.Values;
            panel.setHeadline(sprintf('%s\nD効率 %.1f%%　A効率 %.1f%%　I基準 %.4g　G効率 %.1f%%　最大VIF %.3g（詳しくは「%s」の表）', headline, ...
                values.DEfficiency, values.AEfficiency, values.ICriterion, values.GEfficiency, values.MaxVIF, page.TABLE_METRICS));
            panel.showTable(page.TABLE_METRICS); page.App.applyTheme();
            page.message(sprintf('計画を作成しました（seed=%d）。D最適・I最適は局所探索のため、最良の計画である保証はありません。', details.Seed));
            if report.Rank < report.Terms
                page.showWarnings("ランク不足です。選んだモデルのすべての係数を独立には推定できません。実験数を増やすか、モデルを簡単にしてください。");
            end
            if ~isempty(report.Dependencies)
                page.message(sprintf('「%s」の各列は、係数を掛けて足すと0になる項の組合せ（区別できない関係）を表します。', page.TABLE_DEPENDENCY));
            end
        end
    end
end
