function data = display_metric_names(data)
% 計算・保存モデルの識別子を維持し、表示と表の書出しに使う名称だけを変える。
if ~istable(data), return; end
identifiers = {'KL_nats', 'Mutual_information_bits'};
labels = {'KLダイバージェンス', '相互情報量'};
for index = 1:numel(identifiers)
    names = data.Properties.VariableNames;
    names(strcmp(names, identifiers{index})) = labels(index);
    data.Properties.VariableNames = names;
    if ismember('Metric', names)
        data.Metric = string(data.Metric);
        data.Metric(data.Metric == identifiers{index}) = labels{index};
    end
end
end
