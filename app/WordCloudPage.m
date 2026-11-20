classdef WordCloudPage < AppPage
    % ワードクラウドの画面（Pro 版だけ）。左に文章と見た目の設定を入れ、右に図と単語の出現数を表示する。
    % 見た目は、形（楕円・長方形）、配色（単色・出現数で色を変える・ランダムな色）、色、強調する色、
    % 表示する単語の数、文字の大きさの差を選べる。
    properties (SetAccess = private)
        Text
        Shape
        Scheme
        BaseColor
        Palette
        Highlight
        MaxWords
        SizePower
        RunButton
        Result
    end
    properties (Constant)
        LEFT_WIDTH = 440
        SAMPLE_TEXT = 'MATLAB analysis MATLAB model'
        TABLE_WORDS = '単語の出現数'
        CHART_TITLE = 'Word Cloud'
        SHAPE_NAMES = {'楕円', '長方形'}
        SHAPE_CODES = {'oval', 'rectangle'}
        SCHEME_NAMES = {'単色（よく出る単語だけ強調する色）', '出現数で色を変える（多いほど右の色）', 'ランダムな色'}
        SCHEME_CODES = {'single', 'gradient', 'random'}
        COLOR_NAMES = {'紺', '青', '緑', '赤', '橙', '紫', '黒', '灰'}
        COLOR_VALUES = [0.12, 0.23, 0.42; 0.00, 0.45, 0.74; 0.13, 0.55, 0.13; 0.78, 0.12, 0.15; ...
            0.93, 0.49, 0.10; 0.49, 0.18, 0.56; 0.10, 0.10, 0.10; 0.45, 0.45, 0.45]
        PALETTE_NAMES = {'parula（青→黄）', 'turbo（青→赤）', 'cool（水色→桃）', 'winter（青→緑）', 'autumn（赤→黄）', 'copper（黒→銅）'}
        PALETTE_CODES = {'parula', 'turbo', 'cool', 'winter', 'autumn', 'copper'}
        DEFAULT_MAX_WORDS = 100
        DEFAULT_SIZE_POWER = 0.5
        RANDOM_SEED = 0
    end
    methods
        function page = WordCloudPage(app, parent)
            page@AppPage(app, parent);
            page.Body.ColumnWidth = {page.LEFT_WIDTH, '1x'}; page.Body.RowHeight = {'1x'};
            left = uigridlayout(page.Body, [5, 1]); left.Padding = [0, 0, 0, 0]; left.RowHeight = {60, 30, '1x', 250, 38};
            AppPage.hint(left, ['文章を入力するか、テキストファイル（.txt）を開きます。日本語は自動で単語に分けないため、' ...
                '単語の間を空白で区切ってください。1文字の単語は除きます。']);
            uibutton(left, 'Text', 'テキストファイルを開く', 'ButtonPushedFcn', @(~, ~) page.chooseText());
            page.Text = uitextarea(left, 'Value', {page.SAMPLE_TEXT});
            page.buildStyle(AppPage.section(left, '見た目（形と色）'));
            page.RunButton = AppPage.primaryButton(left, 'ワードクラウドを作成', @(~, ~) page.run());
            holder = uigridlayout(page.Body, [1, 1]); holder.Padding = [0, 0, 0, 0];
            page.Result = ResultPanel(page, holder, '「ワードクラウドを作成」を押すと、ここに図と単語の出現数を表示します。');
            page.schemeChanged();
        end
        function loadText(page, path)
            page.Text.Value = cellstr(splitlines(string(fileread(path))));
            [~, base, extension] = fileparts(path); page.message(['テキストを読み込みました: ' base extension]);
        end
        function setStyle(page, style)
            % テストや他の画面から見た目をまとめて設定する入口（Shape・Scheme・BaseColor・Palette・Highlight・MaxWords・SizePower）。
            names = fieldnames(style);
            for index = 1:numel(names), page.(names{index}).Value = style.(names{index}); end
            page.schemeChanged();
        end
        function run(page)
            try
                require_pro_feature('ワードクラウド');
                [words, counts] = create_wordCloud(strjoin(string(page.Text.Value), newline));
                panel = page.Result; panel.clear();
                [counts, order] = sort(counts, 'descend'); words = words(order);
                panel.setTable(page.TABLE_WORDS, table(string(words), counts, 'VariableNames', {'Word', 'Count'}));
                tab = panel.addChartTab(page.CHART_TITLE); layout = uigridlayout(tab, [1, 1]);
                [colors, highlight] = page.wordColors(counts);
                chart = wordcloud(layout, words, counts, 'Shape', page.Shape.Value, 'Color', colors, 'HighlightColor', highlight, ...
                    'MaxDisplayWords', page.MaxWords.Value, 'SizePower', page.SizePower.Value);
                % 選んだ色を、テーマの適用で上書きしない。
                chart.Title = page.CHART_TITLE; setappdata(chart, 'KeepColor', true);
                panel.registerCharts({chart}, {page.CHART_TITLE});
                panel.setHeadline(sprintf('%d種類の単語を集計しました（表示は多い順に最大%d語）。', numel(words), page.MaxWords.Value));
                panel.showCharts(); page.App.applyTheme();
                page.message('ワードクラウドを作成しました。');
            catch err
                page.showError(err);
            end
        end
    end
    methods (Access = private)
        function buildStyle(page, parent)
            grid = uigridlayout(parent, [7, 2]); grid.RowHeight = repmat({26}, 1, 7); grid.ColumnWidth = {130, '1x'};
            grid.RowSpacing = 4;
            uilabel(grid, 'Text', '形');
            page.Shape = uidropdown(grid, 'Items', page.SHAPE_NAMES, 'ItemsData', page.SHAPE_CODES);
            uilabel(grid, 'Text', '配色');
            page.Scheme = uidropdown(grid, 'Items', page.SCHEME_NAMES, 'ItemsData', page.SCHEME_CODES, ...
                'ValueChangedFcn', @(~, ~) page.schemeChanged());
            uilabel(grid, 'Text', '文字の色');
            page.BaseColor = uidropdown(grid, 'Items', page.COLOR_NAMES, 'ItemsData', 1:numel(page.COLOR_NAMES), 'Value', 1);
            uilabel(grid, 'Text', '強調する色');
            page.Highlight = uidropdown(grid, 'Items', page.COLOR_NAMES, 'ItemsData', 1:numel(page.COLOR_NAMES), 'Value', 4, ...
                'Tooltip', '単色のとき、出現数の多い単語に使う色です。');
            uilabel(grid, 'Text', '色の範囲');
            page.Palette = uidropdown(grid, 'Items', page.PALETTE_NAMES, 'ItemsData', page.PALETTE_CODES, ...
                'Tooltip', '「出現数で色を変える」「ランダムな色」で使う色の並びです。');
            [~, page.MaxWords] = AppPage.numberField(grid, '表示する単語の数', page.DEFAULT_MAX_WORDS, [5, 1000], true);
            [~, page.SizePower] = AppPage.numberField(grid, '文字の大きさの差', page.DEFAULT_SIZE_POWER, [0.1, 3], false);
            page.SizePower.Tooltip = '大きいほど、出現数による文字の大きさの差が強くなります（既定0.5）。';
        end
        function schemeChanged(page)
            single = strcmp(page.Scheme.Value, 'single');
            page.BaseColor.Enable = matlab.lang.OnOffSwitchState(single);
            page.Highlight.Enable = matlab.lang.OnOffSwitchState(single);
            page.Palette.Enable = matlab.lang.OnOffSwitchState(~single);
        end
        function [colors, highlight] = wordColors(page, counts)
            % 単語ごとの色（counts は多い順）。単色はすべて同じ色で、多い単語だけ強調する色にする。
            switch page.Scheme.Value
                case 'single'
                    colors = page.COLOR_VALUES(page.BaseColor.Value, :); highlight = page.COLOR_VALUES(page.Highlight.Value, :);
                    return;
                case 'gradient'
                    % 出現数を0〜1へそろえ、色の並びの左（少ない）から右（多い）へ割り当てる。
                    palette = feval(page.Palette.Value, 256); span = max(counts) - min(counts);
                    level = ones(size(counts)); if span > 0, level = (counts - min(counts)) / span; end
                    colors = palette(1 + round(255 * level), :);
                otherwise
                    palette = feval(page.Palette.Value, 256); stream = RandStream('twister', 'Seed', page.RANDOM_SEED);
                    colors = palette(randi(stream, 256, numel(counts), 1), :);
            end
            % 色を単語ごとに指定したときは、強調の色も最も多い単語の色にそろえる（強調で色が変わらないように）。
            highlight = colors(1, :);
        end
        function chooseText(page)
            try
                path = page.App.chooseOpenFile({'*.txt', 'テキスト（*.txt）'}, 'テキストファイルを選択');
                if isempty(path), return; end
                page.loadText(path);
            catch err
                page.showError(err);
            end
        end
    end
end
