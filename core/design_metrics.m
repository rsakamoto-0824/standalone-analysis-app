function result = design_metrics(design, model)
% 実験計画の評価指標。選んだモデルの項（doe_model_matrix）で計算する。値は −1〜1 の符号化値が前提。
%   D効率 = 100 × |X'X|^(1/p) / n            （大きいほど係数をまとめて精度よく推定できる。直交計画で100%）
%   A効率 = 100 × p / (n × trace((X'X)^-1))   （大きいほど係数の分散の合計が小さい）
%   I基準 = trace(M (X'X)^-1)                 （[-1,1]^k 全体の平均予測分散。誤差分散 σ² を1とした値。小さいほど良い）
%   G効率 = 100 × p / (n × 最大予測分散)        （最大予測分散は3水準の格子点と計画点で評価）
% ほかに、条件数、最大VIF、項どうしの最大相関、残差の自由度を返す。
% result.Table は表示用の表、result.Values は数値（見出し用）、result.Variance は予測分散の分布（FDS）の値。
FDS_POINTS = 2000; GRID_LEVELS = [-1, 0, 1]; MAX_GRID_POINTS = 20000;
[matrix, ~, powers] = doe_model_matrix(design, model);
[runs, terms] = size(matrix); factors = size(design, 2);
values = struct('Runs', runs, 'Terms', terms, 'Rank', rank(matrix), 'DEfficiency', NaN, 'AEfficiency', NaN, ...
    'ICriterion', NaN, 'GEfficiency', NaN, 'MaxVariance', NaN, 'Condition', NaN, 'MaxVIF', NaN, 'MaxCorrelation', NaN, ...
    'ResidualDF', runs - terms);
variance = [];
if values.Rank == terms
    information = matrix' * matrix; inverse = information \ eye(terms);
    [upper, failure] = chol((information + information') / 2);
    if ~failure, values.DEfficiency = 100 * exp(2 * sum(log(diag(upper))) / terms) / runs; end
    values.AEfficiency = 100 * terms / (runs * trace(inverse));
    values.ICriterion = trace(doe_moment_matrix(powers) * inverse);
    % 最大予測分散：3水準の格子点（多すぎる場合は乱数の点）と計画点のうち最大の値。
    if numel(GRID_LEVELS)^factors <= MAX_GRID_POINTS
        grid_points = dec2base(0:numel(GRID_LEVELS)^factors - 1, numel(GRID_LEVELS), factors) - '0';
        grid_points = GRID_LEVELS(grid_points + 1);
        if factors == 1, grid_points = grid_points(:); end
    else
        grid_points = 2 * rand(RandStream('twister', 'Seed', 0), MAX_GRID_POINTS, factors) - 1;
    end
    candidates = doe_model_matrix([grid_points; design], model);
    values.MaxVariance = max(sum((candidates * inverse) .* candidates, 2));
    values.GEfficiency = 100 * terms / (runs * values.MaxVariance);
    values.Condition = cond(information);
    % 予測分散の分布（FDS：領域のうち予測分散がその値以下の割合）。乱数の点は固定 seed で毎回同じにする。
    points = 2 * rand(RandStream('twister', 'Seed', 0), FDS_POINTS, factors) - 1;
    sample = doe_model_matrix(points, model); variance = sort(sum((sample * inverse) .* sample, 2));
end
if terms > 2
    others = matrix(:, 2:end); spread = std(others, 0, 1);
    if all(spread > 0)
        correlation = corrcoef(others); off_diagonal = abs(correlation - eye(size(correlation)));
        values.MaxCorrelation = max(off_diagonal(:));
        if rcond(correlation) > 1e-12, values.MaxVIF = max(diag(inv(correlation))); else, values.MaxVIF = Inf; end
    else
        values.MaxCorrelation = NaN; values.MaxVIF = Inf;
    end
elseif terms == 2
    values.MaxVIF = 1; values.MaxCorrelation = 0;
end
names = ["D効率（%）"; "A効率（%）"; "I基準（平均予測分散）"; "G効率（%）"; "最大予測分散"; "条件数（X'X）"; ...
    "最大VIF"; "項どうしの最大相関 |r|"; "残差の自由度"; "実験数"; "モデルの項数"];
numbers = [values.DEfficiency; values.AEfficiency; values.ICriterion; values.GEfficiency; values.MaxVariance; values.Condition; ...
    values.MaxVIF; values.MaxCorrelation; values.ResidualDF; runs; terms];
guides = ["大きいほど係数をまとめて精度よく推定できます（D最適の基準。直交計画で100%）。"; ...
    "大きいほど係数の分散の合計が小さくなります。"; ...
    "小さいほど領域全体で予測が安定します（I最適の基準。誤差分散を1とした値）。"; ...
    "大きいほど、最も予測が悪い点の予測分散が小さくなります。"; ...
    "領域内で最も大きい予測分散（3水準の格子点と計画点で評価）。"; ...
    "小さいほど係数の推定が安定します（1000を超えると不安定の目安）。"; ...
    "項どうしの重なり。1に近いほど独立で、10を超えると多重共線性が強い目安。"; ...
    "0に近いほど項どうしが独立です。"; ...
    "実験数 − 項数。0だと誤差の大きさを推定できません。"; ...
    "計画の行数。"; "選んだモデルの係数の数（切片を含む）。"];
if values.Rank < terms
    guides(1:6) = "ランク不足のため計算できません。";
end
result = struct('Table', table(names, numbers, guides, 'VariableNames', {'指標', '値', '目安'}), 'Values', values, 'Variance', variance);
end
