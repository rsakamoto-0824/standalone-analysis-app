function source = read_furnace_data(path, sheet, header_row)
source = read_input_data(path, sheet, header_row);
[~, ~, extension] = fileparts(path);
if strcmpi(extension, '.csv')
    % 識別子の先頭ゼロを数値の自動判定で失わないよう、CSVは文字列として読む。
    options = delimitedTextImportOptions('NumVariables', numel(source.Headers), 'Delimiter', ',');
    options.DataLines = [header_row + 1, Inf]; options.VariableNamingRule = 'preserve'; options.VariableNames = source.Headers;
    options.VariableTypes = repmat("string", 1, numel(source.Headers)); options.EmptyLineRule = 'read';
    options.ExtraColumnsRule = 'error';
    options = setvaropts(options, options.VariableNames, 'WhitespaceRule', 'preserve');
    imported = readtable(path, options); source.Cells = table2cell(imported);
    source.RowNumbers = (header_row + 1:header_row + height(imported))';
end
end
