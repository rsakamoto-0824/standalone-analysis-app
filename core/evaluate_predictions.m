function metrics = evaluate_predictions(actual, predicted, bins)
if nargin < 3 || isequal(bins, 0), bins = []; end
[actual, predicted] = metric_inputs(actual, predicted, 2, mfilename);
names = ["R2"; "RMSE"; "RMSPE_percent"; "MAE"; "Pearson_r"; ...
    "Correlation_squared"; "KL_nats"; "Mutual_information_bits"];
values = NaN(8, 1); notes = strings(8, 1);
denominator = sum((actual - mean(actual)).^2);
if denominator > 0
    values(1) = 1 - sum((actual - predicted).^2) / denominator;
else
    notes(1) = "実測値が一定のため定義できません";
end
calculators = {@() calc_rmse(actual, predicted), @() calc_rmspe(actual, predicted), ...
    @() calc_mae(actual, predicted), @() calc_pearson(actual, predicted), ...
    @() calc_r_squared(actual, predicted), @() calc_kl_divergence(actual, predicted, bins), ...
    @() calc_mutual_information(actual, predicted, bins)};
for index = 1:numel(calculators)
    try
        values(index + 1) = calculators{index}();
        if ~isfinite(values(index + 1)), notes(index + 1) = "定数列などのため定義できません"; end
    catch err
        if any(strcmp(err.identifier, {'calc_rmspe:zeroTrueValue', 'calc_kl_divergence:constantData'}))
            notes(index + 1) = string(err.message);
        else
            rethrow(err);
        end
    end
end
metrics = table(names, values, notes, 'VariableNames', {'Metric', 'Value', 'Note'});
end
