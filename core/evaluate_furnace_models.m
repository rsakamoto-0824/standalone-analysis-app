function report = evaluate_furnace_models(slots, values, target_names, query, methods, options, progress, trainer, predictor)
% 一つの成膜Runのプロファイルを比較。検証では両端を固定し内部Slotだけを除く。
if nargin < 7, progress = []; end
if nargin < 8, trainer = @fit_furnace_model; end
if nargin < 9, predictor = @predict_furnace_model; end
constants = furnace_constants();
if ischar(methods), methods = {methods}; end
if ~(iscellstr(methods) || isstring(methods)) || ~isvector(methods)
    error('furnace:method', '補間方式の一覧を指定してください。');
end
methods = cellstr(lower(string(methods(:))));
if ~isstruct(options) || ~isscalar(options), error('furnace:options', '設定は単一の構造体を渡してください。'); end
validate_numeric_data(slots, 'BoatSlot', mfilename); validate_numeric_data(values, '計測値', mfilename, true);
validateattributes(slots, {'numeric'}, {'vector', 'integer', 'positive', '<=', constants.MaximumSlot});
validateattributes(query, {'numeric'}, {'vector', 'integer', 'positive', 'finite', '<=', constants.MaximumSlot});
slots = double(slots(:)); query = double(query(:)); target_names = string(target_names(:));
if numel(unique(slots)) ~= numel(slots), error('furnace:duplicateSlots', '同じ成膜Run内のBoatSlotが重複しています。入力を確認してください。'); end
if size(values, 1) ~= numel(slots) || size(values, 2) ~= numel(target_names) || numel(unique(target_names)) ~= numel(target_names)
    error('furnace:shape', 'BoatSlot・計測値・対象名の件数を確認してください。');
end
if numel(slots) > constants.MaximumMeasuredSlots || numel(query) > constants.MaximumQuerySlots || numel(target_names) > constants.MaximumTargets
    error('furnace:size', '1Runの入力は%d行、予測は%dSlot、計測項目は%d列までです。', constants.MaximumMeasuredSlots, constants.MaximumQuerySlots, constants.MaximumTargets);
end
if isempty(methods) || ~all(ismember(string(methods), string(constants.Methods))) || numel(unique(string(methods))) ~= numel(methods)
    error('furnace:method', '補間方式を1個以上、重複なく選択してください。');
