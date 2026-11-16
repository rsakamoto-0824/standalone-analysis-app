classdef WordCloudPage < AppPage
    % ワードクラウドの画面。左に文章を入れ、右に図と単語の出現数を表示する。
    properties (SetAccess = private)
        Text
        RunButton
        Result
    end
    properties (Constant)
        LEFT_WIDTH = 440
        SAMPLE_TEXT = 'MATLAB analysis MATLAB model'
        TABLE_WORDS = '単語の出現数'
        CHART_TITLE = 'Word Cloud'
        TITLE_FONT_SIZE = 14
    end
    methods
        function page = WordCloudPage(app, parent)
            page@AppPage(app, parent);
            page.Body.ColumnWidth = {page.LEFT_WIDTH, '1x'}; page.Body.RowHeight = {'1x'};
            left = uigridlayout(page.Body, [4, 1]); left.Padding = [0, 0, 0, 0]; left.RowHeight = {60, 30, '1x', 38};
            AppPage.hint(left, ['文章を入力するか、テキストファイル（.txt）を開きます。日本語は自動で単語に分けないため、' ...
                '単語の間を空白で区切ってください。1文字の単語は除きます。']);
            uibutton(left, 'Text', 'テキストファイルを開く', 'ButtonPushedFcn', @(~, ~) page.chooseText());
            page.Text = uitextarea(left, 'Value', {page.SAMPLE_TEXT});
            page.RunButton = AppPage.primaryButton(left, 'ワードクラウドを作成', @(~, ~) page.run());
            holder = uigridlayout(page.Body, [1, 1]); holder.Padding = [0, 0, 0, 0];
            page.Result = ResultPanel(page, holder, '「ワードクラウドを作成」を押すと、ここに図と単語の出現数を表示します。');
        end
        function loadText(page, path)
            page.Text.Value = cellstr(splitlines(string(fileread(path))));
            [~, base, extension] = fileparts(path); page.message(['テキストを読み込みました: ' base extension]);
        end
        function run(page)
            try
                [words, counts] = create_wordCloud(strjoin(string(page.Text.Value), newline));
                panel = page.Result; panel.clear();
                [counts, order] = sort(counts, 'descend'); words = words(order);
                panel.setTable(page.TABLE_WORDS, table(string(words), counts, 'VariableNames', {'Word', 'Count'}));
                tab = panel.addChartTab(page.CHART_TITLE); layout = uigridlayout(tab, [1, 1]);
                chart = wordcloud(layout, words, counts); chart.Title = page.CHART_TITLE;
                panel.registerCharts({chart}, {page.CHART_TITLE});
                panel.setHeadline(sprintf('%d種類の単語を集計しました。', numel(words)));
                panel.showCharts(); page.App.applyTheme();
                page.message('ワードクラウドを作成しました。');
            catch err
                page.showError(err);
            end
        end
    end
    methods (Access = private)
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
