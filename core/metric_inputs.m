function [x, y] = metric_inputs(x, y, minimum_count, identifier)
validate_numeric_data(x, '第一入力', identifier);
validate_numeric_data(y, '第二入力', identifier);
x = double(x(:));
y = double(y(:));
if numel(x) ~= numel(y)
    error([identifier ':rowCount'], '入力の要素数が一致しません。(%d vs %d)', numel(x), numel(y));
end
if numel(x) < minimum_count
    error([identifier ':tooFewRows'], 'データは%d点以上必要です。', minimum_count);
end
end
