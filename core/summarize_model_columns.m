function summary = summarize_model_columns(matrix, names)
if size(matrix, 2) ~= numel(names), error('summary:columns', '列数と列名数が一致しません。'); end
summary = table();
for column = 1:size(matrix, 2)
    values = calc_column_summary(matrix(:, column));
    part = table(repmat(string(names(column)), size(values, 1), 1), ...
        string(values(:, 1)), cell2mat(values(:, 2)), ...
        'VariableNames', {'Column', 'Statistic', 'Value'});
    summary = [summary; part]; %#ok<AGROW>
end
end
