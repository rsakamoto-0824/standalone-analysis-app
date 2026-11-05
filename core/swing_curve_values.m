function values = swing_curve_values(fit, thickness)
if isfield(fit, 'Method') && strcmp(fit.Method, 'spline')
    values = ppval(fit.PP, (thickness - fit.Center) / fit.Scale); return;
end
offset = thickness - fit.Center;
angle = 2 * pi * offset / fit.Period;
values = fit.Offset + fit.Slope * offset + fit.SinCoefficient * sin(angle) + fit.CosCoefficient * cos(angle);
end
