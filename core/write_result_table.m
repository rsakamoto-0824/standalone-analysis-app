function write_result_table(data, path)
% 表を CSV / Excel へ保存する。
% CSV は日本語の列名が Windows の Excel で文字化けしないよう、UTF-8 の先頭に BOM を付ける。
UTF8_BOM = uint8([239, 187, 191]);
[~, ~, extension] = fileparts(path);
if ~any(strcmpi(extension, {'.csv', '.xlsx'}))
    error('write_result_table:fileType', '保存形式は CSV（.csv）または Excel（.xlsx）を選んでください。');
end
write_row_names = istable(data) && ~isempty(data.Properties.RowNames);
if strcmpi(extension, '.xlsx')
    writetable(data, path, 'WriteRowNames', write_row_names); return;
end
writetable(data, path, 'WriteRowNames', write_row_names, 'Encoding', 'UTF-8');
file = fopen(path, 'r'); if file < 0, error('write_result_table:open', '保存したファイルを開けません: %s', path); end
bytes = fread(file, Inf, '*uint8'); fclose(file);
if numel(bytes) >= 3 && isequal(bytes(1:3)', UTF8_BOM), return; end
file = fopen(path, 'w'); if file < 0, error('write_result_table:open', 'ファイルへ書き込めません: %s', path); end
cleanup = onCleanup(@() fclose(file));
fwrite(file, [UTF8_BOM, bytes(:)'], 'uint8');
end
