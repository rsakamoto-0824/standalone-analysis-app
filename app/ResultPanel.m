classdef ResultPanel < handle
    % 見出し・グラフ・表・書出しボタンをまとめた結果表示の部品。
    % グラフはすべてアプリ内のタブへ描画し、外部の図ウィンドウを作らない。
    properties (SetAccess = private)
        Grid
        Headline
        Tabs
        ChartTab
        ChartTabs
        Charts = {}
        ChartNames = {}
    end
    properties (Access = private)
        Owner
        Tables
        EmptyHeadline
    end
    properties (Constant)
        CHART_TAB_TITLE = 'グラフ'
        EXPORT_RESOLUTION = 150
    end
    methods
        function panel = ResultPanel(owner, parent, empty_headline)
            if nargin < 3, empty_headline = '実行すると、ここに結果を表示します。'; end
            panel.Owner = owner; panel.EmptyHeadline = empty_headline;
            panel.Tables = containers.Map('KeyType', 'char', 'ValueType', 'any');
            panel.Grid = uigridlayout(parent, [3, 1]);
            panel.Grid.RowHeight = {44, '1x', 32}; panel.Grid.Padding = [0, 0, 0, 0];
            panel.Headline = uilabel(panel.Grid, 'Text', empty_headline, 'WordWrap', 'on', 'FontWeight', 'bold', 'Interpreter', 'none');
            panel.Tabs = uitabgroup(panel.Grid);
            panel.ChartTab = uitab(panel.Tabs, 'Title', panel.CHART_TAB_TITLE);
            chart_grid = uigridlayout(panel.ChartTab, [1, 1]); chart_grid.Padding = [4, 4, 4, 4];
            panel.ChartTabs = uitabgroup(chart_grid);
            bar = uigridlayout(panel.Grid, [1, 4]); bar.Padding = [0, 0, 0, 0]; bar.ColumnWidth = {'1x', 150, 150, 150};
            uilabel(bar, 'Text', '表示中の表やグラフを書き出せます。', 'HorizontalAlignment', 'right');
            uibutton(bar, 'Text', '表を保存（CSV / Excel）', 'ButtonPushedFcn', @(~, ~) panel.exportTable());
            uibutton(bar, 'Text', 'グラフをPNG保存', 'ButtonPushedFcn', @(~, ~) panel.exportFigure());
            uibutton(bar, 'Text', 'グラフをコピー', 'ButtonPushedFcn', @(~, ~) panel.copyFigure(), ...
                'Tooltip', 'グラフを画像としてクリップボードへコピーします。ExcelやPowerPointへ貼り付けできます。');
        end
        function setHeadline(panel, text)
            panel.Headline.Text = text;
        end
        function view = setTable(panel, title, data)
            % 同じ題名のタブがあれば内容だけ差し替える。
            if isKey(panel.Tables, title) && isvalid(panel.Tables(title))
                view = panel.Tables(title);
            else
                tab = uitab(panel.Tabs, 'Title', title); layout = uigridlayout(tab, [1, 1]); layout.Padding = [4, 4, 4, 4];
                view = uitable(layout); panel.Tables(title) = view;
            end
            view.Data = data;
            if istable(data) && ~isempty(data.Properties.RowNames), view.RowName = data.Properties.RowNames; end
        end
        function data = tableData(panel, title)
            data = table();
            if isKey(panel.Tables, title) && isvalid(panel.Tables(title)), data = panel.Tables(title).Data; end
        end
        function removeTable(panel, title)
            if ~isKey(panel.Tables, title), return; end
            view = panel.Tables(title);
            if isvalid(view), delete(ancestor(view, 'matlab.ui.container.Tab')); end
            remove(panel.Tables, title);
        end
        function tab = addChartTab(panel, title)
            tab = uitab(panel.ChartTabs, 'Title', title);
        end
        function ax = addAxes(panel, title)
            tab = panel.addChartTab(title); layout = uigridlayout(tab, [1, 1]); layout.Padding = [4, 4, 4, 4];
            ax = uiaxes(layout); panel.registerCharts({ax}, {title});
        end
        function registerCharts(panel, charts, names)
            panel.Charts = [panel.Charts, charts(:)']; panel.ChartNames = [panel.ChartNames, names(:)'];
        end
        function removeCharts(panel, prefix)
            % 題名が prefix で始まるグラフだけを消す（SHAPの再計算で使用）。
            tabs = panel.ChartTabs.Children;
            for index = 1:numel(tabs)
                if startsWith(tabs(index).Title, prefix), delete(tabs(index)); end
            end
            panel.dropInvalidCharts();
        end
        function clear(panel)
            delete(panel.ChartTabs.Children); panel.Charts = {}; panel.ChartNames = {};
            titles = keys(panel.Tables);
            for index = 1:numel(titles), panel.removeTable(titles{index}); end
            panel.Headline.Text = panel.EmptyHeadline;
        end
        function showCharts(panel)
            panel.Tabs.SelectedTab = panel.ChartTab;
        end
        function showTable(panel, title)
            if isKey(panel.Tables, title) && isvalid(panel.Tables(title))
                panel.Tabs.SelectedTab = ancestor(panel.Tables(title), 'matlab.ui.container.Tab');
            end
        end
        function [data, name] = currentTable(panel)
            % 表示中のタブにある表。Swing Curve近似の表は、グラフタブ内から取得する。
            data = table(); name = panel.Tabs.SelectedTab.Title;
            if isequal(panel.Tabs.SelectedTab, panel.ChartTab)
                chart_tab = panel.ChartTabs.SelectedTab;
                if ~isempty(chart_tab) && isa(chart_tab.UserData, 'handle') && ismethod(chart_tab.UserData, 'currentTable')
                    data = chart_tab.UserData.currentTable(); name = chart_tab.Title;
                end
                return;
            end
            view = findobj(panel.Tabs.SelectedTab, 'Type', 'uitable');
            if isempty(view), return; end
            data = view(1).Data;
            if ~istable(data) && ~isempty(data)
                data = cell2table(data, 'VariableNames', matlab.lang.makeUniqueStrings(matlab.lang.makeValidName(cellstr(view(1).ColumnName))));
            end
        end
        function exportTable(panel)
            try
                [data, name] = panel.currentTable();
                if isempty(data), error('ResultPanel:noTable', '保存する表がありません。表のタブを選んでから保存してください。'); end
                default_name = [matlab.lang.makeValidName(name) '.csv'];
                path = panel.Owner.App.chooseSaveFile({'*.csv', 'CSV'; '*.xlsx', 'Excel'}, '表示中の表を保存', default_name);
                if isempty(path), return; end
                panel.exportTableTo(path);
            catch err
                panel.Owner.showError(err);
            end
        end
        function exportTableTo(panel, path)
            [data, ~] = panel.currentTable();
            if isempty(data), error('ResultPanel:noTable', '保存する表がありません。表のタブを選んでから保存してください。'); end
            write_result_table(data, path);
            [~, base, extension] = fileparts(path); panel.Owner.message(['表を保存しました: ' base extension]);
        end
        function exportFigure(panel)
            try
                [chart, name] = panel.chooseChart('保存するグラフ');
                if isempty(chart), return; end
                path = panel.Owner.App.chooseSaveFile({'*.png', 'PNG画像'}, 'グラフを保存', [matlab.lang.makeValidName(name) '.png']);
                if isempty(path), return; end
                panel.exportFigureTo(chart, path);
            catch err
                panel.Owner.showError(err);
            end
        end
        function exportFigureTo(panel, chart, path)
            if isnumeric(chart), charts = panel.validCharts(); chart = charts{chart}; end
            panel.reveal(chart);
            if isa(chart, 'matlab.ui.container.Panel')
                panel.exportContainer(chart, path);
            else
                exportgraphics(chart, path, 'Resolution', panel.EXPORT_RESOLUTION);
            end
            [~, base, extension] = fileparts(path); panel.Owner.message(['グラフを保存しました: ' base extension]);
        end
        function copyFigure(panel)
            try
                [charts, names] = panel.validCharts();
                copied = copy_app_chart(charts, names);
                if ~isempty(copied), panel.Owner.message(['クリップボードにコピーしました: ' copied]); end
            catch err
                panel.Owner.showError(err);
            end
        end
        function [charts, names] = validCharts(panel)
            panel.dropInvalidCharts();
            drawn = cellfun(@(chart) ~isa(chart, 'matlab.ui.control.UIAxes') || ~isempty(chart.Children), panel.Charts);
            charts = panel.Charts(drawn); names = panel.ChartNames(drawn);
        end
    end
    methods (Access = private)
        function dropInvalidCharts(panel)
            valid = cellfun(@(chart) isgraphics(chart), panel.Charts);
            panel.Charts = panel.Charts(valid); panel.ChartNames = panel.ChartNames(valid);
        end
        function exportContainer(panel, container, path)
            % 並べた図（パネル）を1枚のPNGにする。パネルを直接書き出せないリリースでは、
            % 中の図を1枚ずつ書き出し、左から順に横へつなぐ。
            try
                exportgraphics(container, path, 'Resolution', panel.EXPORT_RESOLUTION); return;
            catch
                % 下で中の図をつなぐ方法に切り替える。
            end
            GAP_PIXELS = 24;
            axes_list = findobj(container, 'Type', 'axes');
            if isempty(axes_list), error('ResultPanel:noChart', '書き出す図がありません。'); end
            positions = arrayfun(@(ax) getpixelposition(ax, true), axes_list, 'UniformOutput', false);
            [~, order] = sort(cellfun(@(position) position(1), positions)); axes_list = axes_list(order);
            images = cell(1, numel(axes_list));
            for index = 1:numel(axes_list)
                temporary = [tempname '.png']; cleanup = onCleanup(@() deleteFile(temporary));
                exportgraphics(axes_list(index), temporary, 'Resolution', panel.EXPORT_RESOLUTION);
                images{index} = imread(temporary); clear cleanup;
            end
            background = images{1}(1, 1, :); height = max(cellfun(@(image) size(image, 1), images));
            pieces = {};
            for index = 1:numel(images)
                image = images{index};
                filler = repmat(background, height - size(image, 1), size(image, 2));
                pieces{end + 1} = [image; filler]; %#ok<AGROW>
                if index < numel(images), pieces{end + 1} = repmat(background, height, GAP_PIXELS); end %#ok<AGROW>
            end
            imwrite([pieces{:}], path);
        end
        function [chart, name] = chooseChart(panel, prompt)
            chart = []; name = '';
            [charts, names] = panel.validCharts();
            if isempty(charts), error('ResultPanel:noChart', 'グラフがありません。先に解析を実行してください。'); end
            choice = find(cellfun(@(item) panel.isShown(item), charts));
            if numel(choice) ~= 1
                % 表示中の図を先に選んだ状態で一覧を出す（並べた図があればそれが先頭）。
                initial = 1; if ~isempty(choice), initial = choice(1); end
                [choice, accepted] = listdlg('ListString', names, 'SelectionMode', 'single', 'PromptString', prompt, ...
                    'ListSize', [360, 240], 'InitialValue', initial);
                if ~accepted, return; end
            end
            chart = charts{choice}; name = names{choice};
        end
        function shown = isShown(~, chart)
            shown = true; container = chart.Parent;
            while ~isempty(container) && ~isa(container, 'matlab.ui.Figure')
                if isa(container, 'matlab.ui.container.Tab') && ~isequal(container.Parent.SelectedTab, container), shown = false; return; end
                if isprop(container, 'Visible') && strcmp(container.Visible, 'off'), shown = false; return; end
                container = container.Parent;
            end
        end
        function reveal(~, chart)
            % 非表示のタブにある図は書き出せないため、先に表示する。
            container = chart.Parent;
            while ~isempty(container) && ~isa(container, 'matlab.ui.Figure')
                if isa(container, 'matlab.ui.container.Tab'), container.Parent.SelectedTab = container; end
                container = container.Parent;
            end
            drawnow;
        end
    end
end

function deleteFile(path)
if isfile(path), delete(path); end
end
