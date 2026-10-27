function kl = calc_kl_divergence(p_data, q_data, n_bins)
constants = model_constants();
validate_numeric_data(p_data, 'p_data', mfilename);
validate_numeric_data(q_data, 'q_data', mfilename);
if numel(p_data) < 2 || numel(q_data) < 2
    error('calc_kl_divergence:tooFewRows', 'p_data・q_data は各2点以上必要です。');
end
if nargin < 3 || isempty(n_bins)
    n_bins = max(ceil(log2(numel(p_data)) + 1), constants.MIN_BINS);
end
validate_bin_count(n_bins, mfilename);
p_data = p_data(:);
q_data = q_data(:);
all_data = [p_data; q_data];
if min(all_data) == max(all_data)
    error('calc_kl_divergence:constantData', '全データが同一値のためビン分割できません。');
end
edges = linspace(min(all_data), max(all_data), n_bins + 1);
p_counts = histcounts(p_data, edges)' + 1;
q_counts = histcounts(q_data, edges)' + 1;
p_dist = p_counts / sum(p_counts);
q_dist = q_counts / sum(q_counts);
kl = sum(p_dist .* log(p_dist ./ q_dist));
end
