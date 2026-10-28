function report = design_diagnostics(design, model)
[selected, selected_names] = doe_model_matrix(design, model);
[full, names] = doe_model_matrix(design, 'quadratic');
norms = sqrt(sum(full.^2, 1));
normalized = full ./ max(norms, eps);
similarity = abs(normalized' * normalized);
similarity(norms < eps, :) = NaN; similarity(:, norms < eps) = NaN;
dependencies = null(full);
report = struct('Similarity', similarity, 'Names', names, ...
    'Rank', rank(selected), 'Terms', size(selected, 2), 'FullRank', rank(full), ...
    'FullTerms', size(full, 2), 'Dependencies', dependencies, 'SelectedNames', selected_names);
end
