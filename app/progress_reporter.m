function reporter = progress_reporter(dialog, cancel_message)
% 計算の途中から呼ぶ進捗の関数 reporter(done, total, stage) を作る。
% 進捗バーの割合・経過時間・残り時間の目安を更新し、「キャンセル」が押されていたら
% AnalysisApp:cancelled のエラーで計算を止める（画面側で受けて知らせる）。
% 画面の更新（drawnow）は時間がかかるため、前の更新から MIN_INTERVAL_SECONDS 秒たったとき（と最後）だけ行う。
% キャンセルの受け取りも画面の更新のときに行うため、止まるまでの遅れはこの間隔ほど。
MIN_INTERVAL_SECONDS = 0.2;
started = tic; last_update = -Inf;
reporter = @report;
    function report(done, total, stage)
        if isempty(dialog) || ~isvalid(dialog), return; end
        elapsed = toc(started);
        if elapsed - last_update < MIN_INTERVAL_SECONDS && done < total, return; end
        last_update = elapsed;
        [fraction, summary] = format_progress(done, total, elapsed);
        dialog.Indeterminate = 'off'; dialog.Value = fraction; dialog.Message = sprintf('%s\n%s', summary, stage);
        % 押されたキャンセルを受け取るため、画面の処理を進める（limitrate では受け取れないことがあるため使わない）。
        drawnow;
        if dialog.CancelRequested, error('AnalysisApp:cancelled', '%s', cancel_message); end
    end
end
