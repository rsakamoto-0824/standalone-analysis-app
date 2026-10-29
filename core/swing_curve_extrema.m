function [extrema, segments] = swing_curve_extrema(fit, limits)
validateattributes(limits, {'numeric'}, {'vector', 'numel', 2, 'real', 'finite'});
if limits(1) >= limits(2), error('swing_curve_extrema:range', '膜厚範囲の下限は上限より小さくしてください。'); end
extrema = table(strings(0, 1), zeros(0, 1), zeros(0, 1), 'VariableNames', {'Type', 'Thickness', 'SHAP'});
segments = table(strings(0, 1), zeros(0, 1), zeros(0, 1), zeros(0, 1), zeros(0, 1), zeros(0, 1), ...
    'VariableNames', {'Type', 'StartThickness', 'EndThickness', 'StartSHAP', 'EndSHAP', 'Slope'});
angular_frequency = 2 * pi / fit.Period;
ratio = -fit.Slope / (fit.Amplitude * angular_frequency);
% 接するだけの停留点は極値ではない。範囲の端点も極値として追加しない。
if abs(ratio) >= 1, return; end
angles = [acos(ratio), -acos(ratio)]; types = ["極大", "極小"];
for kind = 1:2
    lower_k = ceil((angular_frequency * (limits(1) - fit.Center) + fit.PhaseRadians - angles(kind)) / (2 * pi) - 1e-12);
    upper_k = floor((angular_frequency * (limits(2) - fit.Center) + fit.PhaseRadians - angles(kind)) / (2 * pi) + 1e-12);
    if upper_k - lower_k > 1000, error('swing_curve_extrema:rangeTooWide', '表示範囲を1000周期以下にしてください。'); end
    thickness = fit.Center + (angles(kind) + 2 * pi * (lower_k:upper_k)' - fit.PhaseRadians) / angular_frequency;
    thickness = thickness(thickness >= limits(1) - 1e-10 * fit.Period & thickness <= limits(2) + 1e-10 * fit.Period);
    thickness = min(max(thickness, limits(1)), limits(2));
    values = swing_curve_values(fit, thickness);
    extrema = [extrema; table(repmat(types(kind), numel(thickness), 1), thickness, values, ...
        'VariableNames', extrema.Properties.VariableNames)]; %#ok<AGROW>
    if numel(thickness) >= 2
        slopes = diff(values) ./ diff(thickness);
        segments = [segments; table(repmat(types(kind) + "間", numel(slopes), 1), thickness(1:end - 1), thickness(2:end), ...
            values(1:end - 1), values(2:end), slopes, 'VariableNames', segments.Properties.VariableNames)]; %#ok<AGROW>
    end
end
extrema = sortrows(extrema, 'Thickness'); segments = sortrows(segments, {'StartThickness', 'Type'});
end
