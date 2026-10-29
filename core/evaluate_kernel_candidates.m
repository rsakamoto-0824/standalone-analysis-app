function report = evaluate_kernel_candidates(X, y, kernels, folds, seed, bins, trainer, predictor, progress)
% 学習器を分離し、同一分割・同一乱数条件で未使用行の予測を比較する。
if nargin < 9, progress = []; end
validate_numeric_data(X, 'X', mfilename); validate_numeric_data(y, 'y', mfilename);
if ~isvector(y) || numel(y) ~= size(X, 1)
    error('evaluate_kernel_candidates:rowCount', 'Xの行数とyの要素数を一致させてください。');
end
y = double(y(:)); rows = size(X, 1);
validateattributes(folds, {'numeric'}, {'scalar', 'integer', '>=', 2, '<=', min(10, rows)}, mfilename, 'folds');
if rows - ceil(rows / folds) < 2
    error('evaluate_kernel_candidates:tooFewRows', '各分割の学習行は2行以上必要です。');
end
validateattributes(seed, {'numeric'}, {'scalar', 'integer', '>=', 0, '<=', 2^32 - 1}, mfilename, 'seed');
if bins ~= 0, validate_bin_count(bins, mfilename); end
if ~(iscellstr(kernels) || isstring(kernels)) || ~isvector(kernels)
    error('evaluate_kernel_candidates:kernels', 'カーネル名の一覧を渡してください。');
end
kernels = cellstr(lower(string(kernels(:)))); count = numel(kernels);
if count < 2 || numel(unique(kernels)) ~= count
    error('evaluate_kernel_candidates:kernels', '異なるカーネルを2個以上選択してください。');
end
previous_rng = rng; cleanup = onCleanup(@() rng(previous_rng));
rng(seed, 'twister'); fold_id = zeros(rows, 1);
fold_id(randperm(rows)) = mod((0:rows - 1)', folds) + 1;
models = cell(count, 1); details = cell(count, 1); warnings = cell(count, 1);
oof = NaN(rows, count); training_prediction = NaN(rows, count);
values = NaN(count, 8); training_values = values; seconds = zeros(count, 1); periods = NaN(count, 1);
status = repmat("失敗", count, 1); notes = strings(count, 1); all_metrics = table(); fold_metrics = table();
for candidate = 1:count
    started = tic; warnings{candidate} = strings(0, 1);
    event = struct('Kernel', kernels{candidate}, 'KernelIndex', candidate, 'KernelCount', count, ...
        'Fold', 0, 'Folds', folds, 'Stage', '交差検証', 'PeriodCount', 0, 'PeriodMaximum', 0, 'Period', NaN);
    notify(event);
    try
        for fold = 1:folds
            event.Fold = fold; notify(event);
            held_out = fold_id == fold;
            % 候補順や失敗の有無で、次の候補の乱数条件が変わらないようにする。
            rng(mod(seed + fold, 2^32), 'twister');
            [model, messages, fold_details] = trainer(X(~held_out, :), y(~held_out), kernels{candidate}, @periodProgress);
            warnings{candidate} = [warnings{candidate}; string(messages(:))];
            predicted = checkedPrediction(model, X(held_out, :)); oof(held_out, candidate) = predicted;
            fold_metrics = [fold_metrics; table(string(kernels{candidate}), fold, sum(~held_out), sum(held_out), ...
                sqrt(mean((y(held_out) - predicted).^2)), selectedPeriod(fold_details), ...
                'VariableNames', {'Kernel', 'Fold', 'TrainRows', 'ValidationRows', 'RMSE', 'Period'})]; %#ok<AGROW>
            notify(event);
        end
        cv_metrics = evaluate_predictions(y, oof(:, candidate), bins);
        event.Stage = '全データで学習'; event.Fold = 0; notify(event);
        rng(mod(seed + folds + 1, 2^32), 'twister');
        [model, messages, detail] = trainer(X, y, kernels{candidate}, @periodProgress);
        warnings{candidate} = unique([warnings{candidate}; string(messages(:))], 'stable');
        prediction = checkedPrediction(model, X);
        train_metrics = evaluate_predictions(y, prediction, bins);
        notify(event);
        models{candidate} = model; details{candidate} = detail; training_prediction(:, candidate) = prediction;
        values(candidate, :) = cv_metrics.Value'; training_values(candidate, :) = train_metrics.Value';
        periods(candidate) = selectedPeriod(detail);
        all_metrics = [all_metrics; labelledMetrics(cv_metrics, kernels{candidate}, '交差検証'); ...
            labelledMetrics(train_metrics, kernels{candidate}, '学習データ')]; %#ok<AGROW>
        status(candidate) = "成功"; notes(candidate) = strjoin(warnings{candidate}, ' / ');
    catch err
        if strcmp(err.identifier, 'AnalysisApp:cancelled'), rethrow(err); end
        oof(:, candidate) = NaN; training_prediction(:, candidate) = NaN;
        notes(candidate) = string(err.identifier) + ": " + string(err.message);
    end
    seconds(candidate) = toc(started);
end
notify(event);
rank = NaN(count, 1); successful = find(status == "成功");
[~, order] = sortrows([values(successful, 2), values(successful, 4), successful], [1, 2, 3]);
rank(successful(order)) = (1:numel(successful))';
summary = table(string(kernels), status, rank, repmat(folds, count, 1), repmat(seed, count, 1), repmat(rows, count, 1), ...
    'VariableNames', {'Kernel', 'Status', 'Rank', 'Folds', 'Seed', 'Rows'});
metric_names = {'R2', 'RMSE', 'RMSPE_percent', 'MAE', 'Pearson_r', 'Correlation_squared', 'KL_nats', 'Mutual_information_bits'};
summary = [summary, array2table(values, 'VariableNames', metric_names), ...
    table(training_values(:, 1), training_values(:, 2), seconds, periods, notes, ...
    'VariableNames', {'Training_R2', 'Training_RMSE', 'Seconds', 'Period', 'Note'})];
report = struct('Summary', summary, 'Metrics', all_metrics, 'FoldMetrics', fold_metrics, 'FoldId', fold_id, ...
    'OOFPredictions', oof, 'TrainingPredictions', training_prediction, 'Models', {models}, ...
    'Details', {details}, 'Warnings', {warnings}, 'Folds', folds, 'Seed', seed);

    function prediction = checkedPrediction(model, inputs)
        prediction = predictor(model, inputs);
        validate_numeric_data(prediction, '予測値', 'evaluate_kernel_candidates');
        if ~isvector(prediction) || numel(prediction) ~= size(inputs, 1)
            error('evaluate_kernel_candidates:predictionSize', '予測値の件数が検証データと一致しません。');
        end
        prediction = double(prediction(:));
    end
    function periodProgress(number, maximum, period)
        period_event = event; period_event.PeriodCount = number; period_event.PeriodMaximum = maximum; period_event.Period = period;
        notify(period_event);
    end
    function notify(update)
        if ~isempty(progress), progress(update); end
    end
end

function period = selectedPeriod(details)
period = NaN;
if ~isempty(details) && isfield(details, 'Period'), period = details.Period; end
end

function metrics = labelledMetrics(metrics, kernel, scope)
metrics = addvars(metrics, repmat(string(kernel), height(metrics), 1), repmat(string(scope), height(metrics), 1), ...
    'Before', 1, 'NewVariableNames', {'Kernel', 'Scope'});
end
