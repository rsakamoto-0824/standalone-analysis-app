function report = compare_models(oldMatPath, newMatPath, Xcheck)
old_model = load_train_model(oldMatPath);
new_model = load_train_model(newMatPath);
old_variables = whos('-file', oldMatPath);
new_variables = whos('-file', newMatPath);
old_names = {old_variables.name};
new_names = {new_variables.name};
items = {'変数名'; 'クラス'; 'PredictorNames'; 'ResponseName'; ...
    'KernelFunction'; 'FitMethod'; 'BasisFunction'; 'NumObservations'};
old_values = {strjoin(old_names, ', '); class(old_model); ...
    strjoin(old_model.PredictorNames, ', '); old_model.ResponseName; ...
    model_kernel_name(old_model.KernelFunction); old_model.FitMethod; old_model.BasisFunction; num2str(old_model.NumObservations)};
new_values = {strjoin(new_names, ', '); class(new_model); ...
    strjoin(new_model.PredictorNames, ', '); new_model.ResponseName; ...
    model_kernel_name(new_model.KernelFunction); new_model.FitMethod; new_model.BasisFunction; num2str(new_model.NumObservations)};
old_periodic = swing_kernel_info(old_model.KernelFunction); new_periodic = swing_kernel_info(new_model.KernelFunction);
if ~isempty(old_periodic) || ~isempty(new_periodic)
    old_period = NaN; new_period = NaN;
    if ~isempty(old_periodic), old_period = old_periodic.Period; end
    if ~isempty(new_periodic), new_period = new_periodic.Period; end
    items{end + 1, 1} = '周期（入力の膜厚単位）';
    old_values{end + 1, 1} = num2str(old_period, 17); new_values{end + 1, 1} = num2str(new_period, 17);
end
passed = cellfun(@isequal, old_values, new_values);
passed(1) = isequal(old_names, {'Train_Model'}) && isequal(new_names, {'Train_Model'});
old_prediction = predict(old_model, format_model_input(old_model, Xcheck));
new_prediction = predict(new_model, format_model_input(new_model, Xcheck));
report = struct('Checks', table(items, old_values, new_values, passed, ...
    'VariableNames', {'Item', 'Old', 'New', 'Passed'}), ...
    'MaxPredictionDifference', max(abs(old_prediction - new_prediction)), ...
    'PredictionsExactlyEqual', isequal(old_prediction, new_prediction));
disp(report.Checks);
fprintf('予測差の最大値: %.17g\n', report.MaxPredictionDifference);
fprintf('予測の完全一致 (isequal): %d\n', report.PredictionsExactlyEqual);
end
