function [shap_obj, shap_all] = calc_shap_dependence(Train_Model, X)
Xnew = format_model_input(Train_Model, X);
[shap_obj, shap_all] = compute_shap_values(Train_Model, Xnew);
end