end
if ~isfield(options, 'AllowExtrapolation'), options.AllowExtrapolation = false; end
if ~isfield(options, 'Bins'), options.Bins = constants.DefaultBins; end
validateattributes(options.AllowExtrapolation, {'logical', 'numeric'}, {'scalar', 'binary'});
if options.Bins ~= 0, validate_bin_count(options.Bins, mfilename); end
previous_rng = rng; cleanup = onCleanup(@() rng(previous_rng));
comparison = table(); metrics = table(); predictions = table(); validation = table(); series = cell(numel(target_names)*numel(methods), 1);
total = sum(max(sum(isfinite(values), 1) - 1, 0)) * numel(methods); evaluated = 0;
for target = 1:numel(target_names)
    source_index = find(~isnan(values(:, target))); [x, order] = sort(slots(source_index)); source_index = source_index(order);
    y = double(values(source_index, target)); measured_count = numel(x); scores = NaN(numel(methods), 8);
    training_scores = scores; status = repmat("失敗", numel(methods), 1); notes = strings(numel(methods), 1); elapsed = zeros(numel(methods), 1);
    for candidate = 1:numel(methods)
        method = char(methods{candidate}); started = tic;
        event = struct('Target', char(target_names(target)), 'Method', method, 'Index', evaluated, 'Total', total, 'Stage', '検証');
        notify(event);
        try
            if measured_count < constants.MinimumMeasuredSlots
                error('furnace:tooFewSlots', '対象「%s」は計測済みBoatSlotが%d点以上必要です（現在%d点）。', target_names(target), constants.MinimumMeasuredSlots, measured_count);
            end
            cv_prediction = NaN(measured_count, 1); interior = (2:measured_count - 1)';
            for held_out = interior'
                event.Stage = sprintf('内部Slot %g を除いて検証', x(held_out)); event.Index = evaluated + 1; notify(event);
                train_rows = true(measured_count, 1); train_rows(held_out) = false;
                rng(constants.ComparisonSeed + held_out, 'twister');
                model = trainer(x(train_rows), y(train_rows), method, options);
                cv_prediction(held_out) = predictor(model, x(held_out)); evaluated = evaluated + 1; notify(event);
            end
            cv_metrics = evaluate_predictions(y(interior), cv_prediction(interior), options.Bins);
            event.Stage = '全計測Slotで学習'; event.Index = evaluated + 1; notify(event);
            rng(constants.ComparisonSeed, 'twister'); model = trainer(x, y, method, options);
            training_prediction = predictor(model, x); train_metrics = evaluate_predictions(y, training_prediction, options.Bins);
            outside = query < min(x) | query > max(x); allowed = ~outside | logical(options.AllowExtrapolation);
            predicted = NaN(size(query)); deviation = predicted; interval = NaN(numel(query), 2);
            if any(allowed), [predicted(allowed), deviation(allowed), interval(allowed, :)] = predictor(model, query(allowed)); end
            if any(~isfinite(predicted(allowed))), error('furnace:prediction', '有限の予測値を取得できません。'); end
            evaluated = evaluated + 1; notify(event);
            actual = NaN(size(query)); [is_measured, measured_index] = ismember(query, x); actual(is_measured) = y(measured_index(is_measured));
            region = repmat("補間", numel(query), 1); region(is_measured) = "計測位置";
            region(outside & allowed) = "外挿"; region(~allowed) = "範囲外・未計算";
            target_column = repmat(target_names(target), numel(query), 1); method_column = repmat(string(method), numel(query), 1);
            predictions = [predictions; table(target_column, method_column, query, actual, predicted, deviation, interval(:, 1), interval(:, 2), outside, region, ...
                'VariableNames', {'Target', 'Method', 'BoatSlot', 'Actual', 'Predicted', 'ResponseSD', 'Lower95', 'Upper95', 'OutsideMeasuredRange', 'Region'})]; %#ok<AGROW>
            reason = repmat("内部Slotを除いて検証", measured_count, 1); reason([1, end]) = "両端の計測Slot：検証対象外";
            validation = [validation; table(repmat(target_names(target), measured_count, 1), repmat(string(method), measured_count, 1), ...
                source_index, x, y, cv_prediction, y - cv_prediction, reason, ...
                'VariableNames', {'Target', 'Method', 'SourceIndex', 'BoatSlot', 'Actual', 'ValidationPredicted', 'Residual', 'Note'})]; %#ok<AGROW>
            metrics = [metrics; labelMetrics(cv_metrics, target_names(target), method, '内部Slotの検証'); ...
                labelMetrics(train_metrics, target_names(target), method, '全計測Slotの学習')]; %#ok<AGROW>
            scores(candidate, :) = cv_metrics.Value'; training_scores(candidate, :) = train_metrics.Value'; status(candidate) = "成功";
            index = (target - 1)*numel(methods) + candidate;
            series{index} = struct('Target', target_names(target), 'Method', string(method), 'Slots', x, 'Actual', y, ...
                'SourceIndex', source_index, 'ValidationPrediction', cv_prediction, 'TrainingPrediction', training_prediction, ...
                'Query', query, 'Prediction', predicted, 'Deviation', deviation, 'Interval', interval, 'Outside', outside);
        catch err
            if strcmp(err.identifier, 'AnalysisApp:cancelled'), rethrow(err); end
            notes(candidate) = string(err.identifier) + ": " + string(err.message);
        end
        elapsed(candidate) = toc(started);
    end
    ranks = NaN(numel(methods), 1); success = find(status == "成功");
    [~, order] = sortrows([scores(success, 2), scores(success, 4), success], [1, 2, 3]); ranks(success(order)) = (1:numel(success))';
    names = {'R2', 'RMSE', 'RMSPE_percent', 'MAE', 'Pearson_r', 'Correlation_squared', 'KL_nats', 'Mutual_information_bits'};
    comparison = [comparison; table(repmat(target_names(target), numel(methods), 1), string(methods(:)), status, ranks, ...
        repmat(measured_count, numel(methods), 1), repmat(max(0, measured_count - 2), numel(methods), 1), ...
        'VariableNames', {'Target', 'Method', 'Status', 'Rank', 'MeasuredSlots', 'ValidationSlots'}), ...
        array2table(scores, 'VariableNames', names), table(training_scores(:, 1), training_scores(:, 2), elapsed, notes, ...
        'VariableNames', {'Training_R2', 'Training_RMSE', 'Seconds', 'Note'})]; %#ok<AGROW>
end
notify(event);
report = struct('Comparison', comparison, 'Metrics', metrics, 'Predictions', predictions, 'Validation', validation, ...
    'Series', {series}, 'Options', options);
    function notify(update)
        if ~isempty(progress), progress(update); end
    end
end

function metrics = labelMetrics(metrics, target, method, scope)
metrics = addvars(metrics, repmat(string(target), height(metrics), 1), repmat(string(method), height(metrics), 1), ...
    repmat(string(scope), height(metrics), 1), 'Before', 1, 'NewVariableNames', {'Target', 'Method', 'Scope'});
end
