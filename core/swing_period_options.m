function options = swing_period_options(wavelength, refractive_index, bounds)
if nargin < 1, wavelength = 248; end
if nargin < 2, refractive_index = 1.77; end
if nargin < 3, bounds = []; end
validateattributes(wavelength, {'numeric'}, {'scalar', 'real', 'finite', 'positive'});
validateattributes(refractive_index, {'numeric'}, {'scalar', 'real', 'finite', 'positive'});
reference = wavelength / refractive_index;
if isempty(bounds), bounds = reference * [0.75, 1.25]; end
validateattributes(bounds, {'numeric'}, {'vector', 'numel', 2, 'real', 'finite', 'positive'});
bounds = double(bounds(:)');
if bounds(1) >= bounds(2), error('swing_period_options:bounds', '周期下限は上限より小さくしてください。'); end
options = struct('Wavelength', wavelength, 'RefractiveIndex', refractive_index, ...
    'ReferencePeriod', reference, 'PeriodBounds', bounds);
end
