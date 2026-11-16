classdef ColumnMapper < handle
    % 「モデルの変数 → 入力ファイルの列」を、1行ごとのドロップダウンで割り当てる部品。
    % 表のセル編集は気づきにくいため、常に見える選択欄を使う。
    properties (SetAccess = private)
        Grid
        Roles = {}
        Headers = {}
        Dropdowns = {}
    end
    properties
        ChangedFcn = []
    end
    properties (Constant)
        NONE = '(未選択)'
        ROW_HEIGHT = 26
        ROLE_WIDTH = 150
    end
    methods
        function mapper = ColumnMapper(parent)
            mapper.Grid = uigridlayout(parent, [1, 2], 'Scrollable', 'on');
            mapper.Grid.ColumnWidth = {mapper.ROLE_WIDTH, '1x'}; mapper.Grid.RowHeight = {mapper.ROW_HEIGHT};
            mapper.Grid.Padding = [4, 4, 4, 4]; mapper.Grid.RowSpacing = 4;
            mapper.showPlaceholder('モデルと入力ファイルを選ぶと、ここに割当欄を表示します。');
        end
        function setRoles(mapper, roles, headers, placeholder)
            % 同じ変数名の以前の選択は、列が残っていれば引き継ぐ。
            if nargin < 4, placeholder = 'モデルと入力ファイルを選ぶと、ここに割当欄を表示します。'; end
            roles = cellstr(string(roles(:)')); headers = cellstr(string(headers(:)'));
            previous = containers.Map('KeyType', 'char', 'ValueType', 'char');
            for index = 1:numel(mapper.Roles)
                previous(mapper.Roles{index}) = mapper.Dropdowns{index}.Value;
            end
            delete(mapper.Grid.Children); mapper.Dropdowns = {}; mapper.Roles = roles; mapper.Headers = headers;
            if isempty(roles) || isempty(headers)
                mapper.Roles = {}; mapper.showPlaceholder(placeholder); return;
            end
            mapper.Grid.RowHeight = repmat({mapper.ROW_HEIGHT}, 1, numel(roles));
            items = [{mapper.NONE}, headers];
            for index = 1:numel(roles)
                label = uilabel(mapper.Grid, 'Text', sprintf('%d. %s', index, roles{index}), 'Interpreter', 'none', 'Tooltip', roles{index});
                label.Layout.Row = index; label.Layout.Column = 1;
                selected = mapper.NONE;
                if isKey(previous, roles{index}) && any(strcmp(headers, previous(roles{index})))
                    selected = previous(roles{index});
                elseif any(strcmp(headers, roles{index}))
                    selected = roles{index};
                end
                field = uidropdown(mapper.Grid, 'Items', items, 'Value', selected, 'ValueChangedFcn', @(~, ~) mapper.changed());
                field.Layout.Row = index; field.Layout.Column = 2;
                mapper.Dropdowns{index} = field;
            end
        end
        function select(mapper, columns)
            % テストや自動割当から、変数の順に列を指定する。
            columns = cellstr(string(columns(:)'));
            if numel(columns) ~= numel(mapper.Dropdowns)
                error('ColumnMapper:count', '変数の数と同じ数の列を指定してください。');
            end
            for index = 1:numel(columns), mapper.Dropdowns{index}.Value = columns{index}; end
            mapper.changed();
        end
        function columns = selection(mapper)
            columns = cellfun(@(field) field.Value, mapper.Dropdowns, 'UniformOutput', false);
        end
        function rows = mapping(mapper)
            % assign_required_columns へ渡す {順序, 変数, 入力列} の表。
            columns = mapper.selection(); rows = cell(numel(columns), 3);
            for index = 1:numel(columns), rows(index, :) = {index, mapper.Roles{index}, columns{index}}; end
        end
        function requireComplete(mapper)
            columns = mapper.selection();
            if isempty(columns), error('ColumnMapper:empty', '割り当てる変数がありません。モデルと入力ファイルを選択してください。'); end
            missing = strcmp(columns, mapper.NONE);
            if any(missing)
                error('ColumnMapper:unassigned', '入力列を選んでいない変数があります: %s', strjoin(mapper.Roles(missing), ', '));
            end
            if numel(unique(columns)) ~= numel(columns)
                error('ColumnMapper:duplicate', '同じ入力列を複数の変数へ割り当てています。変数ごとに別の列を選んでください。');
            end
        end
    end
    methods (Access = private)
        function changed(mapper)
            if ~isempty(mapper.ChangedFcn), mapper.ChangedFcn(); end
        end
        function showPlaceholder(mapper, text)
            mapper.Grid.RowHeight = {'1x'};
            label = uilabel(mapper.Grid, 'Text', text, 'WordWrap', 'on', 'VerticalAlignment', 'top');
            label.Layout.Row = 1; label.Layout.Column = [1, 2];
        end
    end
end
