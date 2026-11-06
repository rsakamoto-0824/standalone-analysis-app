function records = evaluate_modeling_batch(inputs, responses, names, targets, conditions, options, services, progress)
% 保存処理を含めず、目的変数と条件ごとにモデル・評価・SHAPを保持する。
if nargin < 8, progress = []; end
validate_numeric_data(inputs, '説明変数', mfilename); validate_numeric_data(responses, '目的変数', mfilename);
if size(inputs,1) ~= size(responses,1) || size(responses,2) ~= numel(targets) || size(inputs,2) ~= numel(names)
    error('modeling:shape', '説明変数・目的変数の行数と列名を一致させてください。');
end
count = numel(conditions);
if count < 1 || count*numel(targets) > 100, error('modeling:size', '一度に計算する目的変数×条件は1〜100組にしてください。'); end
records = cell(numel(targets)*count,1); position = 0;
for target = 1:numel(targets)
    actual = responses(:,target); report = [];
    if count > 1 && options.Folds >= 2
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
                record.FoldMetrics.Kernel(:) = string(conditions(candidate).Kernel);
                record.Note = char(report.Summary.Note(candidate));
            else
                [record.Model, warnings, record.Details] = services.Trainer(inputs, actual, conditions(candidate), []);
                record.Note = char(strjoin(string(warnings), ' / '));
                record.Prediction = services.Predictor(record.Model, inputs); record.TrainingPrediction = record.Prediction;
            end
            record.Metrics = evaluate_predictions(actual, record.Prediction, options.Bins);
            record.TrainingMetrics = evaluate_predictions(actual, record.TrainingPrediction, options.Bins);
            record.Status = '成功'; notify('SHAP', target, candidate);
            try
                limit = min(size(inputs,1),1000);
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
        if ~isempty(report), record.Seconds=record.Seconds+report.Summary.Seconds(candidate); end
        records{position} = record;
    end
end
    function [model, warnings, details] = train(x,y,label,callback)
        condition_index = str2double(extractAfter(label,'condition_'));
        [model,warnings,details] = services.Trainer(x,y,conditions(condition_index),callback);
    end
    function notifyCV(~), notify('交差検証',target,0); end
    function notify(stage, target_index, condition_index)
        if ~isempty(progress), progress(struct('Stage',stage,'Target',targets{target_index},'Condition',condition_index,'Conditions',count)); end
    end
end
