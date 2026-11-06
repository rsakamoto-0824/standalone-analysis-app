function fit = fit_swing_spline(thickness, contribution)
validateattributes(thickness, {'numeric'}, {'vector', 'real', 'finite'});
validateattributes(contribution, {'numeric'}, {'vector', 'real', 'finite'});
[thickness, contribution] = metric_inputs(thickness, contribution, 4, mfilename);
[distinct, ~, group] = unique(thickness);
if numel(distinct) < 4, error('fit_swing_spline:distinct', 'スプライン補間には異なる膜厚が4点以上必要です。'); end
center = mean([min(distinct), max(distinct)]); scale = max(distinct) - min(distinct);
averages = accumarray(group, contribution, [], @mean);
pp = spline((distinct - center) / scale, averages);
prediction = ppval(pp, (thickness - center) / scale);
denominator = sum((contribution - mean(contribution)).^2);
r_squared = NaN;
if denominator > 0, r_squared = 1 - sum((contribution - prediction).^2) / denominator; end
fit = struct('Method', 'spline', 'PP', pp, 'Center', center, 'Scale', scale, ...
    'Prediction', prediction, 'Count', numel(thickness), 'DistinctCount', numel(distinct), ...
    'DataRange', [min(distinct), max(distinct)], 'RMSE', sqrt(mean((contribution - prediction).^2)), ...
    'RSquared', r_squared, 'Period', NaN, 'Amplitude', NaN, 'Slope', NaN, ...
    'Offset', NaN, 'PhaseRadians', NaN, 'IncludeTrend', false, 'SearchBounds', [NaN, NaN], ...
    'Warnings', "補間点への当てはまりです。周期・一定振幅は定義せず、未知データの精度を表しません。");
if numel(distinct) < numel(thickness)
    fit.Warnings(end+1) = "同じ膜厚のSHAP値は平均して補間し、残差は元の各観測行で計算しています。";
end
end
