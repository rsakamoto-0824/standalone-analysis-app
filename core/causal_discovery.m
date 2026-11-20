function result = causal_discovery(values, names, method, options)
% 因果探索（Pro 版）。データの列どうしの因果の向きの候補を推定する。
%   'pc'      ：PC アルゴリズム。偏相関の検定（Fisher の z、有意水準 Alpha）で辺を外し、
%               V字構造と Meek の規則で向きを決める。向きの決まらない辺は無向（―）のまま残す。正規分布・線形を仮定。
%   'lingam'  ：DirectLiNGAM。誤差が正規分布でないことを使って因果の順序を決め、各変数を順序が前の変数へ回帰する
%               （係数は標準化した値。t 検定の p 値が Alpha 以上の辺は外す）。線形・非正規・未観測の交絡なしを仮定。
% options：Alpha（既定 0.05）、MaxConditioning（PC の条件づける変数の最大数。既定 3）。
% 戻り値：result.Adjacency（行→列の向き。両方向が1なら無向）、result.Edges（表）、result.Order（LiNGAM の順序）。
% 推定はあくまで仮説で、因果関係を証明するものではない。
if nargin < 4, options = struct(); end
alpha = 0.05; max_conditioning = 3;
if isfield(options, 'Alpha'), alpha = options.Alpha; end
if isfield(options, 'MaxConditioning'), max_conditioning = options.MaxConditioning; end
validate_numeric_data(values, '列', mfilename);
[rows, count] = size(values);
if count < 2, error('causal:columns', '2列以上を選んでください。'); end
if rows < count + 5, error('causal:rows', '因果探索には、列の数＋5行以上のデータが必要です（現在 %d行）。', rows); end
scale = std(values, 0, 1);
if any(scale == 0), error('causal:constant', '値が一定の列は使えません: %s', strjoin(cellstr(string(names(scale == 0))), ', ')); end
z = (values - mean(values, 1)) ./ scale;
switch method
    case 'pc', [adjacency, strength, order] = pcAlgorithm(z, alpha, max_conditioning);
    case 'lingam', [adjacency, strength, order] = directLingam(z, alpha);
    otherwise, error('causal:method', 'pc または lingam を指定してください。');
end
result.Adjacency = adjacency; result.Strength = strength; result.Order = order; result.Method = method;
result.Edges = edgeTable(adjacency, strength, names, method);
end

% ======================= PC アルゴリズム =======================
function [adjacency, strength, order] = pcAlgorithm(z, alpha, max_conditioning)
[rows, count] = size(z); correlation = corrcoef(z);
adjacent = true(count) & ~eye(count); separators = cell(count);
for level = 0:min(max_conditioning, count - 2)
    for i = 1:count
        for j = find(adjacent(i, :))
            if j < i, continue; end
            neighbours = setdiff(find(adjacent(i, :) | adjacent(j, :)), [i, j]);
            if numel(neighbours) < level, continue; end
            subsets = nchoosek(neighbours, level); if level == 0, subsets = zeros(1, 0); end
            for row = 1:size(subsets, 1)
                given = subsets(row, :);
                if independent(correlation, i, j, given, rows, alpha)
                    adjacent(i, j) = false; adjacent(j, i) = false; separators{i, j} = given; separators{j, i} = given; break;
                end
            end
        end
    end
end
% 向き：まず無向の辺（両方向1）とし、V字構造 i→k←j（i と j は隣接せず、k が i・j を分けた変数に含まれない）を決める。
adjacency = double(adjacent);
for k = 1:count
    parents = find(adjacent(:, k))';
    for a = 1:numel(parents)
        for b = a + 1:numel(parents)
            i = parents(a); j = parents(b);
            if ~adjacent(i, j) && ~ismember(k, separators{i, j})
                adjacency(k, i) = 0; adjacency(k, j) = 0;
            end
        end
    end
