function matrix = extract_numeric_columns(source, names, allow_missing)
if nargin < 3, allow_missing = false; end
names = cellstr(string(names));
if numel(unique(names)) ~= numel(names)
    error('extract_numeric_columns:duplicateColumns', '同じ入力列が複数の変数に割り当てられています。');
end
if isempty(names)
    error('extract_numeric_columns:noColumns', '列を選択してください。');
end
indices = zeros(1, numel(names));
for column = 1:numel(names)
    matches = find(strcmp(source.Headers, names{column}));
    if numel(matches) ~= 1
        error('extract_numeric_columns:missingColumn', '必須列「%s」が不足または重複しています。', names{column});
    end
    indices(column) = matches;
end
matrix = nan(size(source.Cells, 1), numel(names));
for column = 1:numel(names)
    for row = 1:size(matrix, 1)
        value = source.Cells{row, indices(column)};
        if isempty(value) || (isscalar(value) && ismissing(value))
            matrix(row, column) = NaN;
        elseif isnumeric(value) && isscalar(value) && isreal(value)
            matrix(row, column) = double(value);
        elseif ischar(value) || (isstring(value) && isscalar(value))
            if strlength(strtrim(string(value))) == 0
                matrix(row, column) = NaN;
            else
                number = str2double(value);
                if isnan(number) && ~strcmpi(strtrim(string(value)), 'NaN')
                    error('extract_numeric_columns:nonNumeric', ...
                        '元ファイルの行 %d、列「%s」は数値ではありません。', source.RowNumbers(row), names{column});
                end
                matrix(row, column) = number;
            end
        else
            error('extract_numeric_columns:nonNumeric', ...
                '元ファイルの行 %d、列「%s」は数値ではありません。', source.RowNumbers(row), names{column});
        end
    end
end
missing_rows = find(any(isnan(matrix), 2));
if ~allow_missing && ~isempty(missing_rows)
    error('extract_numeric_columns:missingRows', '欠損値を含む元ファイルの行番号: %s', ...
        strjoin(string(source.RowNumbers(missing_rows)'), ', '));
end
if any(isinf(matrix(:)))
    rows = find(any(isinf(matrix), 2));
    error('extract_numeric_columns:infiniteRows', '無限大を含む元ファイルの行番号: %s', ...
        strjoin(string(source.RowNumbers(rows)'), ', '));
end
end
