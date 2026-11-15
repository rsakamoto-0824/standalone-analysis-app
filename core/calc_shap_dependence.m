function [shap_obj, shap_all] = calc_shap_dependence(Train_Model, X)
Xnew = format_model_input(Train_Model, X);
if isa(Train_Model,'ProcessRegressionModel')
    require_r2025b();
    background=array2table(Train_Model.X,'VariableNames',Train_Model.PredictorNames);
    query=array2table(Xnew,'VariableNames',Train_Model.PredictorNames);
    shap_obj=shapley(@(data)predict(Train_Model,data),background,'NumObservationsToSample','all','QueryPoints',query);
    shap_all=shap_obj.Shapley.Value'; return;
end
[shap_obj, shap_all] = compute_shap_values(Train_Model, Xnew);
end
