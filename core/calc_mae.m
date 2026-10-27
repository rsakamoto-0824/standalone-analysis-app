function value = calc_mae(y_true, y_pred)
[y_true, y_pred] = metric_inputs(y_true, y_pred, 1, mfilename);
value = mean(abs(y_true - y_pred));
end
