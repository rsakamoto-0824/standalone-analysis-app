function [model, warnings, details] = train_modeling_candidate(kind, inputs, response, names, condition, period_options, progress)
details = [];
% swingperiodic（周期カーネル）は Pro 版だけ。配布した通常版の exe では学習させない。
if isdeployed && ~strcmp(app_edition(), 'pro') && strcmpi(condition.Kernel, 'swingperiodic')
    error('modeling:proOnly', 'swingperiodic は Pro 版だけで使えるカーネルです。');
end
switch kind
    case 'apc', [model, warnings] = train_apc_model(inputs, response, false, condition.Kernel, condition.FitMethod);
    case 'swing', [model, warnings, details] = train_swing_gpr_model(inputs, response, names, condition.Kernel, condition.FitMethod, progress, period_options);
    case 'generic'
        if isfield(condition,'Regressor') && ~strcmp(condition.Regressor,'gpr')
            trees=ProcessRegressionModel.DEFAULT_TREES; if isfield(condition,'Trees'), trees=condition.Trees; end
            parameters=struct(); if isfield(condition,'Parameters') && ~isempty(condition.Parameters), parameters=condition.Parameters; end
            options=regressionOptions(condition);
            if isfield(condition,'Search') && ~isempty(condition.Search)
                % ハイパーパラメータの探索（Pro 版）。交差検証で候補を比べ、最も良い値で学習し直す。
                require_pro_feature('ハイパーパラメータの探索');
                [parameters, trace, searched] = search_hyperparameters(inputs, response, names, condition.Regressor, ...
                    condition.Components, parameters, condition.Search, progress, options);
                details = struct('SearchTrace', trace, 'SearchMode', condition.Search.Mode, 'SearchFolds', condition.Search.Folds, ...
                    'SearchParameters', searched, 'BestParameters', parameters);
            end
            model=ProcessRegressionModel(inputs,response,names,condition.Regressor,condition.Components,trees,parameters,options); warnings=strings(0,1);
        elseif strcmp(condition.Kernel, 'additive') || (isfield(condition, 'Categorical') && ~isempty(condition.Categorical) && any(condition.Categorical.Mask))
            % Pro 版：加法カーネル、または質的変数を含む GPR。
            options = struct('Additive', strcmp(condition.Kernel, 'additive'), 'FitMethod', condition.FitMethod, ...
                'Categorical', false(1, size(inputs, 2)), 'Levels', {cell(1, size(inputs, 2))});
            if isfield(condition, 'Categorical') && ~isempty(condition.Categorical)
                options.Categorical = condition.Categorical.Mask; options.Levels = condition.Categorical.Levels;
            end
            model = ProcessRegressionModel(inputs, response, names, 'gpr_pro', 2, [], options); warnings = strings(0, 1);
        else
            [model, warnings] = train_generic_gpr_model(inputs, response, condition.Kernel, condition.FitMethod);
        end
    otherwise, error('modeling:kind', 'APC・Swing Curve・汎用回帰を指定してください。');
end
end

function options = regressionOptions(condition)
% GPR 以外の方式へ渡す、質的変数・損失関数・CatBoost の並べ替え。
options = struct();
if isfield(condition, 'Categorical') && ~isempty(condition.Categorical)
    options.Categorical = condition.Categorical.Mask; options.Levels = condition.Categorical.Levels;
end
if isfield(condition, 'Loss') && ~isempty(condition.Loss)
    options.Loss = condition.Loss.Type; options.Quantile = condition.Loss.Quantile;
end
if isfield(condition, 'Order') && ~isempty(condition.Order), options.Order = condition.Order; end
end
