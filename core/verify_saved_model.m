function report = verify_saved_model(fullName, Train_Model_before, model_type, expected)
% expected は画面で選択した設定と実際に使用した行数。省略時は保存前モデルと比較する。
constants = model_constants();
report = struct('Success', false, 'Checks', table(), 'PredictorNames', {{}}, ...
    'ResponseName', '', 'Message', constants.INVALID_MODEL_MESSAGE);
checks = cell(0, 4);
try
    if ~any(strcmp(model_type, constants.MODEL_TYPES))
        error('verify_saved_model:modelType', 'モデル種別が不正です。');
    end
    if nargin < 4
        expected = struct('KernelFunction', Train_Model_before.KernelFunction, ...
            'FitMethod', Train_Model_before.FitMethod, ...
            'BasisFunction', Train_Model_before.BasisFunction, ...
            'NumObservations', size(Train_Model_before.X, 1));
    end
    variables = whos('-file', fullName);
    variable_names = {variables.name};
    checks(end + 1, :) = {'変数名', 'Train_Model のみ', strjoin(variable_names, ', '), ...
        isequal(variable_names, {'Train_Model'})};
    S = load(fullName, "Train_Model");
    if ~isfield(S, 'Train_Model')
        error('verify_saved_model:missingModel', '学習済みモデル（Train_Model）が見つかりません');
    end
    checks(end + 1, :) = {'クラス', 'RegressionGP', class(S.Train_Model), ...
        strcmp(class(S.Train_Model), 'RegressionGP')};
    if ~strcmp(class(S.Train_Model), 'RegressionGP')
        error('verify_saved_model:invalidClass', 'RegressionGP ではありません。');
    end
    wanted_names = Train_Model_before.PredictorNames;
    if any(strcmp(model_type, {'apc', 'swing'}))
        wanted_names = constants.PREDICTOR_NAMES;
    end
    report.PredictorNames = S.Train_Model.PredictorNames;
    report.ResponseName = S.Train_Model.ResponseName;
    checks(end + 1, :) = {'PredictorNames', strjoin(wanted_names, ', '), ...
        strjoin(S.Train_Model.PredictorNames, ', '), ...
        isequal(S.Train_Model.PredictorNames, wanted_names)};
    checks(end + 1, :) = {'ResponseName', Train_Model_before.ResponseName, ...
        S.Train_Model.ResponseName, isequal(S.Train_Model.ResponseName, Train_Model_before.ResponseName)};
    for field = {'KernelFunction', 'FitMethod', 'BasisFunction'}
        name = field{1};
        passed = strcmpi(S.Train_Model.(name), expected.(name)) && ...
            isequal(S.Train_Model.(name), Train_Model_before.(name));
        checks(end + 1, :) = {name, char(string(expected.(name))), ...
            char(string(S.Train_Model.(name))), passed};
    end
    checks(end + 1, :) = {'NumObservations', num2str(expected.NumObservations), ...
        num2str(S.Train_Model.NumObservations), ...
        S.Train_Model.NumObservations == expected.NumObservations && ...
        Train_Model_before.NumObservations == expected.NumObservations};
    before_prediction = predict(Train_Model_before, Train_Model_before.X);
    after_prediction = predict(S.Train_Model, Train_Model_before.X);
    checks(end + 1, :) = {'学習データの予測', 'isequal = true', ...
        mat2str(isequal(before_prediction, after_prediction)), ...
        isequal(before_prediction, after_prediction)};
catch err
    checks(end + 1, :) = {'検証処理', '正常終了', err.identifier, false};
end
report.Checks = cell2table(checks, 'VariableNames', {'Item', 'Expected', 'Actual', 'Passed'});
report.Success = ~isempty(checks) && all([checks{:, 4}]);
if report.Success, report.Message = '保存後の自動検証に成功しました。'; end
end
