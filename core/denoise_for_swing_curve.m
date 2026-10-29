function [shap_resist, shap_obj, shap_all] = denoise_for_swing_curve(Train_Model, X_for_shap, RESIST_for_shap)
require_r2025b();
validate_numeric_data(X_for_shap, 'X_for_shap', 'denoise_for_swing_curve');
validate_numeric_data(RESIST_for_shap, 'RESIST_for_shap', 'denoise_for_swing_curve');
if size(X_for_shap, 2) ~= 3 || size(RESIST_for_shap, 2) ~= 1 || ...
        size(X_for_shap, 1) ~= size(RESIST_for_shap, 1)
    error('denoise_for_swing_curve:shape', 'X は N×3、RESIST は同じ行数の N×1 としてください。');
end
constants = model_constants();
if ~istable(Train_Model.X) || ~isequal(Train_Model.PredictorNames, constants.PREDICTOR_NAMES)
    error('denoise_for_swing_curve:predictorNames', 'モデルの説明変数名・列順がSwing Curve仕様と一致しません。');
end
all_X_for_shap = array2table([X_for_shap, RESIST_for_shap], ...
    'VariableNames', constants.PREDICTOR_NAMES);
% TODO(要確認 Q-08) ノイズ除去用 SHAP では NumObservationsToSample を指定しない。
shap_obj = shapley(Train_Model,"QueryPoints", all_X_for_shap);
shap_all = shap_obj.Shapley.Value';
shap_resist = shap_all(:, end);
end
