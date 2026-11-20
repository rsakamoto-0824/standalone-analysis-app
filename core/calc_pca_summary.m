function result = calc_pca_summary(values, names)
% 主成分分析。列ごとに平均0・標準偏差1へそろえて（標準化して）から計算する（単位の違う列を同じ重みで扱うため）。
% 空欄を含む行は除く。
%   result.Scores      主成分得点（除いた行は NaN）
%   result.Loadings    負荷量（説明変数 × 主成分）
%   result.Explained   寄与率（%）
%   result.Variance    表：主成分ごとの固有値・寄与率・累積寄与率
%   result.LoadingTable 表：説明変数ごとの負荷量
validateColumns(values, names, 2);
valid = all(isfinite(values), 2);
if sum(valid) < 3, error('pca:rows', '主成分分析には、空欄のない行が3行以上必要です（現在 %d行）。', sum(valid)); end
z = standardize(values(valid, :), names);
% 互いに比例する列があると、使わない統計量（T²）の計算で警告が出るため、この計算の間だけ止める。
previous = warning('off', 'stats:pca:ColRankDefX'); restore = onCleanup(@() warning(previous));
[loadings, scores, latent, ~, explained] = pca(z);
clear restore;
components = size(loadings, 2); labels = cellstr("PC" + string(1:components));
result.Scores = NaN(size(values, 1), components); result.Scores(valid, :) = scores;
result.Loadings = loadings; result.Explained = explained; result.Valid = valid;
result.Variance = table(string(labels(:)), latent, explained, cumsum(explained), 'VariableNames', {'主成分', '固有値', '寄与率_percent', '累積寄与率_percent'});
result.LoadingTable = [table(string(names(:)), 'VariableNames', {'説明変数'}), array2table(loadings, 'VariableNames', labels)];
end

function validateColumns(values, names, minimum)
if size(values, 2) < minimum, error('pca:columns', '数値の列を%d列以上選んでください。', minimum); end
if numel(names) ~= size(values, 2), error('pca:names', '列名の数が列の数と一致しません。'); end
end

function z = standardize(values, names)
scale = std(values, 0, 1);
if any(scale == 0), error('pca:constant', '値が一定の列は使えません: %s', strjoin(cellstr(string(names(scale == 0))), ', ')); end
z = (values - mean(values, 1)) ./ scale;
end
