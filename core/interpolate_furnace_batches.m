function report = interpolate_furnace_batches(data, query, methods, options, progress, evaluator)
% Batchはモデル入力にせず、別々の回帰を行うための区分としてだけ使う。
if nargin < 5, progress = []; end
if nargin < 6, evaluator = @evaluate_furnace_models; end
if ischar(methods), methods = {methods}; end
groups = unique(data.Batch, 'stable'); combined = []; series = {};
constants = furnace_constants(); fits = 0;
for group = 1:numel(groups)
    fits = fits + sum(max(sum(isfinite(data.Values(data.Batch == groups(group), :)), 1) - 1, 0))*numel(methods);
end
if numel(groups)*numel(data.TargetNames)*numel(query)*numel(methods) > constants.MaximumOutputRows || fits > constants.MaximumFits
    error('furnace:workSize', '予測結果は%d行、学習は最大%d回までです。バッチ・項目・候補数・予測範囲を絞ってください。', constants.MaximumOutputRows, constants.MaximumFits);
end
for group = 1:numel(groups)
    batch = groups(group); rows = find(data.Batch == batch);
    callback = @(event) batchProgress(event, batch, group, numel(groups));
    single = evaluator(data.Slots(rows), data.Values(rows, :), data.TargetNames, query, methods, options, callback);
    predictions = single.Predictions;
    if ~isempty(predictions)
        [known, location] = ismember(predictions.BoatSlot, data.Slots(rows)); wafer = strings(height(predictions), 1); source_rows = NaN(height(predictions), 1);
        wafer(known) = data.WaferId(rows(location(known))); source_rows(known) = data.SourceRows(rows(location(known)));
        predictions = addvars(predictions, wafer, source_rows, 'Before', 1, 'NewVariableNames', {'WaferId', 'SourceRow'});
    end
    single.Predictions = predictions;
    if ~isempty(single.Validation)
        single.Validation.SourceRow = data.SourceRows(rows(single.Validation.SourceIndex));
        single.Validation.WaferId = data.WaferId(rows(single.Validation.SourceIndex)); single.Validation.SourceIndex = [];
    end
    for field = {'Comparison', 'Metrics', 'Predictions', 'Validation'}
        name = field{1}; table_data = single.(name);
        if ~isempty(table_data), table_data = addvars(table_data, repmat(batch, height(table_data), 1), 'Before', 1, 'NewVariableNames', 'Batch'); end
        if isempty(combined), combined = struct(); end
        if ~isfield(combined, name), combined.(name) = table(); end
        combined.(name) = [combined.(name); table_data];
    end
    for index = 1:numel(single.Series)
        if ~isempty(single.Series{index})
            single.Series{index}.Batch = batch;
            single.Series{index}.SourceRows = data.SourceRows(rows(single.Series{index}.SourceIndex));
        end
    end
    series = [series; single.Series]; %#ok<AGROW>
end
report = combined; report.Series = series; report.Options = options;
    function batchProgress(event, batch, index, count)
        event.Batch = char(batch); event.BatchIndex = index; event.BatchCount = count;
        if ~isempty(progress), progress(event); end
    end
end
