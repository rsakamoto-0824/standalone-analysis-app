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
records = cell(numel(targets)*count,1); position = 0;
for target = 1:numel(targets)
    actual = responses(:,target); report = [];
    if options.Folds >= 2
        labels = cellstr("condition_" + string(1:count));
        report = evaluate_kernel_candidates(inputs, actual, labels, options.Folds, options.Seed, options.Bins, @train, services.Predictor, @notifyCV);
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
                [record.Model, warnings, record.Details] = services.Trainer(inputs, actual, conditions(candidate), []);
                record.Note = char(strjoin(string(warnings), ' / '));
                record.Prediction = services.Predictor(record.Model, inputs); record.TrainingPrediction = record.Prediction;
            end
            record.Metrics = evaluate_predictions(actual, record.Prediction, options.Bins);
            record.TrainingMetrics = evaluate_predictions(actual, record.TrainingPrediction, options.Bins);
            record.Status = '成功';
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
    end
    function notifyCV(update)
        stage = sprintf('交差検証 %d / %d 分割', update.Fold, update.Folds);
        if update.Fold == 0, stage = update.Stage; end
        if update.PeriodCount > 0, stage = sprintf('%s（周期候補 %d / 最大%d）', stage, update.PeriodCount, update.PeriodMaximum); end
        notify(stage, target, update.KernelIndex);
    end
    function notify(stage, target_index, condition_index)
        if ~isempty(progress), progress(struct('Stage',stage,'Target',targets{target_index},'Condition',condition_index,'Conditions',count)); end
    end
end
