function [shap_resist, explainer, values] = approximate_denoise_for_check(model, other_inputs, resist)
% 動作確認専用。ノイズ除去用SHAPの画面の流れだけを、代替SHAPで確認する。
[explainer, values] = approximate_shap_for_check(model, [other_inputs, resist]);
shap_resist = values(:, end);
end
