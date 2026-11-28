classdef BayesPage < AppPage
    % 階層ベイズの画面（Pro 版）。左で ① データ → ② 目的変数・説明変数・グループ → ③ 条件 → ④ 実行、右に結果を表示する。
    % グループ（ロット・装置など）ごとの回帰係数を、全体の傾向へ引き寄せて推定する（データの少ないグループほど強く引き寄せる）。
    properties (SetAccess = private)
        Source
        Response
        Predictors
        Group
        Varying
        Iterations
        BurnIn
        Chains
        Plan
        RunButton
        Views
        ResultTab
        PreviewTab
        Preview
        Result
        Report = []
    end
    properties (Constant)
        LEFT_WIDTH = 440
        NONE = '(未選択)'
        VARYING_NAMES = {'切片と傾きをグループごとに推定する', '切片だけグループごと（傾きは全体で共通）'}
        VARYING_CODES = {'all', 'intercept'}
        TABLE_OVERALL = '全体の係数'
        TABLE_GROUPS = 'グループごとの係数'
        TABLE_SPREAD = 'ばらつき'
        TABLE_FITTED = '予測と残差'
        CHART_GROUPS = 'グループごとの係数'
        CHART_TRACE = '収束の確認（トレース）'
        CHART_FIT = '実測値と予測値'
        RHAT_LIMIT = 1.1
    end
    methods
        function page = BayesPage(app, parent)
            page@AppPage(app, parent);
            page.Body.ColumnWidth = {page.LEFT_WIDTH, '1x'}; page.Body.RowHeight = {'1x'};
            % 各欄に固定の高さを持たせ、入りきらないときは左の列ごと上下にスクロールする（③ の説明や ② の一覧が切れないようにするため）。
            % 最後の伸縮行は、画面が広いときに固定の行が上下に広がらないよう空の部品で埋める。
            left = uigridlayout(page.Body, [6, 1], 'Scrollable', 'on'); left.Padding = [0, 0, 6, 0];
            left.RowHeight = {104, 230, 262, 44, 38, '1x'};
            panel = AppPage.section(left, '① データを開く');
            grid = uigridlayout(panel, [1, 1]); grid.Padding = [8, 6, 8, 6];
            page.Source = DataSourceControl(page, grid); page.Source.LoadedFcn = @(data) page.dataLoaded(data);
            panel = AppPage.section(left, '② 列を選ぶ');
            grid = uigridlayout(panel, [4, 2]); grid.RowHeight = {30, 30, 22, '1x'}; grid.ColumnWidth = {150, '1x'};
            uilabel(grid, 'Text', '目的変数（数値）');
            page.Response = uidropdown(grid, 'Items', {page.NONE}, 'ValueChangedFcn', @(~, ~) page.refreshPlan());
            uilabel(grid, 'Text', 'グループの列');
            page.Group = uidropdown(grid, 'Items', {page.NONE}, 'ValueChangedFcn', @(~, ~) page.refreshPlan(), ...
                'Tooltip', 'ロット・装置名など、係数を分けたい単位の列です（文字の列も選べます）。');
            label = uilabel(grid, 'Text', '説明変数（数値。複数選択は Ctrl キー）'); label.Layout.Column = [1, 2];
            page.Predictors = uilistbox(grid, 'Items', {}, 'Value', {}, 'Multiselect', 'on', 'ValueChangedFcn', @(~, ~) page.refreshPlan());
            page.Predictors.Layout.Column = [1, 2];
            panel = AppPage.section(left, '③ 条件');
            % 選択肢の文（「切片だけグループごと（傾きは全体で共通）」など）が切れないよう、係数の選び方は欄の幅いっぱいに置く。
            % 下の説明（2〜3行）まで見えるよう、欄の高さ（左の列の3行目）も合わせて決めている。
            grid = uigridlayout(panel, [6, 2]); grid.RowHeight = {22, 30, 30, 30, 30, '1x'}; grid.ColumnWidth = {200, '1x'};
            label = uilabel(grid, 'Text', 'グループごとに推定する係数'); label.Layout.Column = [1, 2];
            page.Varying = uidropdown(grid, 'Items', page.VARYING_NAMES, 'ItemsData', page.VARYING_CODES);
            page.Varying.Layout.Column = [1, 2];
            [~, page.Iterations] = AppPage.numberField(grid, 'MCMC の繰り返し回数', 2000, [200, 50000], true);
            [~, page.BurnIn] = AppPage.numberField(grid, '最初に捨てる回数（バーンイン）', 1000, [0, 49000], true);
            [~, page.Chains] = AppPage.numberField(grid, '鎖（チェーン）の数', 2, [1, 4], true);
            label = AppPage.hint(grid, 'R-hat（2本以上の鎖で計算）が1.1以上の量は収束していない可能性があります。回数を増やしてください。乱数seedは「設定」の値です。');
            label.Layout.Column = [1, 2];
            page.Plan = AppPage.stateLabel(left);
            page.RunButton = AppPage.primaryButton(left, '④ 階層ベイズを実行', @(~, ~) page.run());
            AppPage.fillLastRow(left);
            page.Views = uitabgroup(page.Body);
            page.ResultTab = uitab(page.Views, 'Title', '結果'); grid = uigridlayout(page.ResultTab, [1, 1]);
            page.Result = ResultPanel(page, grid, '左の①〜④を進めると、ここにグループごとの係数と収束の確認を表示します。');
            page.PreviewTab = uitab(page.Views, 'Title', '入力プレビュー'); grid = uigridlayout(page.PreviewTab, [1, 1]);
            page.Preview = uitable(grid, 'RowName', 'numbered'); page.Source.PreviewTable = page.Preview;
            page.refreshPlan();
            page.message('① データを開く → ② 目的変数・グループ・説明変数を選ぶ → ③ 条件 → ④ 実行。');
        end
        function selectColumns(page, response, predictors, group)
            page.Response.Value = response; page.Predictors.Value = cellstr(string(predictors(:)')); page.Group.Value = group; page.refreshPlan();
        end
        function run(page)
            dialog = [];
            try
                require_pro_feature('階層ベイズ');
                data = page.Source.Data;
                if isempty(data), error('bayes:noData', '①でデータを開いてください。'); end
                if strcmp(page.Response.Value, page.NONE) || strcmp(page.Group.Value, page.NONE)
                    error('bayes:columns', '②で目的変数とグループの列を選んでください。');
                end
                names = cellstr(string(page.Predictors.Value)); names = names(:)';
                if any(strcmp(names, page.Response.Value)) || any(strcmp(names, page.Group.Value)) || strcmp(page.Response.Value, page.Group.Value)
                    error('bayes:overlap', '目的変数・グループの列・説明変数には、それぞれ別の列を選んでください。');
                end
                response = extract_numeric_columns(data, {page.Response.Value});
                predictors = zeros(numel(response), 0); if ~isempty(names), predictors = extract_numeric_columns(data, names); end
                [groups, group_names] = encode_categories(data, page.Group.Value);
                dialog = page.App.startProgress('階層ベイズ', 'MCMC（ギブスサンプリング）で計算しています。', true);
                options = struct('Varying', page.Varying.Value, 'Iterations', page.Iterations.Value, 'BurnIn', page.BurnIn.Value, ...
                    'Chains', page.Chains.Value, 'Seed', page.settings().Seed, ...
                    'Progress', AnalysisController.progressReporter(dialog, '階層ベイズを中止しました。今回の結果は表示していません。以前の結果は残っています。'));
                report = hierarchical_bayes(response, predictors, groups, names, group_names, options);
                AnalysisController.closeProgress(dialog);
                page.Report = report; page.showReport(report, response, group_names, groups);
            catch err
                AnalysisController.closeProgress(dialog); page.showError(err);
            end
        end
    end
    methods (Access = private)
        function dataLoaded(page, data)
            headers = data.Headers; numeric = headers(cellfun(@(name) data_column(data, name).IsNumeric, headers));
            keepOr(page.Response, [{page.NONE}, numeric], page.NONE); keepOr(page.Group, [{page.NONE}, headers], page.NONE);
            set(page.Predictors, 'Items', numeric, 'Value', intersect(cellstr(string(page.Predictors.Value)), numeric, 'stable'));
            page.Views.SelectedTab = page.PreviewTab; page.refreshPlan();
            page.message(sprintf('%s を読み込みました（%d行）。', page.Source.fileName(), size(data.Cells, 1)));
        end
        function refreshPlan(page)
            if isempty(page.Source.Data), page.setState(page.Plan, '①でデータを開いてください。', false); return; end
            if strcmp(page.Response.Value, page.NONE) || strcmp(page.Group.Value, page.NONE)
                page.setState(page.Plan, '②で目的変数とグループの列を選んでください。', false); return;
            end
            page.setState(page.Plan, sprintf('目的変数 %s を、説明変数 %d列・グループ「%s」ごとの係数で当てはめます。', ...
                page.Response.Value, numel(page.Predictors.Value), page.Group.Value), true);
        end
        function showReport(page, report, response, group_names, groups)
            panel = page.Result; panel.clear();
            panel.setTable(page.TABLE_OVERALL, report.Overall); panel.setTable(page.TABLE_GROUPS, report.Groups);
            panel.setTable(page.TABLE_SPREAD, report.Spread);
            panel.setTable(page.TABLE_FITTED, table(page.Source.Data.RowNumbers, string(group_names(groups)), response, report.Fitted, report.Residual, ...
                'VariableNames', {'SourceRow', 'グループ', '実測', '予測_事後平均', '残差'}));
            page.drawGroups(report, group_names);
            ax = panel.addAxes(page.CHART_TRACE); hold(ax, 'on');
            for chain = 1:size(report.TraceSigma, 2)
                plot(ax, report.TraceSigma(:, chain), 'DisplayName', sprintf('鎖 %d', chain));
            end
            xlabel(ax, 'バーンイン後の繰り返し'); ylabel(ax, '残差の標準偏差 σ'); legend(ax, 'Location', 'best'); grid(ax, 'on');
            title(ax, '収束の確認：鎖どうしが重なって横ばいなら収束の目安'); hold(ax, 'off');
            ax = panel.addAxes(page.CHART_FIT); hold(ax, 'on');
            scatter(ax, response, report.Fitted, 24, groups, 'filled'); colormap(ax, lines(numel(group_names)));
            limits = [min([response; report.Fitted]), max([response; report.Fitted])]; plot(ax, limits, limits, '--');
            xlabel(ax, '実測値'); ylabel(ax, '予測値（グループごとの係数の事後平均）'); grid(ax, 'on');
            title(ax, '実測値と予測値（色はグループ。学習に使ったデータでの当てはまり）'); hold(ax, 'off');
            rmse = sqrt(mean(report.Residual.^2));
            caution = ''; if report.MaxRhat >= page.RHAT_LIMIT, caution = sprintf(' R-hat の最大 %.3f が1.1以上です。回数を増やしてください。', report.MaxRhat); end
            panel.setHeadline(sprintf('グループ %d個・%d行。RMSE %.4g（学習データ）、R-hat の最大 %.3f。%s', ...
                numel(group_names), numel(response), rmse, report.MaxRhat, caution));
            panel.showCharts(); page.Views.SelectedTab = page.ResultTab; page.App.applyTheme();
            if ~isempty(caution), page.showWarnings(string(strtrim(caution))); end
            page.message('階層ベイズの計算が終わりました。');
        end
        function drawGroups(page, report, group_names)
            % グループごとの係数（事後平均と95%区間）を、グループ単独の最小二乗（×）と全体の平均（縦線）と並べる。
            % データの少ないグループほど、区間の中心が全体の平均へ引き寄せられる（縮小）。
            tab = page.Result.addChartTab(page.CHART_GROUPS); holder = uigridlayout(tab, [1, 1]); holder.Padding = [4, 4, 4, 4];
            container = uipanel(holder, 'BorderType', 'none'); varying = report.Varying;
            plots = uigridlayout(container, [1, numel(varying)]); plots.Padding = [0, 0, 0, 0];
            charts = {container}; names = {sprintf('%s（並べた図）', page.CHART_GROUPS)}; count = numel(group_names);
            for index = 1:numel(varying)
                term = report.TermNames(varying(index)); rows = report.Groups(report.Groups.("項") == term, :);
                ax = uiaxes(plots); hold(ax, 'on');
                errorbar(ax, rows.("事後平均"), 1:count, rows.("事後平均") - rows.("下限_2_5"), rows.("上限_97_5") - rows.("事後平均"), ...
                    'horizontal', 'o', 'MarkerFaceColor', [0.12, 0.35, 0.58], 'DisplayName', '事後平均と95%区間');
                plot(ax, rows.("グループ単独の最小二乗"), 1:count, 'x', 'MarkerSize', 9, 'LineWidth', 1.5, 'DisplayName', 'グループ単独の最小二乗');
                overall = report.Overall.("事後平均")(report.Overall.("項") == term);
                xline(ax, overall, '--', 'DisplayName', '全体の平均');
                ax.YTick = 1:count; ax.YTickLabel = cellstr(string(group_names) + "（" + string(rows.("件数")) + "件）");
                ax.TickLabelInterpreter = 'none'; ax.YDir = 'reverse'; grid(ax, 'on');
                xlabel(ax, char(term), 'Interpreter', 'none'); title(ax, sprintf('%s：グループごとの値', term), 'Interpreter', 'none');
                if index == 1, legend(ax, 'Location', 'best'); end
                hold(ax, 'off'); charts{end + 1} = ax; names{end + 1} = sprintf('%s：%s', page.CHART_GROUPS, term); %#ok<AGROW>
            end
            page.Result.registerCharts(charts, names);
        end
    end
end

function keepOr(dropdown, items, fallback)
previous = dropdown.Value; dropdown.Items = items;
if any(strcmp(items, previous)), dropdown.Value = previous; else, dropdown.Value = fallback; end
end
