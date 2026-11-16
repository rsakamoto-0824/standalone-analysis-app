function [model, warnings, details] = train_modeling_candidate(kind, inputs, response, names, condition, period_options, progress)
details = [];
switch kind
    case 'apc', [model, warnings] = train_apc_model(inputs, response, false, condition.Kernel, condition.FitMethod);
    case 'swing', [model, warnings, details] = train_swing_gpr_model(inputs, response, names, condition.Kernel, condition.FitMethod, progress, period_options);
    case 'generic'
        if isfield(condition,'Regressor') && ~strcmp(condition.Regressor,'gpr')
            model=ProcessRegressionModel(inputs,response,names,condition.Regressor,condition.Components); warnings=strings(0,1);
        else
            [model, warnings] = train_generic_gpr_model(inputs, response, condition.Kernel, condition.FitMethod);
        end
    otherwise, error('modeling:kind', 'APC・Swing Curve・汎用回帰を指定してください。');
end
end
