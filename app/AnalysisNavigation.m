classdef AnalysisNavigation < handle
    % 左の画面切替メニュー。目的別の見出しの下に、全文が読める幅のボタンを並べる。
    properties (Constant)
        WIDTH = 240
        BUTTON_HEIGHT = 38
        HEADING_HEIGHT = 24
        SELECTED_COLOR = [0.12, 0.35, 0.58]
    end
    properties (SetAccess = private)
        Layout
        Menu
        Content
        Keys = {}
        Buttons = {}
        Pages = {}
        Headings = {}
        SelectedKey = ''
    end
    properties
        SelectionChangedFcn = []
    end
    properties (Access = private)
        Theme = 'ライト'
        RowCount = 0
    end
    methods
        function navigation = AnalysisNavigation(window)
            navigation.Layout = uigridlayout(window, [1, 2]);
            navigation.Layout.ColumnWidth = {navigation.WIDTH, '1x'}; navigation.Layout.Padding = [0, 0, 0, 0];
            navigation.Layout.ColumnSpacing = 0;
            navigation.Menu = uigridlayout(navigation.Layout, [1, 1], 'Scrollable', 'on');
            navigation.Menu.Padding = [6, 6, 6, 6]; navigation.Menu.RowSpacing = 4; navigation.Menu.RowHeight = {};
            navigation.Content = uigridlayout(navigation.Layout, [1, 1]);
            navigation.Content.Padding = [0, 0, 0, 0];
        end
        function addHeading(navigation, text)
            label = uilabel(navigation.Menu, 'Text', text, 'FontWeight', 'bold', 'FontSize', 11, 'VerticalAlignment', 'bottom');
            navigation.placeRow(label, navigation.HEADING_HEIGHT);
            navigation.Headings{end + 1} = label;
        end
        function page = addPage(navigation, key, title_text)
            page = uipanel(navigation.Content, 'Title', title_text, 'BorderType', 'none', ...
                'Visible', 'off', 'FontWeight', 'bold', 'FontSize', 14);
            page.Layout.Row = 1; page.Layout.Column = 1;
            button = uibutton(navigation.Menu, 'state', 'Text', title_text, 'FontSize', 13, ...
                'HorizontalAlignment', 'left', 'Tooltip', title_text, 'ValueChangedFcn', @(~, ~) navigation.select(key));
            navigation.placeRow(button, navigation.BUTTON_HEIGHT);
            navigation.Keys{end + 1} = key; navigation.Pages{end + 1} = page; navigation.Buttons{end + 1} = button;
        end
        function page = page(navigation, key)
            page = navigation.Pages{navigation.indexOf(key)};
        end
        function select(navigation, key)
            index = navigation.indexOf(key); previous = navigation.SelectedKey;
            for item = 1:numel(navigation.Pages)
                navigation.Pages{item}.Visible = matlab.lang.OnOffSwitchState(item == index);
            end
            navigation.SelectedKey = key; navigation.refreshButtons();
            if ~strcmp(previous, key) && ~isempty(navigation.SelectionChangedFcn)
                navigation.SelectionChangedFcn(key);
            end
        end
        function applyTheme(navigation, theme)
            navigation.Theme = theme; navigation.refreshButtons();
        end
    end
    methods (Access = private)
        function placeRow(navigation, component, height)
            navigation.RowCount = navigation.RowCount + 1;
            navigation.Menu.RowHeight{navigation.RowCount} = height;
            component.Layout.Row = navigation.RowCount; component.Layout.Column = 1;
        end
        function index = indexOf(navigation, key)
            index = find(strcmp(navigation.Keys, key), 1);
            if isempty(index), error('navigation:page', '切替先の画面が見つかりません: %s', key); end
        end
        function refreshButtons(navigation)
            if strcmp(navigation.Theme, 'ダーク')
                surface = [0.14, 0.18, 0.25]; text = [0.92, 0.95, 0.98]; muted = [0.70, 0.76, 0.84];
            else
                surface = [1, 1, 1]; text = [0.12, 0.17, 0.25]; muted = [0.35, 0.40, 0.48];
            end
            for index = 1:numel(navigation.Buttons)
                button = navigation.Buttons{index}; selected = strcmp(navigation.Keys{index}, navigation.SelectedKey);
                button.Value = selected; button.BackgroundColor = surface; button.FontColor = text; button.FontWeight = 'normal';
                if selected
                    button.BackgroundColor = navigation.SELECTED_COLOR; button.FontColor = [1, 1, 1]; button.FontWeight = 'bold';
                end
                navigation.Pages{index}.ForegroundColor = text;
            end
            for index = 1:numel(navigation.Headings), navigation.Headings{index}.FontColor = muted; end
        end
    end
end
