classdef AppPage < handle
    % 各機能画面の共通部分。下部の状況欄、エラー表示、設定の参照をまとめる。
    properties (SetAccess = protected)
        App
        Root
        Body
        Status
    end
    properties (Constant)
        STATUS_HEIGHT = 66
        MAX_STATUS_LINES = 200
        ROW_HEIGHT = 30
        ACCENT_TAG = 'accent'
        STATE_TAG = 'state'
    end
    methods
        function page = AppPage(app, parent)
            page.App = app;
            page.Root = uigridlayout(parent, [2, 1]);
            page.Root.RowHeight = {'1x', page.STATUS_HEIGHT}; page.Root.Padding = [8, 8, 8, 8];
            page.Body = uigridlayout(page.Root, [1, 1]); page.Body.Padding = [0, 0, 0, 0];
            page.Status = uitextarea(page.Root, 'Editable', 'off', 'Value', {'（ここに処理の状況と注意を、新しい順に表示します）'}, ...
                'Tooltip', 'この画面の処理状況と注意です。新しい内容が上に表示されます。');
        end
        function message(page, text)
            % 新しい内容を上に表示する。スクロールしなくても最新の状況が見える。
            added = status_lines(text); added = added(~cellfun(@isempty, added));
            if isempty(added), return; end
            stamp = char(datetime('now', 'Format', 'HH:mm:ss'));
            added = cellfun(@(line) sprintf('%s  %s', stamp, line), added, 'UniformOutput', false);
            lines = [added; status_lines(page.Status.Value)];
            if numel(lines) > page.MAX_STATUS_LINES, lines = lines(1:page.MAX_STATUS_LINES); end
            page.Status.Value = lines;
        end
        function showError(page, err)
            page.message(['エラー: ' err.message]);
            page.App.alert(err.message, '処理を中止しました', 'error');
        end
        function showWarnings(page, warnings)
            warnings = string(warnings);
            if isempty(warnings), return; end
            page.message("注意: " + warnings(:));
            page.App.alert(char(strjoin(warnings(:), newline)), '注意', 'warning');
        end
        function setState(page, label, text, is_ok)
            % 確認状況の文字と色（確認済み=緑、未確認=橙）を設定する。色はテーマの適用時に決まる。
            label.Text = text; label.UserData = 'wait';
            if is_ok, label.UserData = 'ok'; end
            apply_app_theme(label, page.App.Settings.Theme);
        end
        function values = settings(page)
            values = page.App.Settings;
        end
        function onSettingsChanged(~)
            % 設定の保存時に呼ばれる。必要な画面だけ上書きする。
        end
        function onShown(~)
            % 画面を開いたときに呼ばれる。必要な画面だけ上書きする。
        end
    end
    methods (Static)
        function panel = section(parent, title_text)
            panel = uipanel(parent, 'Title', title_text, 'FontWeight', 'bold');
        end
        function button = primaryButton(parent, text, callback)
            button = uibutton(parent, 'Text', text, 'FontWeight', 'bold', 'ButtonPushedFcn', callback, ...
                'Tag', AppPage.ACCENT_TAG, 'BackgroundColor', [0.12, 0.35, 0.58], 'FontColor', [1, 1, 1]);
        end
        function label = stateLabel(parent)
            label = uilabel(parent, 'Text', '', 'FontWeight', 'bold', 'WordWrap', 'on', 'Tag', AppPage.STATE_TAG, ...
                'UserData', 'wait', 'Interpreter', 'none');
        end
        function fillLastRow(grid)
            % 最後の伸縮行（'1x'）が空のままだと、固定高さの行が上下に広がって表示される。
            % 空の部品で埋めて、項目が上から詰まって並ぶようにする。
            label = uilabel(grid, 'Text', '');
            label.Layout.Row = numel(grid.RowHeight); columns = numel(grid.ColumnWidth);
            if columns > 1, label.Layout.Column = [1, columns]; else, label.Layout.Column = 1; end
        end
        function label = hint(parent, text)
            label = uilabel(parent, 'Text', text, 'WordWrap', 'on', 'VerticalAlignment', 'top');
        end
        function [label, field] = numberField(parent, text, value, limits, integer)
            label = uilabel(parent, 'Text', text);
            field = uieditfield(parent, 'numeric', 'Value', value, 'Limits', limits);
            if integer, field.RoundFractionalValues = 'on'; else, field.ValueDisplayFormat = '%.9g'; end
        end
    end
end
