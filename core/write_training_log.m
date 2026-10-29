function write_training_log(log_folder, entry)
% TODO(要確認 Q-04) モデル別の付帯情報は作らず、運用ログだけを集約する。
% TODO(要確認 Q-10) 目標時間は設けず、実際の処理時間だけを記録する。
allowed = {'Function', 'InputFile', 'Rows', 'Kernel', 'FitMethod', 'SavePath', ...
    'Verification', 'PredictorNames', 'ResponseName', 'Status', 'ElapsedSeconds', 'Folds', 'Seed'};
record = struct('DateTime', char(datetime('now', 'TimeZone', 'Asia/Tokyo', ...
    'Format', 'yyyy-MM-dd HH:mm:ss XXX')));
for index = 1:numel(allowed)
    name = allowed{index};
    if isfield(entry, name), record.(name) = entry.(name); end
end
if ~isfolder(log_folder), mkdir(log_folder); end
fullName = fullfile(log_folder, 'training.jsonl');
[file_id, message] = fopen(fullName, 'a', 'n', 'UTF-8');
if file_id < 0
    error('write_training_log:openFailed', 'ログファイルを開けません。%s', message);
end
cleanup = onCleanup(@() fclose(file_id));
if fprintf(file_id, '%s\n', jsonencode(record)) < 0
    error('write_training_log:writeFailed', 'ログの書込みに失敗しました。');
end
end
