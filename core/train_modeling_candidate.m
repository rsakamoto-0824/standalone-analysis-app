function [model, warnings, details] = train_modeling_candidate(kind, inputs, response, names, condition, period_options, progress)
details = [];
switch kind
    case 'apc', [model, warnings] = train_apc_model(inputs, response, false, condition.Kernel, condition.FitMethod);
    case 'swing', [model, warnings, details] = train_swing_gpr_model(inputs, response, names, condition.Kernel, condition.FitMethod, progress, period_options);
    case 'generic', [model, warnings] = train_generic_gpr_model(inputs, response, condition.Kernel, condition.FitMethod);
    otherwise, error('modeling:kind', 'APC・Swing Curve・汎用GPRを指定してください。');
end
end
