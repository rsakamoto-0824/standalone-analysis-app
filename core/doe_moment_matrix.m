function moments = doe_moment_matrix(powers)
% 一様分布 [-1,1]^k でのモデル項の積の平均（I基準の積分モーメント）。
% 各因子の x^m の平均は、m が奇数なら0、偶数なら 1/(m+1)。数値積分の誤差を持ち込まないよう厳密に計算する。
term_count = size(powers, 1); moments = zeros(term_count);
for row = 1:term_count
    combined = powers(row, :) + powers;
    moments(row, :) = (prod(1 ./ (combined + 1), 2) .* all(mod(combined, 2) == 0, 2))';
end
end
