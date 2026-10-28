function values = swing_curve_values(fit, thickness)
offset = thickness - fit.Center;
angle = 2 * pi * offset / fit.Period;
values = fit.Offset + fit.Slope * offset + fit.SinCoefficient * sin(angle) + fit.CosCoefficient * cos(angle);
end
