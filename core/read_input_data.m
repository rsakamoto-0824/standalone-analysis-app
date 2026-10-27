function source = read_input_data(fullName, sheet, header_row)
if nargin < 2 || isempty(sheet), sheet = 1; end
if nargin < 3, header_row = 1; end
validateattributes(header_row, {'numeric'}, {'scalar', 'integer', 'positive'}, mfilename, 'header_row');
[~, ~, extension] = fileparts(fullName);
switch lower(extension)
    case '.xlsx'
        cells = readcell(fullName, 'Sheet', sheet, 'UseExcel', false);
    case '.csv'
        cells = readcell(fullName, 'FileType', 'text', 'Delimiter', ',', 'EmptyLineRule', 'read');
    otherwise
        error('read_input_data:fileType', '入力ファイルは .xlsx または .csv としてください。');
end
if header_row >= size(cells, 1)
    error('read_input_data:noRows', '指定ヘッダー行の後にデータがありません。');
end
headers = strings(1, size(cells, 2));
for column = 1:size(cells, 2)
    value = cells{header_row, column};
    if isempty(value) || ~(ischar(value) || (isstring(value) && isscalar(value))) || ...
            any(ismissing(string(value))) || strlength(string(value)) == 0
        error('read_input_data:emptyHeader', '列 %d のヘッダーは空でない列名にしてください。', column);
    end
    headers(column) = string(value);
end
if numel(unique(headers)) ~= numel(headers)
    error('read_input_data:duplicateHeaders', '入力ファイルに重複する列名があります。元のヘッダーを修正してください。');
end
source = struct('FileName', char(fullName), 'Sheet', sheet, 'HeaderRow', header_row, ...
    'Headers', {cellstr(headers)}, 'Cells', {cells(header_row + 1:end, :)}, ...
    'RowNumbers', (header_row + 1:size(cells, 1))');
end
