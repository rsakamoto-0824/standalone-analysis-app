function [extrema, segments] = swing_spline_extrema(fit, limits)
validateattributes(limits, {'numeric'}, {'vector', 'numel', 2, 'real', 'finite'});
if limits(1) >= limits(2) || limits(1) < fit.DataRange(1) || limits(2) > fit.DataRange(2)
    error('swing_spline_extrema:range', '膜厚範囲は補間データの範囲内で指定してください。');
end
pp = fit.PP; coefficients = pp.coefs;
derivative = coefficients(:, 1:end-1) .* (pp.order-1:-1:1);
dpp = mkpp(pp.breaks, derivative);
positions = [];
for piece = 1:pp.pieces
    candidates = roots(derivative(piece, :));
    candidates = real(candidates(abs(imag(candidates)) < 1e-10));
    width = pp.breaks(piece+1) - pp.breaks(piece);
    candidates = candidates(candidates >= -1e-12 & candidates <= width + 1e-12);
    positions = [positions; pp.breaks(piece) + candidates(:)]; %#ok<AGROW>
end
positions = sort(positions);
if ~isempty(positions), positions = positions([true; diff(positions) > 1e-9]); end
types = strings(0, 1); thickness = zeros(0, 1);
for index = 1:numel(positions)
    z = positions(index); physical = fit.Center + fit.Scale * z;
    step = min([1e-6, (z-pp.breaks(1))/2, (pp.breaks(end)-z)/2]);
    if step <= 0 || physical < limits(1)-1e-9 || physical > limits(2)+1e-9, continue; end
    left = ppval(dpp, z-step); right = ppval(dpp, z+step);
    if left > 0 && right < 0
        kind = "極大";
    elseif left < 0 && right > 0
        kind = "極小";
    else
        continue;
    end
    thickness(end+1, 1) = physical; types(end+1, 1) = kind; %#ok<AGROW>
end
values = zeros(0, 1);
if ~isempty(thickness), values = swing_curve_values(fit, thickness); end
extrema = table(types, thickness, values, 'VariableNames', {'Type', 'Thickness', 'SHAP'});
segments = table(strings(0, 1), zeros(0, 1), zeros(0, 1), zeros(0, 1), zeros(0, 1), zeros(0, 1), ...
    'VariableNames', {'Type', 'StartThickness', 'EndThickness', 'StartSHAP', 'EndSHAP', 'Slope'});
for kind = ["極大", "極小"]
    points = extrema(extrema.Type == kind, :);
    if height(points) < 2, continue; end
    slopes = diff(points.SHAP) ./ diff(points.Thickness);
    segments = [segments; table(repmat(kind+"間", numel(slopes), 1), points.Thickness(1:end-1), points.Thickness(2:end), ...
        points.SHAP(1:end-1), points.SHAP(2:end), slopes, 'VariableNames', segments.Properties.VariableNames)]; %#ok<AGROW>
end
segments = sortrows(segments, {'StartThickness', 'Type'});
end