end
adjacency = meekRules(adjacency);
% 辺の強さ：ほかのすべての列で条件づけた偏相関。
precision = inv(correlation); partial = -precision ./ sqrt(diag(precision) * diag(precision)');
strength = partial .* (adjacency | adjacency'); order = [];
end

function yes = independent(correlation, i, j, given, rows, alpha)
indices = [i, j, given]; precision = inv(correlation(indices, indices));
r = -precision(1, 2) / sqrt(precision(1, 1) * precision(2, 2)); r = max(min(r, 1 - 1e-12), -1 + 1e-12);
statistic = 0.5 * log((1 + r) / (1 - r)) * sqrt(rows - numel(given) - 3);
yes = 2 * (1 - normcdf(abs(statistic))) > alpha;
end

function adjacency = meekRules(adjacency)
% Meek の規則 R1〜R3 を、向きが変わらなくなるまで繰り返す（新しい V字構造や循環を作らない向きだけを決める）。
directed = @(a, b) adjacency(a, b) == 1 && adjacency(b, a) == 0;
undirected = @(a, b) adjacency(a, b) == 1 && adjacency(b, a) == 1;
connected = @(a, b) adjacency(a, b) == 1 || adjacency(b, a) == 1;
count = size(adjacency, 1); changed = true;
while changed
    changed = false;
    for a = 1:count
        for b = 1:count
            if a == b || ~undirected(a, b), continue; end
            others = setdiff(1:count, [a, b]);
            % R1：c→a ― b で c と b が隣接しないなら a→b。
            rule1 = any(arrayfun(@(c) directed(c, a) && ~connected(c, b), others));
            % R2：a→c→b なら a→b。
            rule2 = any(arrayfun(@(c) directed(a, c) && directed(c, b), others));
            % R3：a ― c1→b、a ― c2→b で c1 と c2 が隣接しないなら a→b。
            middle = others(arrayfun(@(c) undirected(a, c) && directed(c, b), others)); rule3 = false;
            for p = 1:numel(middle)
                for q = p + 1:numel(middle)
                    if ~connected(middle(p), middle(q)), rule3 = true; end
                end
            end
            if rule1 || rule2 || rule3, adjacency(b, a) = 0; changed = true; end
        end
    end
end
end

% ======================= DirectLiNGAM =======================
function [adjacency, strength, order] = directLingam(z, alpha)
[rows, count] = size(z); remaining = 1:count; order = zeros(1, count); residuals = z;
for position = 1:count
    if numel(remaining) == 1
        chosen = remaining;
    else
        scores = zeros(1, numel(remaining));
        for a = 1:numel(remaining)
            i = remaining(a); score = 0;
            for j = remaining
                if i == j, continue; end
                xi = standardize(residuals(:, i)); xj = standardize(residuals(:, j));
                ri_j = xi - (xi' * xj / (xj' * xj)) * xj; rj_i = xj - (xj' * xi / (xi' * xi)) * xi;
                difference = (entropy(xj) + entropy(standardize(ri_j))) - (entropy(xi) + entropy(standardize(rj_i)));
                score = score + min(0, difference)^2;
            end
            scores(a) = -score;
        end
        [~, best] = max(scores); chosen = remaining(best);
    end
    order(position) = chosen; remaining(remaining == chosen) = [];
    % 選んだ変数の影響を、残りの変数から取り除く。
    for j = remaining
        x = residuals(:, chosen); residuals(:, j) = residuals(:, j) - (x' * residuals(:, j) / (x' * x)) * x;
    end
end
% 因果の順序に沿って、各変数を前の変数へ最小二乗で回帰し、有意でない係数は外す。
adjacency = zeros(count); strength = zeros(count);
for position = 2:count
    target = order(position); parents = order(1:position - 1);
    design = [ones(rows, 1), z(:, parents)]; [beta, ~, residual] = regress(z(:, target), design);
    degrees = rows - size(design, 2); variance = residual' * residual / degrees;
    standard_error = sqrt(diag(variance * inv(design' * design))); %#ok<MINV>
    p = 2 * (1 - tcdf(abs(beta ./ standard_error), degrees));
    for k = 1:numel(parents)
        if p(k + 1) < alpha, adjacency(parents(k), target) = 1; strength(parents(k), target) = beta(k + 1); end
    end
end
end

function u = standardize(u)
u = (u - mean(u)) / max(std(u), eps);
end

function h = entropy(u)
% 最大エントロピー近似による微分エントロピー（Hyvärinen 1998）。正規分布で最大になる。
K1 = 79.047; K2 = 7.4129; GAMMA = 0.37457;
h = (1 + log(2 * pi)) / 2 - K1 * (mean(log(cosh(u))) - GAMMA)^2 - K2 * mean(u .* exp(-u.^2 / 2))^2;
end

% ======================= 表 =======================
function edges = edgeTable(adjacency, strength, names, method)
names = string(names(:)); from = strings(0, 1); to = strings(0, 1); kind = strings(0, 1); value = zeros(0, 1);
count = size(adjacency, 1);
for i = 1:count
    for j = 1:count
        if adjacency(i, j) == 0, continue; end
        if adjacency(j, i) == 1
            if j < i, continue; end
            kind(end + 1, 1) = "―（向き未定）"; %#ok<AGROW>
        else
            kind(end + 1, 1) = "→"; %#ok<AGROW>
        end
        from(end + 1, 1) = names(i); to(end + 1, 1) = names(j); value(end + 1, 1) = strength(i, j); %#ok<AGROW>
    end
end
label = '偏相関'; if strcmp(method, 'lingam'), label = '係数_標準化'; end
edges = table(from, kind, to, value, 'VariableNames', {'元', '向き', '先', label});
end
