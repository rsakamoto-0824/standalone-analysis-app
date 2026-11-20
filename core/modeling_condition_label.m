function label=modeling_condition_label(condition)
label=condition.Kernel;
if ~isfield(condition,'Regressor'), return; end
trees=ProcessRegressionModel.DEFAULT_TREES;
if isfield(condition,'Trees'), trees=condition.Trees; end
switch condition.Regressor
    case 'linear', label='重回帰';
    case 'pls', label=sprintf('PLS（%d成分）',condition.Components);
    case 'forest', label=sprintf('ランダムフォレスト（%d本）',trees);
    case 'bagging', label=sprintf('バギング木（%d本）',trees);
end
end
