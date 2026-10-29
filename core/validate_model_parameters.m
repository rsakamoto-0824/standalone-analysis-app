function validate_model_parameters(kernel, fit_method, identifier, allow_swing)
if nargin < 4, allow_swing = false; end
constants = model_constants();
allowed = constants.KERNELS;
if allow_swing, allowed = constants.SWING_KERNELS; end
if ~isTextScalar(kernel) || ~any(strcmpi(kernel, allowed))
    error([identifier ':invalidKernel'], 'kernel の有効値: %s', ...
        strjoin(allowed, ', '));
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
