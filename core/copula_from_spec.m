function model = copula_from_spec(names, marginals, dependence, measure, family)
% データを使わずに、指定した周辺分布と順位相関でコピュラのモデルを作る（Pro 版）。
%   marginals ：変数ごとの struct('Code', makedist の名前, 'Parameters', 数値ベクトル)
%   dependence：変数どうしの順位相関の行列（対角は1）。measure は 'kendall'（Kendall τ）または 'spearman'（Spearman ρ）
%   family    ：'Gaussian'・'t'（相関の行列で指定）、'Clayton'・'Frank'・'Gumbel'（2変数だけ。τ から決める）
% t コピュラの自由度は 5（裾の同時の動きを表す既定値）。
T_DEGREES = 5;
count = numel(names);
if count < 2, error('copula:columns', '変数は2つ以上にしてください。'); end
if numel(marginals) ~= count || ~isequal(size(dependence), [count, count]), error('copula:shape', '変数・周辺分布・相関の行列の大きさをそろえてください。'); end
dependence = double(dependence);
off_diagonal = ~eye(count);
if any(~isfinite(dependence(:))) || any(abs(dependence(off_diagonal)) >= 1) || any(abs(diag(dependence) - 1) > 1e-12)
    error('copula:dependence', '順位相関は −1 より大きく 1 より小さい値にし、対角は1にしてください。');
end
if max(max(abs(dependence - dependence'))) > 1e-12, error('copula:symmetric', '順位相関の行列は対称にしてください（i 行 j 列と j 行 i 列を同じ値に）。'); end
info = copula_families(); row = info.Families(strcmp({info.Families.Code}, family));
if isempty(row), error('copula:family', 'コピュラの種類が正しくありません: %s', family); end
if row.Bivariate && count ~= 2, error('copula:bivariate', '%s は2変数だけで使えます。3変数以上はガウスか t コピュラを選んでください。', row.Name); end
model = struct('Source', 'spec', 'Family', family, 'Names', {cellstr(string(names(:)'))}, 'Rho', [], 'Nu', [], 'Alpha', [], ...
    'Marginals', {cell(1, count)}, 'MarginalCode', 'spec', 'Original', [], 'Target', dependence, 'Measure', measure);
infeasible = '指定した順位相関の組み合わせは実現できません（相関の行列が正定値になりません）。値の組み合わせを見直してください。';
switch family
    case 'Gaussian'
        try
            model.Rho = copulaparam('Gaussian', dependence, 'type', measure);
        catch
            error('copula:positiveDefinite', infeasible);
        end
    case 't'
        if strcmp(measure, 'spearman'), error('copula:measure', 't コピュラは Kendall τ で指定してください。'); end
        try
            model.Rho = copulaparam('t', dependence, T_DEGREES, 'type', 'kendall');
        catch
            error('copula:positiveDefinite', infeasible);
        end
        model.Nu = T_DEGREES;
    otherwise
        if strcmp(measure, 'spearman'), error('copula:measure', '%s は Kendall τ で指定してください。', row.Name); end
        tau = dependence(1, 2);
        if strcmp(family, 'Clayton') && tau <= 0 || strcmp(family, 'Gumbel') && tau < 0
            error('copula:negative', '%s は正の関係（τ > 0）だけを表せます。負の関係はガウス・t・Frank を選んでください。', row.Name);
        end
        model.Alpha = copulaparam(family, tau, 'type', 'kendall');
end
if ~isempty(model.Rho)
    [~, failure] = chol(model.Rho);
    if failure, error('copula:positiveDefinite', infeasible); end
end
for column = 1:count
    spec = marginals{column}; parameters = num2cell(double(spec.Parameters(:)'));
    names_list = info.SpecMarginals(strcmp({info.SpecMarginals.Code}, spec.Code)).Parameters;
    if numel(parameters) ~= numel(names_list), error('copula:parameters', '変数「%s」の分布のパラメータは %d 個です。', model.Names{column}, numel(names_list)); end
    arguments = [names_list; parameters];
    try
        model.Marginals{column} = struct('Kind', 'distribution', 'Distribution', makedist(spec.Code, arguments{:}));
    catch err
        error('copula:marginal', '変数「%s」の分布のパラメータが正しくありません: %s', model.Names{column}, err.message);
    end
end
end
