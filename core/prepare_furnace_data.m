function data = prepare_furnace_data(source, wafer_column, slot_column, target_columns, batch_column)
if nargin < 5, batch_column = ''; end
target_columns = cellstr(string(target_columns));
selected = [{char(wafer_column), char(slot_column)}, target_columns];
if ~isempty(batch_column), selected{end + 1} = char(batch_column); end
if isempty(target_columns) || numel(unique(selected)) ~= numel(selected)
    error('furnace:columns', 'WaferId・BoatSlot・目的変数・バッチは異なる列を指定し、目的変数を1列以上選択してください。');
end
slots = extract_numeric_columns(source, {slot_column}); values = extract_numeric_columns(source, target_columns, true);
constants = furnace_constants();
validateattributes(slots, {'numeric'}, {'vector', 'integer', 'positive', '<=', constants.MaximumSlot});
wafer = identifiers(source, wafer_column);
batch = repmat("単一Run", numel(slots), 1);
if ~isempty(batch_column), batch = identifiers(source, batch_column); end
groups = unique(batch, 'stable');
if numel(groups) > constants.MaximumBatches, error('furnace:batchCount', '一括解析するバッチは%d件までです。', constants.MaximumBatches); end
for index = 1:numel(groups)
    rows = batch == groups(index);
    if numel(unique(slots(rows))) ~= sum(rows), error('furnace:duplicateSlots', 'バッチ「%s」内のBoatSlotが重複しています。', groups(index)); end
    if numel(unique(wafer(rows))) ~= sum(rows), error('furnace:duplicateWafer', 'バッチ「%s」内のWaferIdが重複しています。', groups(index)); end
end
data = struct('Slots', slots, 'Values', values, 'WaferId', wafer, 'Batch', batch, ...
    'TargetNames', string(target_columns(:)), 'SourceRows', source.RowNumbers(:));
end

function values = identifiers(source, name)
column = find(strcmp(source.Headers, name));
if numel(column) ~= 1, error('furnace:identifierColumn', '識別列「%s」が不足または重複しています。', name); end
values = strings(size(source.Cells, 1), 1);
for row = 1:numel(values)
    value = source.Cells{row, column};
    if isempty(value) || ~isscalar(string(value)) || ismissing(string(value)) || strlength(strtrim(string(value))) == 0 || ...
            (isnumeric(value) && (~isreal(value) || ~isfinite(value)))
        error('furnace:missingIdentifier', '元ファイルの行%dの「%s」を入力してください。', source.RowNumbers(row), name);
    end
    values(row) = string(value);
end
end
