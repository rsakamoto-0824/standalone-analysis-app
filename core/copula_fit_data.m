function model = copula_fit_data(values, names, family, marginal)
% データの列どうしの関係（順位の関係）をコピュラで、各列の分布を周辺分布で当てはめる（Pro 版）。
% 関係は順位だけで決まるため、各列を (順位)/(行数+1) にそろえた値（疑似観測値）に copulafit を当てはめる。
%   family   ：'Gaussian'・'t'・'Clayton'・'Frank'・'Gumbel'（Clayton・Frank・Gumbel は2列だけ）
%   marginal ：'empirical'（経験分布の分位点。データの範囲の外の値は出ない）または fitdist の分布名（'Kernel' など）
validate_numeric_data(values, '列', mfilename);
[rows, count] = size(values);
if count < 2, error('copula:columns', '2列以上を選んでください。'); end
if rows < 10, error('copula:rows', 'コピュラの当てはめには10行以上が必要です（現在 %d行）。', rows); end
info = copula_families(); row = info.Families(strcmp({info.Families.Code}, family));
if isempty(row), error('copula:family', 'コピュラの種類が正しくありません: %s', family); end
if row.Bivariate && count ~= 2, error('copula:bivariate', '%s は2列だけで使えます（現在 %d列）。3列以上はガウスか t コピュラを選んでください。', row.Name, count); end
if any(std(values, 0, 1) == 0), error('copula:constant', '値が一定の列は使えません。'); end
pseudo = zeros(rows, count);
for column = 1:count, pseudo(:, column) = tiedrank(values(:, column)) / (rows + 1); end
model = struct('Source', 'data', 'Family', family, 'Names', {cellstr(string(names(:)'))}, 'Rho', [], 'Nu', [], 'Alpha', [], ...
    'Marginals', {cell(1, count)}, 'MarginalCode', marginal, 'Original', values);
switch family
    case 'Gaussian', model.Rho = copulafit('Gaussian', pseudo);
    case 't', [model.Rho, model.Nu] = copulafit('t', pseudo, 'Method', 'ApproximateML');
    otherwise, model.Alpha = copulafit(family, pseudo);
end
for column = 1:count
    x = values(:, column);
    if strcmp(marginal, 'empirical')
        model.Marginals{column} = struct('Kind', 'empirical', 'Data', sort(x));
    else
        if ismember(marginal, {'Lognormal', 'Weibull', 'Gamma'}) && any(x <= 0)
            error('copula:positive', '列「%s」に0以下の値があるため、この周辺分布は使えません。経験分布・カーネル密度・正規分布を選んでください。', model.Names{column});
        end
        model.Marginals{column} = struct('Kind', 'distribution', 'Distribution', fitdist(x, marginal));
    end
end
end
