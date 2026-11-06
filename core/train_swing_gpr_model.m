function [model, warnings, details] = train_swing_gpr_model(inputs, response, names, kernel, fit_method, progress, period_options)
if nargin < 6, progress = []; end
if nargin < 7, period_options = swing_period_options(); end
validate_numeric_data(inputs, '説明変数', mfilename);
validate_numeric_data(response, '目的変数', mfilename);
names = cellstr(string(names(:)'));
if ~isvector(response) || size(inputs, 1) ~= numel(response) || size(inputs, 2) ~= numel(names) || ...
        numel(unique(names)) ~= numel(names) || ~strcmp(names{end}, 'RESIST_TH')
    error('train_swing_gpr_model:shape', '1列以上の説明変数と同じ行数の目的変数を指定し、最後の説明変数をRESIST_THにしてください。');
end
validate_model_parameters(kernel, fit_method, mfilename, true);
require_r2025b();
details = [];
if strcmpi(kernel, 'swingperiodic')
    [model, warnings, details] = train_swing_periodic_model(inputs(:, 1:end-1), inputs(:, end), response, ...
        fit_method, progress, period_options, names);
else
    input_table = array2table(inputs, 'VariableNames', names);
    model = fitrgp(input_table, double(response(:)), 'KernelFunction', kernel, 'FitMethod', fit_method, 'Standardize', true);
    warnings = strings(0, 1);
end
end
