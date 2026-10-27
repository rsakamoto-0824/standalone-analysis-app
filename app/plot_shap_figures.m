function figures = plot_shap_figures(shap_obj, shap_all, predictor_names)
importance = mean(abs(shap_all), 1);
[~, order] = sort(importance, 'descend');
sorted_names = predictor_names(order);
N_FACTORS = numel(sorted_names);
figures = cell(N_FACTORS + 1, 1);
figures{1} = figure('Name', 'SHAP 分布', 'Color', 'white');
swarmchart(shap_obj);
for i = 1:N_FACTORS
    feat_name = sorted_names{i};
    figures{i + 1} = figure('Name', ['SHAP 依存: ' feat_name], 'Color', 'white');
    other_ranks = setdiff(1:N_FACTORS, i);
    if isempty(other_ranks)
        plotDependence(shap_obj, feat_name);
    else
        color_name = sorted_names{other_ranks(1)};
        plotDependence(shap_obj, feat_name, "ColorPredictor", color_name);
    end
end
end
