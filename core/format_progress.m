function [fraction, text] = format_progress(done, total, elapsed_seconds)
% 進捗の割合と、「45%（経過 1分20秒 / 残り 約1分40秒）」の形の文を作る。
% 残り時間は、ここまでの速さが続くと仮定した目安。始まった直後は目安を出さない。
MIN_FRACTION_FOR_ESTIMATE = 0.05;
MIN_SECONDS_FOR_ESTIMATE = 3;
fraction = 0;
if total > 0, fraction = min(max(done / total, 0), 1); end
text = sprintf('%d%%（経過 %s', floor(100 * fraction), duration_text(elapsed_seconds));
if fraction >= MIN_FRACTION_FOR_ESTIMATE && fraction < 1 && elapsed_seconds >= MIN_SECONDS_FOR_ESTIMATE
    remaining = elapsed_seconds * (1 - fraction) / fraction;
    text = sprintf('%s / 残り 約%s', text, duration_text(remaining));
end
text = [text '）'];
end

function text = duration_text(seconds)
seconds = max(0, round(seconds));
if seconds < 60
    text = sprintf('%d秒', seconds);
elseif seconds < 3600
    text = sprintf('%d分%02d秒', floor(seconds / 60), mod(seconds, 60));
else
    text = sprintf('%d時間%02d分', floor(seconds / 3600), floor(mod(seconds, 3600) / 60));
end
end
