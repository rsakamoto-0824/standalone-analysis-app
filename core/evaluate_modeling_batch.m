function records = evaluate_modeling_batch(inputs, responses, names, targets, conditions, options, services, progress)
% 保存処理を含めず、目的変数と条件ごとにモデル・評価・SHAPを保持する。
if nargin < 8, progress = []; end
validate_numeric_data(inputs, '説明変数', mfilename); validate_numeric_data(responses, '目的変数', mfilename);
if size(inputs,1) ~= size(responses,1) || size(responses,2) ~= numel(targets) || size(inputs,2) ~= numel(names)
    error('modeling:shape', '説明変数・目的変数の行数と列名を一致させてください。');
end
count = numel(conditions); constants = model_constants();
if count < 1 || count*numel(targets) > constants.MAX_MODELING_CANDIDATES
    error('modeling:size', '一度に計算する目的変数×条件は1〜%d組にしてください。', constants.MAX_MODELING_CANDIDATES);
end
% Folds が2以上なら、条件が1つでも交差検証で評価する。0なら学習データで評価する。
compute_shap = ~isfield(options, 'ComputeShap') || options.ComputeShap;
% 進捗の割合：1回の学習と1回のSHAP計算をそれぞれ1単位として数える。
trainings_per_target = count; if options.Folds >= 2, trainings_per_target = count*(options.Folds+1); end
units_per_target = trainings_per_target + count*double(compute_shap);
total_units = numel(targets)*units_per_target; trained = 0; shapped = 0; partial = 0;
records = cell(numel(targets)*count,1); position = 0;
for target = 1:numel(targets)
    actual = responses(:,target); report = []; trained = 0; shapped = 0; partial = 0;
    if options.Folds >= 2
        labels = cellstr("condition_" + string(1:count));
        report = evaluate_kernel_candidates(inputs, actual, labels, options.Folds, options.Seed, options.Bins, @train, services.Predictor, @notifyCV);
        trained = trainings_per_target; partial = 0;
    end
    for candidate = 1:count
        position = position+1; notify('学習', target, candidate); started = tic;
        record = struct('Target', char(targets{target}), 'Condition', conditions(candidate), 'Inputs', inputs, 'InputNames', {names}, ...
            'Actual', actual, 'Model', [], 'Prediction', [], 'TrainingPrediction', [], 'Metrics', table(), ...
            'TrainingMetrics', table(), 'Scope', '学習データ', 'FoldId', [], 'FoldMetrics', table(), 'Details', [], 'Shap', [], 'Status', '失敗', ...
            'ShapStatus', '未計算', 'Note', '', 'Seconds', 0);
        try
            if ~isempty(report)
                if report.Summary.Status(candidate) ~= "成功", error('modeling:candidateFailed', '%s', report.Summary.Note(candidate)); end
                record.Model = report.Models{candidate}; record.Prediction = report.OOFPredictions(:,candidate);
                record.TrainingPrediction = report.TrainingPredictions(:,candidate); record.Details = report.Details{candidate};
                record.Scope = sprintf('%d分割交差検証', options.Folds);
                record.FoldId = report.FoldId;
                record.FoldMetrics = report.FoldMetrics(report.FoldMetrics.Kernel==labels{candidate},:);
                record.FoldMetrics.Kernel(:) = string(modeling_condition_label(conditions(candidate)));
                record.Note = char(report.Summary.Note(candidate));
            else
                [record.Model, warnings, record.Details] = services.Trainer(inputs, actual, conditions(candidate), @periodProgress);
                record.Note = char(strjoin(string(warnings), ' / '));
                record.Prediction = services.Predictor(record.Model, inputs); record.TrainingPrediction = record.Prediction;
            end
            record.Metrics = evaluate_predictions(actual, record.Prediction, options.Bins);
            record.TrainingMetrics = evaluate_predictions(actual, record.TrainingPrediction, options.Bins);
            record.Status = '成功';
            if isempty(report), trained = candidate; partial = 0; end
            if ~compute_shap, record.Seconds = toc(started); records{position} = addCVSeconds(record); continue; end
            notify('SHAP', target, candidate);
            try
                limit = min(size(inputs,1),constants.MAX_SHAP_POINTS);
                [object, values] = services.Shap(record.Model, inputs(1:limit,:));
                if ~isequal(size(values), [limit,size(inputs,2)]) || any(~isfinite(values(:)))
                    error('modeling:shapShape', 'SHAP値の形状または数値が不正です。');
                end
                record.Shap = struct('Explainer', object, 'Values', values, 'Inputs', inputs(1:limit,:));
                record.ShapStatus = '成功';
            catch err
                if strcmp(err.identifier,'AnalysisApp:cancelled'), rethrow(err); end
                record.ShapStatus = '失敗'; record.Note = [record.Note ' / SHAP: ' err.message];
            end
        catch err
            if strcmp(err.identifier,'AnalysisApp:cancelled'), rethrow(err); end
            record.Model = []; record.Note = err.message;
        end
        if isempty(report), trained = candidate; partial = 0; end
        if compute_shap, shapped = candidate; end
        record.Seconds = toc(started);
        records{position} = addCVSeconds(record);
    end
end
    function record = addCVSeconds(record)
        if ~isempty(report), record.Seconds = record.Seconds + report.Summary.Seconds(candidate); end
    end
    function [model, warnings, details] = train(x,y,label,callback)
        condition_index = str2double(extractAfter(label,'condition_'));
        [model,warnings,details] = services.Trainer(x,y,conditions(condition_index),callback);
        trained = trained + 1; partial = 0;
    end
    function notifyCV(update)
        % 前の条件が途中で失敗した場合も、条件の切替えで進捗をそろえる。
        trained = max(trained, (update.KernelIndex-1)*(update.Folds+1));
        stage = sprintf('交差検証 %d / %d 分割', update.Fold, update.Folds);
        if update.Fold == 0, stage = update.Stage; end
        partial = 0;
        if update.PeriodCount > 0
            stage = sprintf('%s（周期候補 %d / 最大%d）', stage, update.PeriodCount, update.PeriodMaximum);
            partial = min(update.PeriodCount/max(update.PeriodMaximum,1), 1);
        end
        notify(stage, target, update.KernelIndex);
    end
    function periodProgress(number, maximum, ~)
        % 周期カーネルは候補ごとに学習し直すため、1回の学習の中の進み具合も反映する。
        partial = min(number/max(maximum,1), 1);
        notify(sprintf('学習（周期候補 %d / 最大%d）', number, maximum), target, candidate);
    end
    function notify(stage, target_index, condition_index)
        if isempty(progress), return; end
        done = (target_index-1)*units_per_target + trained + shapped + partial;
        progress(struct('Stage',stage,'Target',targets{target_index},'TargetIndex',target_index,'Targets',numel(targets), ...
            'Condition',condition_index,'Conditions',count,'Done',min(done,total_units),'Total',total_units));
    end
end
