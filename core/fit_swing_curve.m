function fit = fit_swing_curve(thickness, contribution, options)
% 周波数だけを探索し、オフセット・傾き・sin/cos係数は各候補で最小二乗推定する。
if nargin < 3, options = struct(); end
validateattributes(thickness, {'numeric'}, {'vector', 'real', 'finite'});
validateattributes(contribution, {'numeric'}, {'vector', 'real', 'finite'});
[thickness, contribution] = metric_inputs(thickness, contribution, 8, mfilename);
if ~isfield(options, 'IncludeTrend'), options.IncludeTrend = true; end
if ~isfield(options, 'PeriodBounds'), options.PeriodBounds = []; end
validateattributes(options.IncludeTrend, {'logical', 'numeric'}, {'scalar', 'binary'});
distinct = unique(thickness);
if numel(distinct) < 8, error('fit_swing_curve:distinct', '異なる膜厚が8点以上必要です。'); end
span = max(distinct) - min(distinct); center = min(distinct) + span / 2;
if isempty(options.PeriodBounds)
    bounds = [max(4 * median(diff(distinct)), span / 20), span];
else
    bounds = options.PeriodBounds;
end
validateattributes(bounds, {'numeric'}, {'vector', 'numel', 2, 'real', 'finite', 'positive'});
bounds = double(bounds(:)');
if bounds(1) >= bounds(2), error('fit_swing_curve:bounds', '周期の下限は上限より小さくしてください。'); end
frequency_bounds = [span / bounds(2), span / bounds(1)];
MAX_CYCLES = 100;
if frequency_bounds(2) > MAX_CYCLES
    error('fit_swing_curve:tooManyCycles', '探索範囲はデータ範囲内で100周期以下にしてください。周期の下限を増やしてください。');
end
response_center = mean(contribution); response_scale = std(contribution);
if response_scale == 0, error('fit_swing_curve:noOscillation', 'SHAP値が一定のため周期を推定できません。'); end
if ~isfinite(response_scale), error('fit_swing_curve:scale', 'SHAP値の桁が大きすぎます。入力を確認してください。'); end
z = (thickness - center) / span; response = (contribution - response_center) / response_scale;
grid_count = max(401, ceil(diff(frequency_bounds) * 80) + 1);
frequency_grid = linspace(frequency_bounds(1), frequency_bounds(2), grid_count);
scores = zeros(size(frequency_grid));
for index = 1:grid_count
    scores(index) = solveAtFrequency(frequency_grid(index), z, response, options.IncludeTrend);
end
[best_score, best_index] = min(scores); best_frequency = frequency_grid(best_index);
local_minima = find(scores(2:end - 1) <= scores(1:end - 2) & scores(2:end - 1) <= scores(3:end)) + 1;
optimizer_options = optimset('Display', 'off', 'TolX', 1e-10);
for index = local_minima
    [frequency, score] = fminbnd(@(value) solveAtFrequency(value, z, response, options.IncludeTrend), ...
        frequency_grid(index - 1), frequency_grid(index + 1), optimizer_options);
    if score < best_score, best_score = score; best_frequency = frequency; end
end
if ~isfinite(best_score), error('fit_swing_curve:rank', '指定周期範囲で独立な近似項を求められません。'); end
[~, coefficients] = solveAtFrequency(best_frequency, z, response, options.IncludeTrend);
coefficients = response_scale * coefficients;
fit = struct('Center', center, 'Offset', response_center + coefficients(1), ...
    'Slope', 0, 'SinCoefficient', coefficients(end - 1), 'CosCoefficient', coefficients(end), ...
    'Period', span / best_frequency, 'SearchBounds', bounds, 'IncludeTrend', logical(options.IncludeTrend), ...
    'Count', numel(thickness), 'DataRange', [min(thickness), max(thickness)], 'Warnings', strings(0, 1));
if options.IncludeTrend, fit.Slope = coefficients(2) / span; end
fit.Amplitude = hypot(fit.SinCoefficient, fit.CosCoefficient);
fit.PhaseRadians = atan2(fit.CosCoefficient, fit.SinCoefficient);
if fit.Amplitude < 1e-7 * response_scale
    error('fit_swing_curve:noOscillation', '周期成分がほぼ0のため、周期・極値を識別できません。');
end
fit.Prediction = swing_curve_values(fit, thickness);
fit.RMSE = sqrt(mean((contribution - fit.Prediction).^2));
fit.RSquared = 1 - sum((contribution - fit.Prediction).^2) / sum((contribution - response_center).^2);
if fit.RSquared < 0.5, fit.Warnings(end + 1) = "近似のR²が0.5未満です。周期・極値の解釈に注意してください。"; end
if any(abs(best_frequency - frequency_bounds) < 1e-4 * max(1, diff(frequency_bounds)))
    fit.Warnings(end + 1) = "推定周期が探索範囲の端にあります。周期範囲を見直してください。";
end
if span < fit.Period, fit.Warnings(end + 1) = "対象範囲が1周期未満です。周期の識別にはより広い膜厚範囲が必要です。"; end
if fit.Period < 4 * median(diff(distinct))
    fit.Warnings(end + 1) = "周期に対して膜厚点の間隔が大きいため、周期の取り違えに注意してください。";
end
end

function [score, coefficients] = solveAtFrequency(frequency, z, response, include_trend)
angle = 2 * pi * frequency * z;
matrix = [ones(size(z)), sin(angle), cos(angle)];
if include_trend, matrix = [ones(size(z)), z, sin(angle), cos(angle)]; end
[orthogonal, upper] = qr(matrix, 0);
if rcond(upper) < 1e-10, score = Inf; coefficients = []; return; end
coefficients = upper \ (orthogonal' * response);
score = sum((response - matrix * coefficients).^2);
end
