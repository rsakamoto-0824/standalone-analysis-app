function summary = calc_column_summary(data)
if ~isnumeric(data) || ~isreal(data)
    error('calc_column_summary:invalidData', 'data は数値配列で渡してください。');
end
if isempty(data)
    error('calc_column_summary:emptyData', 'data が空です。');
end
data = data(:);
n_missing = sum(isnan(data));
data_clean = data(~isnan(data));
if numel(data_clean) < 2
    error('calc_column_summary:tooFewRows', ...
        '有効なデータが %d 件しかありません。算出には2件以上必要です。', numel(data_clean));
end
if any(isinf(data_clean))
    error('calc_column_summary:infiniteData', 'data に無限大が含まれています。');
end
data_clean = double(data_clean);
q = quantile(data_clean, [0.25, 0.75]);
summary = {'n', numel(data_clean); 'n_missing', n_missing; ...
    'mean', mean(data_clean); 'median', median(data_clean); ...
    'max', max(data_clean); 'min', min(data_clean); ...
    'range', max(data_clean) - min(data_clean); 'iqr', q(2) - q(1); ...
    'q1', q(1); 'q3', q(2); 'std', std(data_clean)};
end
