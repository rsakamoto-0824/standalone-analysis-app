function [ranks, scores, groups] = model_rank_scores(records)
% 学習したモデルの一覧の順位。同じ実行・同じ目的変数・同じ損失関数（分位点回帰は同じ τ）のモデルどうしで比べる。
%   平均を予測するモデル（二乗誤差・GPR）：RMSE の小さい順
%   分位点回帰のモデル：ピンボール損失の小さい順（RMSE は平均からのずれのため、分位点のモデルの比べ方には使わない）
% records：Run・Target・Condition・Model・Metrics・Actual・Prediction を持つ記録の cell。学習に失敗したモデルは順位 NaN。
% 戻り値：ranks（順位）、scores（比べた値）、groups（比べたまとまりの名前。"実行/目的変数/平均" または "…/分位点τ=0.9"）。
count = numel(records); ranks = NaN(count, 1); scores = NaN(count, 1); groups = strings(count, 1);
for index = 1:count
    record = records{index}; [loss, tau] = lossOf(record.Condition);
    groups(index) = sprintf('%d/%s/%s', record.Run, record.Target, loss);
    if isempty(record.Model) || isempty(record.Metrics), continue; end
    if isnan(tau)
        scores(index) = record.Metrics.Value(2);
    elseif ~isempty(record.Prediction)
        scores(index) = ProcessRegressionModel.pinballLoss(record.Actual, record.Prediction, tau);
    end
end
names = unique(groups);
for group = 1:numel(names)
    members = find(groups == names(group) & isfinite(scores)); [~, order] = sort(scores(members));
    ranks(members(order)) = 1:numel(members);
end
end

function [loss, tau] = lossOf(condition)
loss = "平均"; tau = NaN;
if isfield(condition, 'Loss') && ~isempty(condition.Loss) && strcmp(condition.Loss.Type, 'quantile')
    tau = condition.Loss.Quantile; loss = "分位点τ=" + string(tau);
end
end
