function [best, trace, searched] = search_hyperparameters(inputs, response, names, method, components, base, search, progress)
% ハイパーパラメータをグリッドサーチまたはランダムサーチで探す（Pro 版）。
% 各試行は search.Folds 分割の交差検証の RMSE（学習に使っていない行での予測誤差）で比べる。
%   base   ：探索しない項目の値（hyperparameter_values と同じ名前）
%   search ：Mode（'grid' / 'random'）、Trials（ランダムサーチの試行数）、Folds、Seed、
%            Candidates（項目名ごとの候補の数値ベクトル）
% 戻り値：best は最も RMSE の小さい試行の値、trace は試行ごとの表（試行順。最良の推移も含む）、
%         searched は探索した項目の {Name, Label} の一覧。
% グリッドサーチは候補のすべての組み合わせ、ランダムサーチはその中から重複なしに Trials 通りを選ぶ。
if nargin < 8, progress = []; end
MAX_TRIALS = 200;
if ~ismember(search.Mode, {'grid', 'random'}), error('search:mode', '探索の方式は grid または random を指定してください。'); end
specs = hyperparameter_specs(method); fields = fieldnames(search.Candidates)';
if isempty(fields), error('search:empty', '探索する項目の候補を1つ以上指定してください。'); end
lists = cell(1, numel(fields)); searched = struct('Name', {}, 'Label', {});
for index = 1:numel(fields)
    position = find(strcmp({specs.Name}, fields{index}), 1);
    if isempty(position), error('hyperparameter:name', '%s にはハイパーパラメータ「%s」がありません。', method, fields{index}); end
    values = unique(double(search.Candidates.(fields{index})(:)'), 'stable');
    if isempty(values), error('search:empty', '%s の候補が空です。', specs(position).Label); end
    for value = values, hyperparameter_values(method, struct(fields{index}, value)); end
    lists{index} = values; searched(end + 1) = struct('Name', fields{index}, 'Label', specs(position).Label); %#ok<AGROW>
end
sizes = cellfun(@numel, lists); total = prod(sizes);
stream = RandStream('twister', 'Seed', search.Seed);
if strcmp(search.Mode, 'grid')
    if total > MAX_TRIALS
        error('search:tooMany', 'グリッドサーチの組み合わせが%d通りあります。%d通り以下になるよう候補を減らすか、ランダムサーチを選んでください。', total, MAX_TRIALS);
    end
    order = 1:total;
else
    trials = min([search.Trials, total, MAX_TRIALS]);
    if trials < 1, error('search:trials', 'ランダムサーチの試行数は1以上にしてください。'); end
    order = randperm(stream, total, trials);
end
rows = size(inputs, 1); folds = search.Folds;
if folds < 2 || rows < 2 * folds
    error('search:folds', '探索の交差検証には、分割数（%d）の2倍以上の行が必要です（現在 %d行）。', folds, rows);
end
% 分割は試行によらず同じにする（試行どうしを同じ条件で比べるため）。
fold_id = zeros(rows, 1); fold_id(randperm(stream, rows)) = mod(0:rows - 1, folds) + 1;
count = numel(order); grid_values = NaN(count, numel(fields));
rmse = NaN(count, 1); r2 = NaN(count, 1); seconds = zeros(count, 1); status = repmat("失敗", count, 1); notes = strings(count, 1);
total_variation = sum((response - mean(response)).^2);
for trial = 1:count
    started = tic; subscripts = cell(1, numel(fields));
    [subscripts{:}] = ind2sub([sizes, 1], order(trial));
    parameters = base;
    for index = 1:numel(fields)
        parameters.(fields{index}) = lists{index}(subscripts{index}); grid_values(trial, index) = parameters.(fields{index});
    end
    try
        predicted = NaN(rows, 1);
        for fold = 1:folds
            held = fold_id == fold;
            model = ProcessRegressionModel(inputs(~held, :), response(~held), names, method, components, [], parameters);
            predicted(held) = predict(model, inputs(held, :));
        end
        rmse(trial) = sqrt(mean((response - predicted).^2));
        if total_variation > 0, r2(trial) = 1 - sum((response - predicted).^2) / total_variation; end
        status(trial) = "成功";
    catch err
        if strcmp(err.identifier, 'AnalysisApp:cancelled'), rethrow(err); end
        notes(trial) = string(err.message);
    end
    seconds(trial) = toc(started);
    if ~isempty(progress), progress(trial, count, 'ハイパーパラメータの試行'); end
end
if all(status ~= "成功")
    error('search:failed', 'ハイパーパラメータの探索で、すべての試行が失敗しました: %s', notes(1));
end
best_so_far = rmse; best_so_far(~isfinite(best_so_far)) = Inf; best_so_far = cummin(best_so_far); best_so_far(isinf(best_so_far)) = NaN;
[~, winner] = min(rmse);
best = base;
for index = 1:numel(fields), best.(fields{index}) = grid_values(winner, index); end
trace = [table((1:count)', 'VariableNames', {'試行'}), array2table(grid_values, 'VariableNames', {searched.Label}), ...
    table(rmse, r2, best_so_far, (1:count)' == winner, seconds, status, notes, ...
    'VariableNames', {'CV_RMSE', 'CV_R2', 'それまでの最良RMSE', '採用', '秒', '状態', '備考'})];
end
