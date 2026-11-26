function matrix = model_input_matrix(source, mapping, model)
% 推定に使う入力の行列。mapping は {順序, モデルの変数名, 入力ファイルの列}。
% 質的変数を持つモデル（Pro 版）では、その列を学習時の水準の一覧で番号に置き換える（学習時になかった値は止める）。
[categorical, levels] = categorical_info(model, size(mapping, 1));
matrix = zeros(size(source.Cells, 1), size(mapping, 1));
if any(~categorical)
    matrix(:, ~categorical) = assign_required_columns(source, mapping(~categorical, 2), mapping(~categorical, 3));
end
if any(categorical) && numel(unique(mapping(:, 3))) ~= size(mapping, 1)
    error('extract_numeric_columns:duplicateColumns', '同じ入力列が複数の変数に割り当てられています。');
end
for column = find(categorical)
    matrix(:, column) = encode_categories(source, mapping{column, 3}, levels{column});
end
end

function [mask, levels] = categorical_info(model, count)
mask = false(1, count); levels = cell(1, count);
if isa(model, 'ProcessRegressionModel'), [mask, levels] = model.categoricalInfo(); end
end
