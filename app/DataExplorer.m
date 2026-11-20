classdef DataExplorer < handle
    % 読み込んだデータの傾向をグラフで確認する部品（モデルを作る画面の「① データを開く」の中）。
    % 通常版：単変量の傾向（横軸＝レコードまたは任意の列、縦軸＝任意の列、色＝任意の列。文字の列＝質的変数にも対応）。
    % Pro 版：上に加えて、ヒストグラム、相関マトリックス、分散分析（ANOVA）、Parallel Coordinates、
    %         Parallel Sets、Sankey Diagram、主成分分析（PCA）、クラスタリング。
    % 学習に使うデータや列の選択は変えない（見るだけ）。
    properties (SetAccess = private)
        IsPro
        Kind
        XAxis
        YAxis
        Color
        ColorMode
        Columns
        ClusterMethod
        ClusterCount
        Guide
        DrawButton
        Result
        Data = []
    end
    properties (Access = private)
        Owner
    end
    properties (Constant)
        RECORD = 'レコード（行の順番）'
        NO_COLOR = '(単色)'
        KIND_NAMES = {'単変量の傾向（散布図）', 'ヒストグラム', '相関マトリックス', '分散分析（ANOVA）', ...
            'Parallel Coordinates', 'Parallel Sets', 'Sankey Diagram', '主成分分析（PCA）', 'クラスタリング'}
        KIND_CODES = {'trend', 'histogram', 'correlation', 'anova', 'parallel', 'sets', 'sankey', 'pca', 'cluster'}
        COLOR_MODE_NAMES = {'自動（文字の列・種類が10以下の数値はグループ）', '量的（連続した色）', '質的（グループごとの色）'}
        COLOR_MODE_CODES = {'auto', 'numeric', 'category'}
        CLUSTER_METHOD_NAMES = {'k-means 法', 'Ward 法（階層型）'}
        CLUSTER_METHOD_CODES = {'kmeans', 'ward'}
        AUTO_CATEGORY_LIMIT = 10
        MAX_LEGEND_GROUPS = 20
        FLOW_LEVELS = 6
        MAX_FLOW_COLUMNS = 6
        MAX_HISTOGRAMS = 12
        MAX_ANOVA_FACTORS = 4
        DEFAULT_CLUSTERS = 3
        MARKER_SIZE = 24
        LEFT_WIDTH = 320
        GUIDES = struct( ...
            'trend', '縦軸の列の値を、横軸（レコードの順番、または任意の列）に対して点で表示します。色の列は文字（質的変数）でも数値でも使えます。', ...
            'histogram', '「列」で選んだ数値の列ごとに、値の分布をヒストグラムで表示します（最大12列）。色の列を選ぶとグループごとに重ねます。', ...
            'correlation', '「列」で選んだ数値の列どうしの相関係数（Pearson）を色と数値で表示します。空欄は組ごとに除きます。', ...
            'anova', '縦軸の列（数値）が、「列」で選んだ要因（1〜4列）の水準で違うかを分散分析で調べます。数値の要因は6区間に分けます。', ...
            'parallel', '「列」で選んだ数値の列を縦軸として並べ、1行を1本の線で表示します（各軸は最小〜最大で目盛ります）。色の列でグループ分けできます。', ...
            'sets', '「列」で選んだ列（2〜6列。数値は6区間に分けます）の値の組み合わせを帯で表示します。帯の太さは行数、色は最初の列の値です。', ...
            'sankey', '「列」で選んだ列（2〜6列。数値は6区間に分けます）の隣り合う列の間で、値がどう移るかを流れで表示します。', ...
            'pca', '「列」で選んだ数値の列（2列以上）を標準化して主成分分析を行い、主成分得点・寄与率・負荷量を表示します。', ...
            'cluster', '「列」で選んだ数値の列（2列以上）を標準化して群に分けます。群の数の目安（エルボー図）とシルエット係数も表示します。')
    end
    methods
        function explorer = DataExplorer(owner, parent, is_pro)
            explorer.Owner = owner; explorer.IsPro = is_pro;
            grid = uigridlayout(parent, [1, 2]); grid.ColumnWidth = {explorer.LEFT_WIDTH, '1x'}; grid.Padding = [4, 4, 4, 4];
            left = uigridlayout(grid, [11, 2]); left.Padding = [0, 0, 0, 0]; left.ColumnWidth = {80, '1x'};
            left.RowHeight = {30, 30, 30, 30, 30, 22, '1x', 30, 30, 70, 38};
            kinds = 1; if is_pro, kinds = 1:numel(explorer.KIND_CODES); end
            uilabel(left, 'Text', 'グラフ');
            explorer.Kind = uidropdown(left, 'Items', explorer.KIND_NAMES(kinds), 'ItemsData', explorer.KIND_CODES(kinds), ...
                'ValueChangedFcn', @(~, ~) explorer.kindChanged());
            uilabel(left, 'Text', '横軸');
            explorer.XAxis = uidropdown(left, 'Items', {explorer.RECORD});
            uilabel(left, 'Text', '縦軸');
            explorer.YAxis = uidropdown(left, 'Items', {'(データ未選択)'});
            uilabel(left, 'Text', '色');
            explorer.Color = uidropdown(left, 'Items', {explorer.NO_COLOR}, 'Tooltip', '点や線を色分けする列です。文字の列はグループごとの色になります。');
            uilabel(left, 'Text', '色の扱い');
            explorer.ColorMode = uidropdown(left, 'Items', explorer.COLOR_MODE_NAMES, 'ItemsData', explorer.COLOR_MODE_CODES, ...
                'Tooltip', '数値の列をグループ（質的変数）として色分けするか、連続した色（量的変数）で表すかを選びます。');
            label = uilabel(left, 'Text', '列（複数選択は Ctrl キーを押しながらクリック）'); label.Layout.Column = [1, 2];
            explorer.Columns = uilistbox(left, 'Items', {}, 'Value', {}, 'Multiselect', 'on'); explorer.Columns.Layout.Column = [1, 2];
            uilabel(left, 'Text', '群の分け方');
            explorer.ClusterMethod = uidropdown(left, 'Items', explorer.CLUSTER_METHOD_NAMES, 'ItemsData', explorer.CLUSTER_METHOD_CODES);
            [~, explorer.ClusterCount] = AppPage.numberField(left, '群の数', explorer.DEFAULT_CLUSTERS, [2, 10], true);
            explorer.Guide = AppPage.hint(left, ''); explorer.Guide.Layout.Column = [1, 2];
            explorer.DrawButton = AppPage.primaryButton(left, 'グラフを描く', @(~, ~) explorer.draw());
            explorer.DrawButton.Layout.Column = [1, 2];
            holder = uigridlayout(grid, [1, 1]); holder.Padding = [0, 0, 0, 0];
            explorer.Result = ResultPanel(owner, holder, '左でグラフの種類と列を選び、「グラフを描く」を押すと、ここに表示します。');
            explorer.kindChanged();
        end
        function setData(explorer, data)
            % データを開き直したら、列の選択肢を更新する（同じ名前の列の選択は残す）。
            explorer.Data = data; headers = data.Headers;
            numeric = headers(cellfun(@(name) data_column(data, name).IsNumeric, headers));
            keepOr(explorer.XAxis, [{explorer.RECORD}, headers], explorer.RECORD);
            default_y = '(数値の列がありません)'; if ~isempty(numeric), default_y = numeric{1}; end
            keepOr(explorer.YAxis, headers, default_y);
            keepOr(explorer.Color, [{explorer.NO_COLOR}, headers], explorer.NO_COLOR);
            chosen = intersect(cellstr(string(explorer.Columns.Value)), headers, 'stable');
            if isempty(chosen), chosen = numeric(1:min(numel(numeric), explorer.FLOW_LEVELS)); end
            set(explorer.Columns, 'Items', headers, 'Value', chosen);
            explorer.Result.clear();
        end
        function configure(explorer, settings)
            % テストや他の画面から、選択をまとめて設定する入口（フィールド名は Kind・X・Y・Color・ColorMode・Columns・ClusterMethod・ClusterCount）。
            names = fieldnames(settings);
            for index = 1:numel(names)
                value = settings.(names{index});
                switch names{index}
                    case 'Kind', explorer.Kind.Value = value; explorer.kindChanged();
                    case 'X', explorer.XAxis.Value = value;
                    case 'Y', explorer.YAxis.Value = value;
                    case 'Color', explorer.Color.Value = value;
                    case 'ColorMode', explorer.ColorMode.Value = value;
                    case 'Columns', explorer.Columns.Value = cellstr(string(value));
                    case 'ClusterMethod', explorer.ClusterMethod.Value = value;
                    case 'ClusterCount', explorer.ClusterCount.Value = value;
                    otherwise, error('DataExplorer:setting', '設定できない項目です: %s', names{index});
                end
            end
        end
        function draw(explorer)
            try
                if isempty(explorer.Data), error('DataExplorer:noData', '先に「Excel / CSV を開く」でデータを開いてください。'); end
                kind = explorer.Kind.Value;
                if ~strcmp(kind, 'trend')
                    if ~explorer.IsPro, error('AnalysisApp:proOnly', 'このグラフは Pro 版だけで使えます。'); end
                    require_pro_feature('このグラフ');
                end
                panel = explorer.Result; panel.clear();
                switch kind
                    case 'trend', explorer.drawTrend();
                    case 'histogram', explorer.drawHistograms();
                    case 'correlation', explorer.drawCorrelation();
                    case 'anova', explorer.drawAnova();
                    case 'parallel', explorer.drawParallel();
                    case {'sets', 'sankey'}, explorer.drawFlows(kind);
                    case 'pca', explorer.drawPca();
                    case 'cluster', explorer.drawClusters();
                end
                panel.showCharts(); explorer.Owner.App.applyTheme();
                explorer.Owner.message(sprintf('グラフを描きました: %s', explorer.KIND_NAMES{strcmp(explorer.KIND_CODES, kind)}));
            catch err
                explorer.Owner.showError(err);
            end
        end
    end
    methods (Access = private)
        % ================= 画面 =================
        function kindChanged(explorer)
            kind = explorer.Kind.Value;
            uses = struct('X', {{'trend'}}, 'Y', {{'trend', 'anova'}}, 'Color', {{'trend', 'histogram', 'parallel', 'pca'}}, ...
                'Columns', {{'histogram', 'correlation', 'anova', 'parallel', 'sets', 'sankey', 'pca', 'cluster'}}, 'Cluster', {{'cluster'}});
            enable = @(names) matlab.lang.OnOffSwitchState(any(strcmp(names, kind)));
            explorer.XAxis.Enable = enable(uses.X); explorer.YAxis.Enable = enable(uses.Y);
            explorer.Color.Enable = enable(uses.Color); explorer.ColorMode.Enable = enable({'trend', 'pca'});
            explorer.Columns.Enable = enable(uses.Columns);
            explorer.ClusterMethod.Enable = enable(uses.Cluster); explorer.ClusterCount.Enable = enable(uses.Cluster);
            explorer.Guide.Text = explorer.GUIDES.(kind);
        end

        % ================= 単変量の傾向 =================
        function drawTrend(explorer)
            data = explorer.Data; y = explorer.numericColumn(explorer.YAxis.Value, '縦軸');
            rows = numel(y.Numbers); categories = strings(0, 1);
            if strcmp(explorer.XAxis.Value, explorer.RECORD)
                x = (1:rows)'; x_label = 'レコード（データの行の順番）';
            else
                column = data_column(data, explorer.XAxis.Value); x_label = column.Name;
                if column.IsNumeric
                    x = column.Numbers;
                else
                    [x, categories] = category_groups(column, Inf); x = double(x);
                end
            end
            ax = explorer.Result.addAxes(sprintf('%s の傾向', y.Name)); hold(ax, 'on');
            shown = isfinite(x) & isfinite(y.Numbers);
            if strcmp(explorer.XAxis.Value, explorer.RECORD)
                % レコードの順番に対する傾向は、点を細い線でつないで変化を追いやすくする。
                plot(ax, x(shown), y.Numbers(shown), '-', 'Color', [0.7, 0.7, 0.7], 'HandleVisibility', 'off');
            end
            points = explorer.coloredScatter(ax, x, y.Numbers, shown);
            if ~isempty(categories)
                ax.XTick = 1:numel(categories); ax.XTickLabel = categories; ax.TickLabelInterpreter = 'none';
                for index = 1:numel(points), points(index).XJitter = 'density'; points(index).XJitterWidth = 0.4; end
            end
            xlabel(ax, x_label, 'Interpreter', 'none'); ylabel(ax, y.Name, 'Interpreter', 'none'); grid(ax, 'on');
            title(ax, sprintf('%s の傾向（%d点）', y.Name, sum(shown)), 'Interpreter', 'none'); hold(ax, 'off');
            explorer.Result.setTable('縦軸の要約', explorer.summaryByGroup(y.Numbers));
            explorer.Result.setHeadline(sprintf('縦軸: %s / 横軸: %s / 色: %s', y.Name, explorer.XAxis.Value, explorer.Color.Value));
        end
        function points = coloredScatter(explorer, ax, x, y, shown)
            % 色の列に応じて、単色・量的（連続した色）・質的（グループごとの色と凡例）で点を描く。
            [mode, column] = explorer.colorChoice();
            switch mode
                case 'none'
                    points = scatter(ax, x(shown), y(shown), explorer.MARKER_SIZE, 'filled', 'DisplayName', 'データ');
                case 'numeric'
                    values = column.Numbers;
                    points = scatter(ax, x(shown), y(shown), explorer.MARKER_SIZE, values(shown), 'filled');
                    colormap(ax, parula(256)); scale = colorbar(ax); scale.Label.String = column.Name; scale.Label.Interpreter = 'none';
                otherwise
                    [groups, names] = category_groups(column, Inf);
                    colors = lines(numel(names)); points = gobjects(0);
                    for group = 1:numel(names)
                        member = shown & groups == group;
                        if ~any(member), continue; end
                        points(end + 1) = scatter(ax, x(member), y(member), explorer.MARKER_SIZE, colors(group, :), 'filled', ...
                            'DisplayName', char(names(group))); %#ok<AGROW>
                    end
                    if numel(names) <= explorer.MAX_LEGEND_GROUPS
                        legend(ax, points, 'Location', 'bestoutside', 'Interpreter', 'none');
                    end
            end
        end
        function [mode, column] = colorChoice(explorer)
            % 色の扱い：自動では文字の列と、種類が少ない数値の列をグループ（質的変数）にする。
            mode = 'none'; column = [];
            if strcmp(explorer.Color.Value, explorer.NO_COLOR) || strcmp(explorer.Color.Enable, 'off'), return; end
            column = data_column(explorer.Data, explorer.Color.Value); requested = explorer.ColorMode.Value;
            if strcmp(explorer.ColorMode.Enable, 'off'), requested = 'category'; end
            switch requested
                case 'numeric'
                    if ~column.IsNumeric, error('DataExplorer:colorNumeric', '色の列「%s」は数値ではないため、量的（連続した色）にできません。質的か自動を選んでください。', column.Name); end
                    mode = 'numeric';
                case 'category'
                    mode = 'category';
                otherwise
                    levels = numel(unique(column.Numbers(isfinite(column.Numbers))));
                    mode = 'numeric';
                    if ~column.IsNumeric || levels <= explorer.AUTO_CATEGORY_LIMIT, mode = 'category'; end
            end
        end
        function summary = summaryByGroup(explorer, values)
            % 縦軸の要約。色をグループで分けたときはグループごとにも出す。
            names = "全体"; members = {true(size(values))};
            [mode, column] = explorer.colorChoice();
            if strcmp(mode, 'category')
                [groups, labels] = category_groups(column, Inf);
                for group = 1:numel(labels), names(end + 1, 1) = labels(group); members{end + 1, 1} = groups == group; end %#ok<AGROW>
            end
            stats = zeros(numel(names), 6);
            for index = 1:numel(names)
                part = values(members{index} & isfinite(values));
                if isempty(part), stats(index, :) = [0, NaN(1, 5)]; continue; end
                stats(index, :) = [numel(part), mean(part), std(part), min(part), median(part), max(part)];
            end
            summary = [table(names, 'VariableNames', {'グループ'}), array2table(stats, 'VariableNames', {'件数', '平均', '標準偏差', '最小', '中央値', '最大'})];
        end

        % ================= Pro 版のグラフ =================
        function drawHistograms(explorer)
            names = explorer.selectedColumns(1, explorer.MAX_HISTOGRAMS);
            [mode, column] = explorer.colorChoice(); groups = []; labels = strings(0, 1);
            if ~strcmp(mode, 'none'), [groups, labels] = category_groups(column, explorer.FLOW_LEVELS); end
            stats = zeros(numel(names), 6);
            for index = 1:numel(names)
                values = explorer.numericColumn(names{index}, '列').Numbers; finite = isfinite(values);
                ax = explorer.Result.addAxes(sprintf('ヒストグラム: %s', names{index})); hold(ax, 'on');
                [~, edges] = histcounts(values(finite));
                if isempty(groups)
                    histogram(ax, values(finite), edges);
                else
                    colors = lines(numel(labels));
                    for group = 1:numel(labels)
                        member = finite & groups == group;
                        if any(member)
                            histogram(ax, values(member), edges, 'FaceColor', colors(group, :), 'FaceAlpha', 0.5, 'DisplayName', char(labels(group)));
                        end
                    end
                    legend(ax, 'Location', 'bestoutside', 'Interpreter', 'none');
                end
                xlabel(ax, names{index}, 'Interpreter', 'none'); ylabel(ax, '件数'); grid(ax, 'on'); hold(ax, 'off');
                title(ax, sprintf('%s の分布（%d件）', names{index}, sum(finite)), 'Interpreter', 'none');
                part = values(finite); stats(index, :) = [numel(part), mean(part), std(part), min(part), median(part), max(part)];
            end
            explorer.Result.setTable('列の要約', [table(string(names(:)), 'VariableNames', {'列'}), ...
                array2table(stats, 'VariableNames', {'件数', '平均', '標準偏差', '最小', '中央値', '最大'})]);
            explorer.Result.setHeadline(sprintf('%d列の分布を表示しました。', numel(names)));
        end
        function drawCorrelation(explorer)
            names = explorer.selectedColumns(2, Inf); values = explorer.numericMatrix(names);
            [r, p] = corr(values, 'Rows', 'pairwise');
            ax = explorer.Result.addAxes('相関マトリックス');
            imagesc(ax, r, [-1, 1]); colormap(ax, diverging_map()); scale = colorbar(ax); scale.Label.String = '相関係数 r';
            count = numel(names);
            for row = 1:count
                for column = 1:count
                    shade = [0, 0, 0]; if abs(r(row, column)) > 0.6, shade = [1, 1, 1]; end
                    text(ax, column, row, sprintf('%.2f', r(row, column)), 'HorizontalAlignment', 'center', ...
                        'Color', shade, 'Tag', 'keep-color', 'FontSize', 9);
                end
            end
            ax.XTick = 1:count; ax.YTick = 1:count; ax.XTickLabel = names; ax.YTickLabel = names;
            ax.XTickLabelRotation = 45; ax.TickLabelInterpreter = 'none'; ax.YDir = 'reverse'; axis(ax, 'tight');
            title(ax, '相関マトリックス（Pearson。1に近いほど正、−1に近いほど負の相関）');
            row_names = cellstr(string(names));
            explorer.Result.setTable('相関係数', array2table(r, 'VariableNames', row_names, 'RowNames', row_names));
            explorer.Result.setTable('相関のp値', array2table(p, 'VariableNames', row_names, 'RowNames', row_names));
            explorer.Result.setHeadline(sprintf('%d列の相関係数。空欄は列の組ごとに除いて計算しました。相関は因果関係を示しません。', count));
        end
        function drawAnova(explorer)
            y = explorer.numericColumn(explorer.YAxis.Value, '縦軸（応答）');
            names = explorer.selectedColumns(1, explorer.MAX_ANOVA_FACTORS);
            if any(strcmp(names, y.Name)), error('DataExplorer:anovaFactor', '縦軸の列「%s」を要因に含めることはできません。', y.Name); end
            factors = cell(1, numel(names));
            for index = 1:numel(names)
                [groups, labels] = category_groups(data_column(explorer.Data, names{index}), explorer.FLOW_LEVELS);
                factors{index} = labels(groups);
            end
            result = calc_anova_summary(y.Numbers, factors, names);
            for index = 1:numel(names)
                ax = explorer.Result.addAxes(sprintf('箱ひげ図: %s', names{index}));
                valid = isfinite(y.Numbers) & factors{index} ~= "(欠損)";
                boxchart(ax, categorical(factors{index}(valid)), y.Numbers(valid));
                xlabel(ax, names{index}, 'Interpreter', 'none'); ylabel(ax, y.Name, 'Interpreter', 'none'); grid(ax, 'on');
                ax.TickLabelInterpreter = 'none';
                p = result.Table.("p値")(result.Table.("要因") == string(names{index}));
                title(ax, sprintf('%s の水準ごとの %s（p = %.3g）', names{index}, y.Name, p), 'Interpreter', 'none');
            end
            explorer.Result.setTable('ANOVA表', result.Table);
            explorer.Result.setTable('水準ごとの平均', result.Groups);
            explorer.Result.setHeadline(sprintf(['応答: %s / 要因: %s / %d行。p値が小さい（目安 0.05 未満）要因ほど、水準によって平均が違うといえます。' ...
                '寄与率は全体のばらつきに占める割合です。'], y.Name, strjoin(names, ', '), result.Rows));
            explorer.Result.showTable('ANOVA表');
        end
        function drawParallel(explorer)
            names = explorer.selectedColumns(2, Inf); values = explorer.numericMatrix(names);
            variables = matlab.lang.makeUniqueStrings(matlab.lang.makeValidName(names));
            data = array2table(values, 'VariableNames', variables);
            tab = explorer.Result.addChartTab('Parallel Coordinates'); layout = uigridlayout(tab, [1, 1]); layout.Padding = [4, 4, 4, 4];
            [mode, column] = explorer.colorChoice(); arguments = {};
            if ~strcmp(mode, 'none')
                [groups, labels] = category_groups(column, explorer.FLOW_LEVELS);
                data.Group = categorical(labels(groups)); arguments = {'GroupVariable', 'Group'};
            end
            chart = parallelplot(layout, data, 'CoordinateVariables', variables, arguments{:});
            chart.CoordinateTickLabels = names; chart.Title = 'Parallel Coordinates（各軸は最小〜最大で目盛り）';
            if ~strcmp(mode, 'none'), chart.LegendTitle = column.Name; end
            explorer.Result.registerCharts({chart}, {'Parallel Coordinates'});
            explorer.Result.setHeadline(sprintf('%d列・%d行を1本ずつの線で表示しました。', numel(names), size(values, 1)));
        end
        function drawFlows(explorer, style)
            names = explorer.selectedColumns(2, explorer.MAX_FLOW_COLUMNS);
            rows = size(explorer.Data.Cells, 1); groups = zeros(rows, numel(names)); level_names = cell(1, numel(names));
            for index = 1:numel(names)
                [groups(:, index), level_names{index}] = category_groups(data_column(explorer.Data, names{index}), explorer.FLOW_LEVELS);
            end
            counts = cellfun(@numel, level_names); layout = category_flow_layout(groups, counts, style);
            % Parallel Sets は最初の列の値で色を付けて凡例を出す。Sankey は流れの元の水準ごとに色を付け、名前は各水準の横に出す。
            title_text = 'Parallel Sets'; color_names = level_names{1};
            if strcmp(style, 'sankey'), title_text = 'Sankey Diagram'; color_names = strings(0, 1); end
            ax = explorer.Result.addAxes(title_text);
            plot_category_flows(ax, layout, names, level_names, color_names);
            title(ax, sprintf('%s（帯の太さ＝行数、%d行）', title_text, rows));
            [paths, ~, member] = unique(groups, 'rows'); counts_by_path = accumarray(member, 1);
            labels = strings(size(paths));
            for index = 1:numel(names), labels(:, index) = level_names{index}(paths(:, index)); end
            combination = [array2table(labels, 'VariableNames', cellstr(string(names))), table(counts_by_path, 'VariableNames', {'件数'})];
            explorer.Result.setTable('値の組み合わせ', sortrows(combination, '件数', 'descend'));
            explorer.Result.setHeadline(sprintf('%s：%s（数値の列は%d区間に分けました）', title_text, strjoin(names, ' → '), explorer.FLOW_LEVELS));
        end
        function drawPca(explorer)
            names = explorer.selectedColumns(2, Inf); values = explorer.numericMatrix(names);
            result = calc_pca_summary(values, names);
            ax = explorer.Result.addAxes('主成分得点（PC1 × PC2）'); hold(ax, 'on');
            explorer.coloredScatter(ax, result.Scores(:, 1), result.Scores(:, 2), result.Valid);
            xlabel(ax, sprintf('PC1（%.1f%%）', result.Explained(1))); ylabel(ax, sprintf('PC2（%.1f%%）', result.Explained(2)));
            grid(ax, 'on'); title(ax, '主成分得点（各行を2つの主成分で表示）'); hold(ax, 'off');
            ax = explorer.Result.addAxes('寄与率'); hold(ax, 'on');
            bar(ax, result.Explained); plot(ax, cumsum(result.Explained), 'o-', 'LineWidth', 1.5);
            ax.XTick = 1:numel(result.Explained); ax.XTickLabel = cellstr("PC" + string(1:numel(result.Explained)));
            ylabel(ax, '寄与率（%）'); ylim(ax, [0, 105]); grid(ax, 'on'); legend(ax, {'寄与率', '累積寄与率'}, 'Location', 'east');
            title(ax, '主成分ごとの寄与率（どれだけのばらつきを説明するか）'); hold(ax, 'off');
            ax = explorer.Result.addAxes('負荷量（PC1 × PC2）'); hold(ax, 'on');
            for index = 1:numel(names)
                plot(ax, [0, result.Loadings(index, 1)], [0, result.Loadings(index, 2)], '-', 'LineWidth', 1.5, 'Color', [0.12, 0.35, 0.58]);
                text(ax, result.Loadings(index, 1), result.Loadings(index, 2), [' ' names{index}], 'Interpreter', 'none');
            end
            axis(ax, 'equal'); limits = [-1, 1] * 1.1; xlim(ax, limits); ylim(ax, limits); grid(ax, 'on');
            xlabel(ax, 'PC1 の負荷量'); ylabel(ax, 'PC2 の負荷量'); title(ax, '各列が主成分にどう効くか（同じ向きの列は似た動き）'); hold(ax, 'off');
            explorer.Result.setTable('寄与率', result.Variance);
            explorer.Result.setTable('負荷量', result.LoadingTable);
            scores = [table(explorer.Data.RowNumbers, 'VariableNames', {'SourceRow'}), ...
                array2table(result.Scores, 'VariableNames', cellstr("PC" + string(1:size(result.Scores, 2))))];
            explorer.Result.setTable('主成分得点', scores);
            explorer.Result.setHeadline(sprintf('%d列を標準化して主成分分析しました（%d行）。PC1とPC2で全体のばらつきの %.1f%% を説明します。', ...
                numel(names), sum(result.Valid), sum(result.Explained(1:min(2, end)))));
        end
        function drawClusters(explorer)
            names = explorer.selectedColumns(2, Inf); values = explorer.numericMatrix(names);
            method = explorer.ClusterMethod.Value; count = explorer.ClusterCount.Value;
            result = calc_cluster_summary(values, names, method, count, explorer.Owner.settings().Seed);
            [~, scores] = pca(result.Standardized); clusters = result.Clusters(result.Valid);
            ax = explorer.Result.addAxes('群（PC1 × PC2）'); hold(ax, 'on'); colors = lines(count);
            for group = 1:count
                member = clusters == group;
                scatter(ax, scores(member, 1), scores(member, 2), explorer.MARKER_SIZE, colors(group, :), 'filled', ...
                    'DisplayName', sprintf('群%d（%d件）', group, sum(member)));
            end
            legend(ax, 'Location', 'bestoutside'); grid(ax, 'on'); xlabel(ax, 'PC1'); ylabel(ax, 'PC2');
            title(ax, sprintf('群の分かれ方（主成分得点で表示。シルエット係数 %.2f）', result.Silhouette)); hold(ax, 'off');
            ax = explorer.Result.addAxes('エルボー図'); hold(ax, 'on');
            plot(ax, result.Elbow.("群の数"), result.Elbow.("群内平方和"), 'o-', 'LineWidth', 1.5);
            chosen = result.Elbow.("群の数") == count;
            plot(ax, result.Elbow.("群の数")(chosen), result.Elbow.("群内平方和")(chosen), 'p', 'MarkerSize', 14, 'MarkerFaceColor', [0.85, 0.33, 0.10]);
            xlabel(ax, '群の数'); ylabel(ax, '群内平方和（標準化後）'); grid(ax, 'on');
            title(ax, '群の数の目安（減り方が緩やかになる手前が目安。星が今の群の数）'); hold(ax, 'off');
            if strcmp(method, 'ward'), explorer.drawDendrogram(result.Linkage); end
            explorer.Result.setTable('群ごとの平均', result.Centers);
            explorer.Result.setTable('エルボー', result.Elbow);
            assignment = [table(explorer.Data.RowNumbers, result.Clusters, 'VariableNames', {'SourceRow', '群'}), ...
                array2table(values, 'VariableNames', cellstr(string(names)))];
            explorer.Result.setTable('群の割り当て', assignment);
            method_name = explorer.CLUSTER_METHOD_NAMES{strcmp(explorer.CLUSTER_METHOD_CODES, method)};
            explorer.Result.setHeadline(sprintf(['%s で %d群に分けました（%d列を標準化、%d行）。シルエット係数 %.2f（1に近いほど群がはっきり分かれています）。' ...
                '空欄を含む行は群0です。'], method_name, count, numel(names), sum(result.Valid), result.Silhouette));
        end
        function drawDendrogram(explorer, tree)
            % dendrogram は描く先の図を指定できないため、表示中の図を一時的にこの図へ切り替えて描く。
            ax = explorer.Result.addAxes('樹形図（Ward 法）'); window = ancestor(ax, 'figure');
            visibility = window.HandleVisibility; window.HandleVisibility = 'on'; previous = window.CurrentAxes;
            restore = onCleanup(@() restoreFigure(window, visibility, previous));
            window.CurrentAxes = ax; lines_drawn = dendrogram(tree, 30);
            set(lines_drawn, 'Color', [0.12, 0.35, 0.58]);
            xlabel(ax, '群（30個までにまとめて表示）'); ylabel(ax, '結合の距離'); title(ax, 'Ward 法の樹形図'); grid(ax, 'on');
            clear restore;
        end

        % ================= 列の取り出し =================
        function column = numericColumn(explorer, name, role)
            column = data_column(explorer.Data, name);
            if ~column.IsNumeric || ~any(isfinite(column.Numbers))
                error('DataExplorer:numeric', '%sの列「%s」に数値でない値があります。数値の列を選んでください。', role, name);
            end
        end
        function values = numericMatrix(explorer, names)
            values = zeros(size(explorer.Data.Cells, 1), numel(names));
            for index = 1:numel(names), values(:, index) = explorer.numericColumn(names{index}, '「列」で選んだ').Numbers; end
        end
        function names = selectedColumns(explorer, minimum, maximum)
            names = cellstr(string(explorer.Columns.Value)); names = names(:)';
            if numel(names) < minimum, error('DataExplorer:columns', '「列」の一覧から%d列以上を選んでください。', minimum); end
            if numel(names) > maximum, error('DataExplorer:columns', '「列」は%d列以下にしてください（現在 %d列）。', maximum, numel(names)); end
        end
    end
end

function keepOr(dropdown, items, fallback)
% 選択肢を入れ替えるとき、同じ名前があれば選択を残し、なければ fallback を選ぶ。
previous = dropdown.Value;
if isempty(items), items = {fallback}; end
if ~any(strcmp(items, fallback)), items = [items, {fallback}]; end
dropdown.Items = items;
if any(strcmp(items, previous)), dropdown.Value = previous; else, dropdown.Value = fallback; end
end

function map = diverging_map()
% 負の相関を青、0を白、正の相関を赤で表す色。
STEPS = 128;
blue = [0.13, 0.40, 0.67]; red = [0.70, 0.09, 0.17]; white = [1, 1, 1];
map = [interp1([0; 1], [blue; white], linspace(0, 1, STEPS)'); interp1([0; 1], [white; red], linspace(0, 1, STEPS)')];
end

function restoreFigure(window, visibility, previous)
if ~isvalid(window), return; end
if ~isempty(previous) && isvalid(previous), window.CurrentAxes = previous; end
window.HandleVisibility = visibility;
end
