function validate_bin_count(n_bins, identifier)
if ~isnumeric(n_bins) || ~isreal(n_bins) || ~isscalar(n_bins) || ...
        ~isfinite(n_bins) || n_bins < 2 || n_bins ~= fix(n_bins)
    error([identifier ':invalidBins'], 'n_bins は 2 以上の整数としてください。');
end
end
