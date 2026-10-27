function mi = calc_mutual_information(x, y, n_bins)
constants = model_constants();
[x, y] = metric_inputs(x, y, 2, mfilename);
if nargin < 3 || isempty(n_bins)
    n_bins = max(ceil(log2(numel(x)) + 1), constants.MIN_BINS);
end
validate_bin_count(n_bins, mfilename);
edges_x = linspace(min(x), max(x), n_bins + 1);
edges_y = linspace(min(y), max(y), n_bins + 1);
joint_counts = histcounts2(x, y, edges_x, edges_y) + 1;
joint_prob = joint_counts / sum(joint_counts(:));
p_x = sum(joint_prob, 2);
p_y = sum(joint_prob, 1);
eps_val = constants.ENTROPY_EPSILON;
h_x = -sum(p_x(p_x > eps_val) .* log2(p_x(p_x > eps_val)));
h_y = -sum(p_y(p_y > eps_val) .* log2(p_y(p_y > eps_val)));
joint_flat = joint_prob(joint_prob > eps_val);
h_xy = -sum(joint_flat .* log2(joint_flat));
mi = max(h_x + h_y - h_xy, 0);
end
