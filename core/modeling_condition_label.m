function label=modeling_condition_label(condition)
% 画面の一覧・グラフに出す学習条件の名前。
% ハイパーパラメータを持つ方式は、主な値（hyperparameter_specs の Short を持つ項目）を後ろに付ける。
% 探索する条件は、探索の方式を後ろに付ける（採用した値は結果の表で確認する）。
label=condition.Kernel;
if ~isfield(condition,'Regressor'), return; end
names=struct('linear','重回帰','forest','ランダムフォレスト','bagging','バギング木','ebm','EBM', ...
    'xgboost','XGBoost','lightgbm','LightGBM','catboost','CatBoost');
switch condition.Regressor
    case 'gpr'
        % Pro 版の加法カーネル・質的変数の GPR は、方式の名前で表す。
        categorical=isfield(condition,'Categorical') && ~isempty(condition.Categorical) && any(condition.Categorical.Mask);
        if strcmp(condition.Kernel,'additive') || categorical
            label=ProcessRegressionModel.proGprLabel(strcmp(condition.Kernel,'additive'),categorical);
        end
        return;
    case 'linear', label=names.linear; return;
    case 'pls', label=sprintf('PLS（%d成分）',condition.Components); return;
end
label=names.(condition.Regressor);
if isfield(condition,'Search') && ~isempty(condition.Search)
    modes=struct('grid','グリッドサーチ','random','ランダムサーチ');
    label=sprintf('%s（%s）',label,modes.(condition.Search.Mode)); return;
end
values=struct();
if isfield(condition,'Parameters') && ~isempty(condition.Parameters), values=condition.Parameters; end
if ismember(condition.Regressor,{'forest','bagging'}) && ~isfield(values,'NumTrees')
    trees=ProcessRegressionModel.DEFAULT_TREES; if isfield(condition,'Trees'), trees=condition.Trees; end
    values.NumTrees=trees;
end
specs=hyperparameter_specs(condition.Regressor); parts={};
for index=1:numel(specs)
    spec=specs(index);
    if isempty(spec.Short), continue; end
    value=spec.Default; if isfield(values,spec.Name), value=values.(spec.Name); end
    if ismember(spec.Short,{'本','回'}), parts{end+1}=sprintf('%g%s',value,spec.Short); %#ok<AGROW>
    else, parts{end+1}=sprintf('%s%g',spec.Short,value); end %#ok<AGROW>
end
label=sprintf('%s（%s）',label,strjoin(parts,'・'));
end
