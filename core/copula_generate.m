function samples = copula_generate(model, count, seed)
% コピュラのモデルから count 行の乱数を作る。コピュラで 0〜1 の一様な値を作り、各列の周辺分布の逆関数で元の尺度へ戻す。
% 乱数はこの計算の間だけ seed で固定し、終わったら元に戻す（同じ seed なら同じ乱数になる）。
validateattributes(count, {'numeric'}, {'scalar', 'integer', '>=', 1, '<=', 1e6});
previous = rng; restore = onCleanup(@() rng(previous)); rng(seed, 'twister');
switch model.Family
    case 'Gaussian', uniform = copularnd('Gaussian', model.Rho, count);
    case 't', uniform = copularnd('t', model.Rho, model.Nu, count);
    otherwise, uniform = copularnd(model.Family, model.Alpha, count);
end
% カーネル密度の逆関数は、分布の端で収束の警告を出すことがある（値は端の近くの値になる）。この計算の間だけ警告を止める。
warnings = warning('off', 'all'); restore_warnings = onCleanup(@() warning(warnings));
samples = zeros(count, numel(model.Marginals));
for column = 1:numel(model.Marginals)
    marginal = model.Marginals{column};
    if strcmp(marginal.Kind, 'empirical')
        data = marginal.Data(:); positions = linspace(0, 1, numel(data))';
        samples(:, column) = interp1(positions, data, uniform(:, column));
    else
        samples(:, column) = icdf(marginal.Distribution, uniform(:, column));
    end
end
end
