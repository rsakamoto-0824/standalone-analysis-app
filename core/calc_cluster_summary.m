function result = calc_cluster_summary(values, names, method, cluster_count, seed)
% クラスタリング。列ごとに標準化してから、k-means 法または Ward 法（階層型）で cluster_count 群に分ける。
% 空欄を含む行は除く（群は 0）。
%   result.Clusters     各行の群（1〜cluster_count。除いた行は 0）
%   result.Silhouette   シルエット係数の平均（1に近いほど群がはっきり分かれている）
%   result.Elbow        表：群の数ごとの群内平方和（群の数を決める目安。曲がりの大きい所）
%   result.Centers      表：群ごとの件数と各列の平均（元の単位）
%   result.Linkage      Ward 法の結合の記録（樹形図用。k-means では空）
MAX_ELBOW = 10; REPLICATES = 10;
if size(values, 2) < 1, error('cluster:columns', '数値の列を1列以上選んでください。'); end
if ~ismember(method, {'kmeans', 'ward'}), error('cluster:method', 'kmeans または ward を指定してください。'); end
valid = all(isfinite(values), 2); rows = sum(valid);
if rows < cluster_count + 1, error('cluster:rows', '群の数（%d）より多い、空欄のない行が必要です（現在 %d行）。', cluster_count, rows); end
scale = std(values(valid, :), 0, 1);
if any(scale == 0), error('cluster:constant', '値が一定の列は使えません: %s', strjoin(cellstr(string(names(scale == 0))), ', ')); end
z = (values(valid, :) - mean(values(valid, :), 1)) ./ scale;
previous = rng; restore = onCleanup(@() rng(previous)); rng(seed, 'twister');
limit = min(MAX_ELBOW, rows - 1); within = NaN(limit, 1); tree = [];
if strcmp(method, 'ward')
    tree = linkage(z, 'ward');
    assignment = cluster(tree, 'maxclust', cluster_count);
    for k = 1:limit, within(k) = withinSum(z, cluster(tree, 'maxclust', k)); end
else
    assignment = kmeans(z, cluster_count, 'Replicates', REPLICATES);
    for k = 1:limit, [~, ~, sums] = kmeans(z, k, 'Replicates', REPLICATES); within(k) = sum(sums); end
end
result.Clusters = zeros(size(values, 1), 1); result.Clusters(valid) = assignment; result.Valid = valid;
result.Silhouette = mean(silhouette(z, assignment), 'omitnan');
result.Elbow = table((1:limit)', within, 'VariableNames', {'群の数', '群内平方和'});
counts = accumarray(assignment, 1, [cluster_count, 1]);
means = zeros(cluster_count, size(values, 2)); kept = values(valid, :);
for k = 1:cluster_count, means(k, :) = mean(kept(assignment == k, :), 1); end
result.Centers = [table((1:cluster_count)', counts, 'VariableNames', {'群', '件数'}), array2table(means, 'VariableNames', cellstr(string(names)))];
result.Linkage = tree; result.Standardized = z;
end

function total = withinSum(z, assignment)
total = 0;
for k = unique(assignment)'
    members = z(assignment == k, :); total = total + sum(sum((members - mean(members, 1)).^2));
end
end
