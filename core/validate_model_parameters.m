function validate_model_parameters(kernel, fit_method, identifier)
constants = model_constants();
if ~isTextScalar(kernel) || ~any(strcmpi(kernel, constants.KERNELS))
    error([identifier ':invalidKernel'], 'kernel の有効値: %s', ...
        strjoin(constants.KERNELS, ', '));
end
if ~isTextScalar(fit_method) || ~any(strcmpi(fit_method, constants.FIT_METHODS))
    error([identifier ':invalidFitMethod'], 'fit_method の有効値: %s', ...
        strjoin(constants.FIT_METHODS, ', '));
end
end

function valid = isTextScalar(value)
valid = (ischar(value) && isrow(value)) || ...
    (isstring(value) && isscalar(value) && ~ismissing(value));
end
