function design = create_D_DOE(nfactors, nruns, seed)
validateattributes(nfactors, {'numeric'}, {'scalar', 'integer', 'positive', 'finite'}, mfilename, 'nfactors');
validateattributes(nruns, {'numeric'}, {'scalar', 'integer', 'positive', 'finite'}, mfilename, 'nruns');
require_r2025b();
if nargin < 3 || isempty(seed)
    rng('shuffle');
else
    validateattributes(seed, {'numeric'}, {'scalar', 'integer', 'nonnegative', '<=', 2^32 - 1}, mfilename, 'seed');
    rng(seed);
end
design = cordexch(nfactors, nruns, "quadratic");
end
