function r2 = calc_r_squared(y_true, y_pred)
[y_true, y_pred] = metric_inputs(y_true, y_pred, 2, mfilename);
C = corrcoef(y_true, y_pred);
r2 = C(1,2)^2;
end
