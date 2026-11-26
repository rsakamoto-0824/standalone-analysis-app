classdef CausalPage < AppPage
    % 因果探索の画面（Pro 版）。左で ① データ → ② 列 → ③ 方法 → ④ 前もって分かっている因果（任意）→ ⑤ 実行、
    % 右に因果グラフと辺の表を表示する。
    properties (SetAccess = private)
        Source
        Columns
        Method
        Alpha
        MaxConditioning
        Plan
        RunButton
        Views
        ResultTab
        PreviewTab
        Preview
        Result
        Report = []
        % 事前の知識：{元の列, 種類のコード, 先の列} の一覧と、入力・一覧の部品。
        Knowledge = cell(0, 3)
        KnowledgeFrom
        KnowledgeKind
        KnowledgeTo
        KnowledgeTable
        SelectedKnowledgeRow = 0
    end
    properties (Constant)
        LEFT_WIDTH = 440
        METHOD_NAMES = {'PCアルゴリズム（偏相関の検定。向きの決まらない辺も残す）', 'DirectLiNGAM（非正規性を使って向きと順序を決める）'}
        METHOD_CODES = {'pc', 'lingam'}
        MAX_COLUMNS = 50
        CIRCLE_LAYOUT_LIMIT = 12
        TABLE_EDGES = '因果の辺'
        TABLE_ORDER = '因果の順序'
        CHART_GRAPH = '因果グラフ'
        NODE_COLOR = [0.12, 0.35, 0.58]
        UNDIRECTED_COLOR = [0.55, 0.55, 0.55]
        KNOWLEDGE_NAMES = {'→ この向きはあり得ない', '― 因果はない（どちらの向きも）', '→ この向きの因果がある'}
        KNOWLEDGE_CODES = {'forbidden', 'none', 'required'}
        NO_COLUMN = '(②で列を選んでください)'
    end
    methods
        function page = CausalPage(app, parent)
            page@AppPage(app, parent);
            page.Body.ColumnWidth = {page.LEFT_WIDTH, '1x'}; page.Body.RowHeight = {'1x'};
            % 各欄に固定の高さを持たせ、入りきらないときは左の列ごと上下にスクロールする。最後の伸縮行は空の部品で埋める。
            left = uigridlayout(page.Body, [7, 1], 'Scrollable', 'on'); left.Padding = [0, 0, 6, 0];
            left.RowHeight = {104, 200, 230, 330, 44, 38, '1x'};
            panel = AppPage.section(left, '① データを開く');
            grid = uigridlayout(panel, [1, 1]); grid.Padding = [8, 6, 8, 6];
            page.Source = DataSourceControl(page, grid); page.Source.LoadedFcn = @(data) page.dataLoaded(data);
            panel = AppPage.section(left, sprintf('② 列を選ぶ（数値の列を2〜%d列）', page.MAX_COLUMNS));
            grid = uigridlayout(panel, [2, 1]); grid.RowHeight = {22, '1x'};
            uilabel(grid, 'Text', '複数選択は Ctrl キーを押しながらクリックします。');
            page.Columns = uilistbox(grid, 'Items', {}, 'Value', {}, 'Multiselect', 'on', 'ValueChangedFcn', @(~, ~) page.refreshPlan());
            panel = AppPage.section(left, '③ 方法');
            grid = uigridlayout(panel, [4, 2]); grid.RowHeight = {30, 30, 30, '1x'}; grid.ColumnWidth = {200, '1x'};
            uilabel(grid, 'Text', '方法');
            page.Method = uidropdown(grid, 'Items', page.METHOD_NAMES, 'ItemsData', page.METHOD_CODES, 'ValueChangedFcn', @(~, ~) page.refreshPlan());
            [~, page.Alpha] = AppPage.numberField(grid, '有意水準（辺を残す基準）', 0.05, [0.001, 0.5], false);
            [~, page.MaxConditioning] = AppPage.numberField(grid, 'PC：条件づける列の最大数', 3, [0, 10], true);
            label = AppPage.hint(grid, '推定した向きは仮説です。因果関係の証明ではありません。未観測の共通原因があると誤った辺が出ることがあります。列が多いほど時間がかかります。');
            label.Layout.Column = [1, 2];
            page.buildKnowledge(AppPage.section(left, '④ 前もって分かっている因果（任意）'));
            page.Plan = AppPage.stateLabel(left);
            page.RunButton = AppPage.primaryButton(left, '⑤ 因果探索を実行', @(~, ~) page.run());
            AppPage.fillLastRow(left);
            page.Views = uitabgroup(page.Body);
            page.ResultTab = uitab(page.Views, 'Title', '結果'); grid = uigridlayout(page.ResultTab, [1, 1]);
            page.Result = ResultPanel(page, grid, '左の①〜④を進めると、ここに因果グラフと辺の表を表示します。');
            page.PreviewTab = uitab(page.Views, 'Title', '入力プレビュー'); grid = uigridlayout(page.PreviewTab, [1, 1]);
            page.Preview = uitable(grid, 'RowName', 'numbered'); page.Source.PreviewTable = page.Preview;
            page.refreshPlan();
            page.message(['① データを開く → ② 列を選ぶ → ③ 方法を選ぶ → ④ 分かっている因果を指定（任意）→ ⑤ 実行。' ...
                '列どうしの因果の向きの候補をグラフで表示します。']);
        end
        function selectColumns(page, names)
            page.Columns.Value = cellstr(string(names(:)')); page.refreshPlan();
        end
        function setKnowledge(page, rules)
            % 事前の知識をまとめて指定する（テストや手順書の撮影で使う）。rules は {元, 種類のコード, 先} の n×3 の cell。
            if isempty(rules), rules = cell(0, 3); end
            if size(rules, 2) ~= 3 || ~all(ismember(rules(:, 2), page.KNOWLEDGE_CODES))
                error('causal:knowledgeKind', '事前の知識は {元, 種類（forbidden・none・required）, 先} で指定してください。');
            end
            page.Knowledge = rules; page.SelectedKnowledgeRow = 0; page.refreshPlan();
        end
        function run(page)
            dialog = [];
            try
                require_pro_feature('因果探索');
                if isempty(page.Source.Data), error('causal:noData', '①でデータを開いてください。'); end
                names = cellstr(string(page.Columns.Value)); names = names(:)';
                if numel(names) < 2 || numel(names) > page.MAX_COLUMNS
                    error('causal:columns', '②で数値の列を2〜%d列選んでください（現在 %d列）。', page.MAX_COLUMNS, numel(names));
                end
                values = extract_numeric_columns(page.Source.Data, names);
                dialog = page.App.startProgress('因果探索', '列どうしの関係を調べています。');
                % 選んでいない列を含む指定は使わない（列の選び直しで消さずに残しておく）。
                used = all(ismember(page.Knowledge(:, [1, 3]), names), 2); rules = page.Knowledge(used, :);
                options = struct('Alpha', page.Alpha.Value, 'MaxConditioning', page.MaxConditioning.Value, ...
                    'Knowledge', causal_knowledge(names, rules));
                report = causal_discovery(values, names, page.Method.Value, options);
                AnalysisController.closeProgress(dialog);
                page.Report = report; page.showReport(report, names, size(rules, 1));
                if any(~used)
                    page.message(sprintf('②で選んでいない列を含む事前の知識 %d 件は使いませんでした。', sum(~used)));
                end
            catch err
                AnalysisController.closeProgress(dialog); page.showError(err);
            end
        end
    end
    methods (Access = private)
        function buildKnowledge(page, panel)
            % 種類の文（「― 因果はない（どちらの向きも）」など）が切れないよう、種類は欄の幅いっぱいの行に置く。
            grid = uigridlayout(panel, [5, 3]); grid.RowHeight = {44, 30, 30, 30, '1x'}; grid.ColumnWidth = {'1x', '1x', '1x'};
            label = AppPage.hint(grid, ['あり得ない向き（例：後の工程 → 前の工程）や、分かっている因果を指定すると、' ...
                'それを守って推定します。元・先の列と種類を選んで追加します。']);
            label.Layout.Column = [1, 3];
            page.KnowledgeFrom = uidropdown(grid, 'Items', {page.NO_COLUMN}, 'Tooltip', '因果の元（原因の側）の列');
            arrow = uilabel(grid, 'Text', '元 → 先', 'HorizontalAlignment', 'center'); arrow.Layout.Column = 2;
            page.KnowledgeTo = uidropdown(grid, 'Items', {page.NO_COLUMN}, 'Tooltip', '因果の先（結果の側）の列');
            page.KnowledgeKind = uidropdown(grid, 'Items', page.KNOWLEDGE_NAMES, 'ItemsData', page.KNOWLEDGE_CODES, ...
                'Tooltip', ['あり得ない：その向きの辺を作りません（逆向きは残ります）。因果はない：2つの列の間に辺を作りません。' ...
                '因果がある：その向きの辺を、検定の結果によらず残します。']);
            page.KnowledgeKind.Layout.Column = [1, 3];
            uibutton(grid, 'Text', '追加', 'ButtonPushedFcn', @(~, ~) page.addKnowledge());
            uibutton(grid, 'Text', '選んだ行を削除', 'ButtonPushedFcn', @(~, ~) page.removeKnowledge());
            uibutton(grid, 'Text', 'すべて削除', 'ButtonPushedFcn', @(~, ~) page.setKnowledge(cell(0, 3)));
            page.KnowledgeTable = uitable(grid, 'RowName', {}, 'ColumnName', {'元', '種類', '先'}, 'ColumnWidth', {'auto', 170, 'auto'}, ...
                'CellSelectionCallback', @(~, event) page.knowledgeRowSelected(event));
            page.KnowledgeTable.Layout.Column = [1, 3];
            page.refreshKnowledge();
        end
        function addKnowledge(page)
            from = page.KnowledgeFrom.Value; to = page.KnowledgeTo.Value;
            try
                if strcmp(from, page.NO_COLUMN), error('causal:knowledgeColumn', '②で列を選んでから、元と先の列を選んでください。'); end
                if strcmp(from, to), error('causal:knowledgeSelf', '元と先には別の列を選んでください。'); end
                rules = [page.Knowledge; {from, page.KnowledgeKind.Value, to}];
                % 同じ組の指定を重ねたときに、矛盾をすぐに知らせる（循環なども含めて確かめる）。
                causal_knowledge(unique([rules(:, 1); rules(:, 3)], 'stable'), rules);
                page.Knowledge = rules; page.refreshPlan();
            catch err
                page.showError(err);
            end
        end
        function removeKnowledge(page)
            if page.SelectedKnowledgeRow < 1 || page.SelectedKnowledgeRow > size(page.Knowledge, 1)
                page.message('削除する行を、事前の知識の表でクリックして選んでください。'); return;
            end
            page.Knowledge(page.SelectedKnowledgeRow, :) = []; page.SelectedKnowledgeRow = 0; page.refreshPlan();
        end
        function knowledgeRowSelected(page, event)
            if isempty(event.Indices), return; end
            page.SelectedKnowledgeRow = event.Indices(1, 1);
        end
        function refreshKnowledge(page)
            if isempty(page.KnowledgeTable), return; end
            names = cellstr(string(page.Columns.Value)); names = names(:)';
            if isempty(names), names = {page.NO_COLUMN}; end
            for field = {page.KnowledgeFrom, page.KnowledgeTo}
                control = field{1}; previous = control.Value; control.Items = names;
                if any(strcmp(names, previous)), control.Value = previous; end
            end
            if numel(names) >= 2 && strcmp(page.KnowledgeFrom.Value, page.KnowledgeTo.Value), page.KnowledgeTo.Value = names{2}; end
            rows = page.Knowledge;
            if ~isempty(rows)
                rows(:, 2) = cellfun(@(code) page.KNOWLEDGE_NAMES{strcmp(page.KNOWLEDGE_CODES, code)}, rows(:, 2), 'UniformOutput', false);
            end
            page.KnowledgeTable.Data = rows;
        end
        function dataLoaded(page, data)
            headers = data.Headers;
            numeric = headers(cellfun(@(name) data_column(data, name).IsNumeric, headers));
            kept = intersect(cellstr(string(page.Columns.Value)), numeric, 'stable');
            if isempty(kept), kept = numeric(1:min(numel(numeric), 6)); end
            set(page.Columns, 'Items', numeric, 'Value', kept);
            page.Views.SelectedTab = page.PreviewTab; page.refreshPlan();
            page.message(sprintf('%s を読み込みました（%d行）。数値の列だけを一覧に出します。', page.Source.fileName(), size(data.Cells, 1)));
        end
        function refreshPlan(page)
            page.refreshKnowledge();
            if isempty(page.Source.Data)
                page.setState(page.Plan, '①でデータを開いてください。', false); return;
            end
            count = numel(page.Columns.Value);
            if count < 2
                page.setState(page.Plan, '②で列を2列以上選んでください。', false); return;
            end
            names = cellstr(string(page.Columns.Value));
            used = sum(all(ismember(page.Knowledge(:, [1, 3]), names), 2));
            knowledge = ''; if used > 0, knowledge = sprintf('（事前の知識 %d 件を守って推定）', used); end
            page.setState(page.Plan, sprintf('%d列・%d行で、%s を実行します%s。', count, size(page.Source.Data.Cells, 1), ...
                page.METHOD_NAMES{strcmp(page.METHOD_CODES, page.Method.Value)}, knowledge), true);
        end
        function showReport(page, report, names, knowledge_count)
            panel = page.Result; panel.clear(); panel.setTable(page.TABLE_EDGES, report.Edges);
            if ~isempty(report.Order)
                panel.setTable(page.TABLE_ORDER, table((1:numel(report.Order))', string(names(report.Order))', 'VariableNames', {'順序', '列'}));
            end
            ax = panel.addAxes(page.CHART_GRAPH); page.drawGraph(ax, report, names);
            directed = sum(report.Edges.("向き") == "→"); undirected = height(report.Edges) - directed;
            method = page.METHOD_NAMES{strcmp(page.METHOD_CODES, report.Method)};
            knowledge = ''; if knowledge_count > 0, knowledge = sprintf('事前の知識 %d 件を守って推定しました。', knowledge_count); end
            panel.setHeadline(sprintf(['%s / %d列。向きの決まった辺 %d本、向きの決まらない辺 %d本。%s' ...
                '線の太さと数値は関係の強さ（PC は偏相関、LiNGAM は標準化した係数）。推定は仮説で、因果の証明ではありません。'], ...
                method, numel(names), directed, undirected, knowledge));
            panel.showCharts(); page.Views.SelectedTab = page.ResultTab; page.App.applyTheme();
            page.message('因果探索が終わりました。');
        end
        function drawGraph(page, ax, report, names)
            % 向きの決まった辺は矢印、向きの決まらない辺は矢印なしの破線で描く（無向の辺は片方向だけを使う）。
            adjacency = report.Adjacency; undirected = adjacency & adjacency'; drawn = adjacency & ~(undirected & tril(true(size(adjacency))));
            [from, to] = find(drawn); weights = abs(report.Strength(sub2ind(size(adjacency), from, to)));
            graph = digraph(from, to, weights, numel(names));
            graph.Nodes.Name = cellstr(string(names(:)));
            % 列が多いと円の配置では重なるため、つながりで引き寄せる配置（force）にする。
            layout = 'circle'; if numel(names) > page.CIRCLE_LAYOUT_LIMIT, layout = 'force'; end
            plot_handle = plot(ax, graph, 'Layout', layout, 'NodeColor', page.NODE_COLOR, 'MarkerSize', 9, 'NodeFontSize', 11, ...
                'EdgeColor', page.NODE_COLOR, 'ArrowSize', 12, 'Interpreter', 'none');
            if numedges(graph) > 0
                % digraph は辺を並べ替えて持つため、表示する辺の順に元・先を取り直して書式を決める。
                ends = graph.Edges.EndNodes; order_from = findnode(graph, ends(:, 1)); order_to = findnode(graph, ends(:, 2));
                is_undirected = undirected(sub2ind(size(adjacency), order_from, order_to));
                plot_handle.LineWidth = 1 + 4 * graph.Edges.Weight / max(max(graph.Edges.Weight), eps);
                plot_handle.EdgeLabel = arrayfun(@(value) sprintf('%.2f', value), report.Strength(sub2ind(size(adjacency), order_from, order_to)), 'UniformOutput', false);
                highlight(plot_handle, order_from(is_undirected), order_to(is_undirected), 'LineStyle', '--', 'EdgeColor', page.UNDIRECTED_COLOR, 'ArrowSize', 0);
            end
            axis(ax, 'off'); title(ax, '因果グラフ（矢印：推定した向き、破線：向きの決まらない関係）');
        end
    end
end
