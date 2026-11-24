function source = read_furnace_data(path, sheet, header_row)
source = read_input_data(path, sheet, header_row);
[~, ~, extension] = fileparts(path);
if strcmpi(extension, '.csv')
    % 識別子の先頭ゼロを数値の自動判定で失わないよう、CSVは文字列として読む（readtable は配布版で止まることがあったため使わない）。
    cells = read_csv_cells(path, true);
    if size(cells, 2) > numel(source.Headers)
        extra = find(any(~cellfun(@(value) isscalar(value) && ismissing(value), cells(header_row + 1:end, numel(source.Headers) + 1:end)), 2), 1);
        if ~isempty(extra), error('read_furnace_data:extraColumns', '元ファイルの行 %d に、列名より多い値があります。', header_row + extra); end
    end
    data = cells(header_row + 1:end, 1:numel(source.Headers));
    for index = 1:numel(data)
        if ischar(data{index}), data{index} = string(data{index}); end
    end
    source.Cells = data; source.RowNumbers = (header_row + 1:header_row + size(data, 1))';
end
end
