classdef AnalysisNavigation < handle
    properties (Constant)
        Width = 240
    end
    properties (SetAccess = private)
        Layout
        Menu
        Content
        Buttons = {}
        Pages = {}
    end
    properties
        SelectionChangedFcn = []
    end
    properties (Dependent)
        Children
        SelectedTab
    end
    properties (Access = private)
        ActivePage = []
        Theme = 'ライト'
    end
    methods
        function navigation = AnalysisNavigation(window)
            navigation.Layout = uigridlayout(window, [1, 2]);
            navigation.Layout.ColumnWidth = {navigation.Width, '1x'};
            navigation.Menu = uigridlayout(navigation.Layout, [11, 1], 'Scrollable', 'on');
            navigation.Menu.Layout.Row = 1; navigation.Menu.Layout.Column = 1;
            navigation.Menu.Padding = [4, 4, 4, 4];
            navigation.Menu.RowHeight = [repmat({44}, 1, 10), {'1x'}];
            navigation.Content = uigridlayout(navigation.Layout, [1, 1]);
            navigation.Content.Layout.Row = 1; navigation.Content.Layout.Column = 2;
            navigation.Content.Padding = [0, 0, 0, 0];
        end
        function page = addPage(navigation, title_text)
            % 標準の縦タブには見出し幅の指定がないため、固定幅の切替ボタンを使う。
            page = uipanel(navigation.Content, 'Title', title_text, 'BorderType', 'none', ...
                'Visible', 'off', 'FontWeight', 'bold');
            page.Layout.Row = 1; page.Layout.Column = 1;
            button = uibutton(navigation.Menu, 'state', 'Text', title_text, 'FontSize', 14, ...
                'Tooltip', title_text, 'ValueChangedFcn', @(~, ~) navigation.select(page));
            button.Layout.Row = numel(navigation.Pages) + 1; button.Layout.Column = 1;
            navigation.Pages{end + 1} = page; navigation.Buttons{end + 1} = button;
            if isempty(navigation.ActivePage), navigation.SelectedTab = page; end
        end
        function select(navigation, page)
            navigation.SelectedTab = page;
        end
        function pages = get.Children(navigation)
            pages = [navigation.Pages{:}];
        end
        function page = get.SelectedTab(navigation)
            page = navigation.ActivePage;
        end
        function set.SelectedTab(navigation, page)
            if ~any(cellfun(@(item) isequal(item, page), navigation.Pages))
                error('navigation:page', '切替先の画面が見つかりません。');
            end
            previous = navigation.ActivePage;
            for index = 1:numel(navigation.Pages)
                navigation.Pages{index}.Visible = matlab.lang.OnOffSwitchState(isequal(navigation.Pages{index}, page));
            end
            navigation.ActivePage = page; navigation.refreshButtons();
            if ~isequal(previous, page) && ~isempty(navigation.SelectionChangedFcn)
                navigation.SelectionChangedFcn(navigation, struct('OldValue', previous, 'NewValue', page));
            end
        end
        function applyTheme(navigation, theme)
            navigation.Theme = theme; navigation.refreshButtons();
        end
    end
    methods (Access = private)
        function refreshButtons(navigation)
            if strcmp(navigation.Theme, 'ダーク')
                surface = [0.14, 0.18, 0.25]; text = [0.92, 0.95, 0.98];
            else
                surface = [1, 1, 1]; text = [0.12, 0.17, 0.25];
            end
            for index = 1:numel(navigation.Pages)
                button = navigation.Buttons{index}; selected = isequal(navigation.Pages{index}, navigation.ActivePage);
                button.Value = selected; button.BackgroundColor = surface; button.FontColor = text; button.FontWeight = 'normal';
                if selected
                    button.BackgroundColor = [0.12, 0.35, 0.58]; button.FontColor = [1, 1, 1]; button.FontWeight = 'bold';
                end
                if isprop(navigation.Pages{index}, 'ForegroundColor'), navigation.Pages{index}.ForegroundColor = text; end
                if isprop(navigation.Pages{index}, 'FontColor'), navigation.Pages{index}.FontColor = text; end
            end
        end
    end
end
