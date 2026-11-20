function K = mixed_gpr_kernel(XN, XM, theta, categorical, additive)
% Pro 版の GPR のカーネル（fitrgp の KernelFunction に渡す）。categorical は質的変数の列（論理ベクトル）。
% 連続の列は二乗指数（列ごとの長さ尺度）、質的変数の列は「同じ水準なら1、違えば ρ」（0<ρ<1、列ごと）で表す。
%   additive = false：K = σ² × exp(−½Σ((x−x')/ℓ)²) × Π(ρ + (1−ρ)[a=b])
%       theta = [log ℓ（連続の列）, log σ, logit ρ（質的の列）]
%   additive = true ：K = Σ σ_c² exp(−½((x_c−x_c')/ℓ_c)²) + Σ σ_q² (ρ_q + (1−ρ_q)[a=b])（各列の効果の和＝加法カーネル）
%       theta = [log ℓ（連続の列）, log σ（連続の列）, log σ（質的の列）, logit ρ（質的の列）]
continuous = find(~categorical); qualitative = find(categorical);
C = numel(continuous); Q = numel(qualitative);
if ~additive
    lengths = exp(theta(1:C)); sigma = exp(theta(C + 1)); rho = 1 ./ (1 + exp(-theta(C + 2:C + 1 + Q)));
    K = sigma^2 * ones(size(XN, 1), size(XM, 1));
    if C > 0, K = K .* exp(-0.5 * pdist2(XN(:, continuous) ./ lengths(:)', XM(:, continuous) ./ lengths(:)').^2); end
    for index = 1:Q
        same = XN(:, qualitative(index)) == XM(:, qualitative(index))';
        K = K .* (rho(index) + (1 - rho(index)) * same);
    end
else
    lengths = exp(theta(1:C)); sigma_c = exp(theta(C + 1:2 * C));
    sigma_q = exp(theta(2 * C + 1:2 * C + Q)); rho = 1 ./ (1 + exp(-theta(2 * C + Q + 1:2 * C + 2 * Q)));
    K = zeros(size(XN, 1), size(XM, 1));
    for index = 1:C
        column = continuous(index);
        K = K + sigma_c(index)^2 * exp(-0.5 * ((XN(:, column) - XM(:, column)') / lengths(index)).^2);
    end
    for index = 1:Q
        same = XN(:, qualitative(index)) == XM(:, qualitative(index))';
        K = K + sigma_q(index)^2 * (rho(index) + (1 - rho(index)) * same);
    end
end
end
