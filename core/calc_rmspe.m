function value = calc_rmspe(y_true, y_pred)
[y_true, y_pred] = metric_inputs(y_true, y_pred, 1, mfilename);
if any(y_true == 0)
    error('calc_rmspe:zeroTrueValue', 'y_true に 0 が含まれるため RMSPE を算出できません。');
end
value = sqrt(mean(((y_true - y_pred) ./ y_true).^2)) * 100;
end
