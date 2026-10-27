function metrics = calc_all_metrics(col1, col2)
if numel(col1) ~= numel(col2)
    error('calc_all_metrics:rowCount', 'col1 と col2 の要素数が一致しません。(%d vs %d)', numel(col1), numel(col2));
end
if numel(col1) < 2
    error('calc_all_metrics:tooFewRows', 'データは2点以上必要です。');
end
metrics = {'rmse', calc_rmse(col1, col2); 'mae', calc_mae(col1, col2); ...
    'r', calc_pearson(col1, col2); 'r_squared', calc_r_squared(col1, col2)};
end
