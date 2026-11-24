classdef DataSourceControl < handle
    % Excel / CSV の選択、シート・ヘッダー行の指定、先頭行の表示をまとめた部品。
    % 入力ダイアログを何度も開かず、画面内でシートとヘッダー行を変更できる。
    properties (SetAccess = private)
        Grid
        OpenButton
        FileLabel
        Sheet
        HeaderRow
        Data = []
        Path = ''
    end
    properties
        LoadedFcn = []
        PreviewTable = []
    end
    properties (Access = private)
        Owner
        Reader
        Updating = false
    end
    properties (Constant)
        PREVIEW_ROWS = 100
        NO_FILE_TEXT = '入力ファイル未選択'
        FILE_FILTER = {'*.xlsx;*.csv', 'Excel / CSV（*.xlsx, *.csv）'}
    end
    methods
        function control = DataSourceControl(owner, parent, reader, button_text)
            if nargin < 3 || isempty(reader), reader = @read_input_data; end
            if nargin < 4, button_text = 'Excel / CSV を開く'; end
            control.Owner = owner; control.Reader = reader;
            control.Grid = uigridlayout(parent, [2, 4]);
            control.Grid.RowHeight = {30, 30}; control.Grid.ColumnWidth = {150, '1x', 90, 70};
            control.Grid.Padding = [0, 0, 0, 0];
            control.OpenButton = uibutton(control.Grid, 'Text', button_text, 'ButtonPushedFcn', @(~, ~) control.choose());
            control.FileLabel = uilabel(control.Grid, 'Text', control.NO_FILE_TEXT);
            control.FileLabel.Layout.Column = [2, 4];
            label = uilabel(control.Grid, 'Text', 'シート', 'HorizontalAlignment', 'right');
            label.Layout.Row = 2; label.Layout.Column = 1;
            control.Sheet = uidropdown(control.Grid, 'Items', {'(ファイル未選択)'}, 'Enable', 'off', ...
                'ValueChangedFcn', @(~, ~) control.reload());
            control.Sheet.Layout.Row = 2; control.Sheet.Layout.Column = 2;
            label = uilabel(control.Grid, 'Text', 'ヘッダー行', 'HorizontalAlignment', 'right');
            label.Layout.Row = 2; label.Layout.Column = 3;
            control.HeaderRow = uieditfield(control.Grid, 'numeric', 'Value', 1, 'Limits', [1, 1e6], ...
                'RoundFractionalValues', 'on', 'Enable', 'off', 'ValueChangedFcn', @(~, ~) control.reload(), ...
                'Tooltip', '列名が書かれている行の番号です。');
            control.HeaderRow.Layout.Row = 2; control.HeaderRow.Layout.Column = 4;
        end
        function choose(control)
            path = control.Owner.App.chooseOpenFile(control.FILE_FILTER, '入力ファイルを選択');
            if isempty(path), return; end
            control.open(path);
        end
        function succeeded = open(control, path, sheet, header_row)
            % 画面のボタンとテストの両方から使う読込みの入口。
            if nargin < 3, sheet = ''; end
            if nargin < 4, header_row = 1; end
            succeeded = false;
            try
                [~, ~, extension] = fileparts(path);
                sheets = {'(CSV)'};
                if strcmpi(extension, '.xlsx')
                    % sheetnames は配布版で止まることがあったため、自前の読み取りでシート名を得る。
                    [~, sheets] = read_xlsx_cells(path);
                    if isempty(sheet), sheet = sheets{1}; end
                    if ~any(strcmp(sheets, sheet)), error('DataSourceControl:sheet', 'シート「%s」が見つかりません。', sheet); end
                else
                    sheet = sheets{1};
                end
                data = control.read(path, sheet, header_row);
                control.Updating = true; restore = onCleanup(@() control.finishUpdate());
                set(control.Sheet, 'Items', sheets, 'Value', sheet, 'Enable', matlab.lang.OnOffSwitchState(numel(sheets) > 1));
                control.HeaderRow.Value = header_row; control.HeaderRow.Enable = 'on';
                clear restore;
                control.Path = path; control.accept(data);
                succeeded = true;
            catch err
                control.Owner.showError(err);
            end
        end
        function reload(control)
            if control.Updating || isempty(control.Path), return; end
            try
                control.accept(control.read(control.Path, control.Sheet.Value, control.HeaderRow.Value));
            catch err
                control.Owner.showError(err);
            end
        end
        function clear(control)
            control.Data = []; control.Path = ''; control.FileLabel.Text = control.NO_FILE_TEXT;
            set(control.Sheet, 'Items', {'(ファイル未選択)'}, 'Enable', 'off'); control.HeaderRow.Enable = 'off';
            if ~isempty(control.PreviewTable), control.PreviewTable.Data = table(); end
        end
        function name = fileName(control)
            name = '';
            if isempty(control.Path), return; end
            [~, base, extension] = fileparts(control.Path); name = [base extension];
        end
    end
    methods (Access = private)
        function finishUpdate(control)
            control.Updating = false;
        end
        function data = read(control, path, sheet, header_row)
            if strcmp(sheet, '(CSV)'), sheet = 1; end
            data = control.Reader(path, sheet, header_row);
        end
        function accept(control, data)
            control.Data = data;
            control.FileLabel.Text = sprintf('%s（%d行 × %d列）', control.fileName(), size(data.Cells, 1), numel(data.Headers));
            control.FileLabel.Tooltip = control.Path;
            if ~isempty(control.PreviewTable), control.showPreview(); end
            if ~isempty(control.LoadedFcn), control.LoadedFcn(data); end
        end
        function showPreview(control)
            cells = control.Data.Cells(1:min(control.PREVIEW_ROWS, size(control.Data.Cells, 1)), :);
            for index = 1:numel(cells)
                value = cells{index};
                if isempty(value) || (isscalar(value) && ismissing(value))
                    cells{index} = '';
                elseif ~(ischar(value) || (isnumeric(value) && isscalar(value)) || (islogical(value) && isscalar(value)))
                    cells{index} = char(string(value));
                end
            end
            control.PreviewTable.Data = cells; control.PreviewTable.ColumnName = control.Data.Headers;
        end
    end
end
