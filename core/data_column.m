function column = data_column(data, name)
% 読み込んだデータ（read_input_data の戻り値）から1列を取り出す。
%   column.Name      列名
%   column.Numbers   数値（数値でない値・空欄は NaN）
%   column.Labels    表示用の文字（空欄は "(欠損)"）
%   column.Missing   空欄の行
%   column.IsNumeric 空欄以外がすべて数値なら true（文字が1つでもあれば質的変数として扱う）
position = find(strcmp(data.Headers, name), 1);
if isempty(position), error('data_column:name', '列「%s」が見つかりません。', name); end
cells = data.Cells(:, position); count = numel(cells);
numbers = NaN(count, 1); labels = strings(count, 1); missing = false(count, 1); numeric = true;
for index = 1:count
    value = cells{index};
    if isempty(value) || (isscalar(value) && ismissing(value))
        labels(index) = "(欠損)"; missing(index) = true; continue;
    end
    labels(index) = string(value);
    if (isnumeric(value) || islogical(value)) && isscalar(value)
        numbers(index) = double(value);
    else
        numeric = false;
    end
end
if ~any(~missing), numeric = false; end
column = struct('Name', char(name), 'Numbers', numbers, 'Labels', labels, 'Missing', missing, 'IsNumeric', numeric);
end
