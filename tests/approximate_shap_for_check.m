function [explainer, values] = approximate_shap_for_check(model, inputs)
% 動作確認専用の代替SHAP。R2025b以外では shapley の複数行計算を使えないため、
% 「その列だけ学習データの平均に置き換えたときの予測差」で画面の流れだけを確認する。
% 実際のSHAP値ではないので、解析には使用しない。
explainer = [];
reference = model.X; if istable(reference), reference = table2array(reference); end
center = mean(reference, 1);
% 質的変数（Pro 版の GPR）の列は水準の番号のため、平均ではなく最も多い水準に置き換える。
if isa(model, 'ProcessRegressionModel')
    for column = find(model.categoricalInfo()), center(column) = mode(reference(:, column)); end
end
baseline = predict(model, format_model_input(model, inputs));
values = zeros(size(inputs));
for column = 1:size(inputs, 2)
    replaced = inputs; replaced(:, column) = center(column);
    values(:, column) = baseline - predict(model, format_model_input(model, replaced));
end
end
