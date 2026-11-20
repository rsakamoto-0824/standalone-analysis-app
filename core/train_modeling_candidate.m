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
            model=ProcessRegressionModel(inputs,response,names,condition.Regressor,condition.Components,trees); warnings=strings(0,1);
        else
            [model, warnings] = train_generic_gpr_model(inputs, response, condition.Kernel, condition.FitMethod);
        end
    otherwise, error('modeling:kind', 'APC・Swing Curve・汎用回帰を指定してください。');
end
end
