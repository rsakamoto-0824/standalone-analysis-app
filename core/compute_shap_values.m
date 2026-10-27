function [shap_obj, shap_all] = compute_shap_values(Train_Model, X_for_shap)
    require_r2025b();
    if ~license('test', 'Statistics_Toolbox')
        error('compute_shap_values:noToolbox', ...
            'SHAP 算出には Statistics and Machine Learning Toolbox が必要です。');
    end
    try
        shap_obj = shapley(Train_Model,"NumObservationsToSample","all","QueryPoints",X_for_shap);
        shap_tmpValue = shap_obj.Shapley;
        shap_all = shap_tmpValue.Value';
    catch err
        error('compute_shap_values:shapleyFailed', ...
            'SHAP 値の算出に失敗しました。\n詳細: %s', err.message);
    end
end
