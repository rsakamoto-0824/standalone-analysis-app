function [shap_resist, shap_obj, shap_all] = denoise_for_swing_curve(Train_Model, X_for_shap, RESIST_for_shap)
require_r2025b();
if size(X_for_shap, 2) > 0, validate_numeric_data(X_for_shap, 'X_for_shap', 'denoise_for_swing_curve'); end
validate_numeric_data(RESIST_for_shap, 'RESIST_for_shap', 'denoise_for_swing_curve');
if ~isnumeric(X_for_shap) || ~ismatrix(X_for_shap) || size(RESIST_for_shap, 2) ~= 1 || ...
        size(X_for_shap, 1) ~= size(RESIST_for_shap, 1)
    error('denoise_for_swing_curve:shape', '追加の説明変数とRESISTは同じ行数にしてください。追加の説明変数は0列でも使用できます。');
end
names = Train_Model.PredictorNames;
if ~istable(Train_Model.X) || numel(names) ~= size(X_for_shap, 2) + 1 || ~strcmp(names{end}, 'RESIST_TH')
    error('denoise_for_swing_curve:predictorNames', 'モデルの説明変数名・列順がSwing Curve仕様と一致しません。');
end
all_X_for_shap = array2table([X_for_shap, RESIST_for_shap], ...
    'VariableNames', names);
% TODO(要確認 Q-08) ノイズ除去用 SHAP では NumObservationsToSample を指定しない。
shap_obj = shapley(Train_Model,"QueryPoints", all_X_for_shap);
shap_all = shap_obj.Shapley.Value';
shap_resist = shap_all(:, end);
end
