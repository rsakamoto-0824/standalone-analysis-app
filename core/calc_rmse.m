function value = calc_rmse(y_true, y_pred)
[y_true, y_pred] = metric_inputs(y_true, y_pred, 1, mfilename);
value = sqrt(mean((y_true - y_pred).^2));
end
