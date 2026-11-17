function options = swing_period_options(wavelength, refractive_index, bounds)
% Swing Curve の周期の基準と探索範囲。
% レジスト膜内の定在波は、膜厚が λ/(2n) 変わるごとに同じ干渉条件へ戻るため、
% 基準周期 = 露光波長 ÷ レジスト屈折率 ÷ 2 とする（既定 248 ÷ 1.77 ÷ 2 ≒ 70.06 nm）。
% 範囲を指定しない場合は、基準周期の75〜125%を探索する。
DEFAULT_WAVELENGTH = 248; DEFAULT_REFRACTIVE_INDEX = 1.77;
STANDING_WAVE_DIVISOR = 2; DEFAULT_RANGE = [0.75, 1.25];
if nargin < 1, wavelength = DEFAULT_WAVELENGTH; end
if nargin < 2, refractive_index = DEFAULT_REFRACTIVE_INDEX; end
if nargin < 3, bounds = []; end
validateattributes(wavelength, {'numeric'}, {'scalar', 'real', 'finite', 'positive'});
validateattributes(refractive_index, {'numeric'}, {'scalar', 'real', 'finite', 'positive'});
reference = wavelength / refractive_index / STANDING_WAVE_DIVISOR;
if isempty(bounds), bounds = reference * DEFAULT_RANGE; end
validateattributes(bounds, {'numeric'}, {'vector', 'numel', 2, 'real', 'finite', 'positive'});
bounds = double(bounds(:)');
if bounds(1) >= bounds(2), error('swing_period_options:bounds', '周期下限は上限より小さくしてください。'); end
options = struct('Wavelength', wavelength, 'RefractiveIndex', refractive_index, ...
    'ReferencePeriod', reference, 'PeriodBounds', bounds);
end
