function apply_app_theme(window, theme)
% 画面全体の配色をライト／ダークへそろえる。
% Tag が accent の部品（主要ボタン）と state の部品（確認状況の色文字）は、意味を持つ色を残す。
ACCENT_TAG = 'accent'; STATE_TAG = 'state';
ACCENT_COLOR = [0.12, 0.35, 0.58]; ACCENT_TEXT = [1, 1, 1];
TAB_TEXT = [0.12, 0.17, 0.25];
if strcmp(theme, 'ダーク')
    background = [0.09, 0.12, 0.18]; surface = [0.14, 0.18, 0.25]; text = [0.92, 0.95, 0.98];
else
    background = [0.94, 0.96, 0.98]; surface = [1, 1, 1]; text = [0.12, 0.17, 0.25];
end
if isprop(window, 'Color'), window.Color = background; end
objects = findall(window);
for index = 1:numel(objects)
    item = objects(index);
    if isa(item, 'matlab.ui.control.UIAxes')
        item.Color = surface; item.XColor = text; item.YColor = text;
        item.Title.Color = text; item.XLabel.Color = text; item.YLabel.Color = text;
    elseif isa(item, 'matlab.graphics.illustration.ColorBar')
        item.Color = text;
    elseif isa(item, 'matlab.graphics.illustration.Legend')
        item.Color = surface; item.TextColor = text; item.EdgeColor = text;
    elseif isa(item, 'matlab.graphics.primitive.Text')
        item.Color = text;
    elseif isa(item, 'matlab.ui.control.Table')
        item.BackgroundColor = [surface; background]; item.ForegroundColor = text;
    elseif isa(item, 'matlab.ui.container.TabGroup')
        % ネイティブなタブ見出しは明るい背景を保つため、文字もそれに合わせる。
        if isprop(item, 'FontColor'), item.FontColor = TAB_TEXT; end
    elseif isa(item, 'matlab.ui.container.Tab')
        item.BackgroundColor = background;
        if isprop(item, 'FontColor'), item.FontColor = TAB_TEXT; end
    elseif isprop(item, 'Tag') && strcmp(item.Tag, ACCENT_TAG)
        item.BackgroundColor = ACCENT_COLOR; item.FontColor = ACCENT_TEXT;
    elseif isprop(item, 'Tag') && strcmp(item.Tag, STATE_TAG)
        item.BackgroundColor = background; item.FontColor = state_color(item.UserData, theme);
    else
        if isprop(item, 'BackgroundColor'), item.BackgroundColor = background; end
        if isprop(item, 'FontColor'), item.FontColor = text; end
        if isprop(item, 'ForegroundColor') && isa(item, 'matlab.ui.container.Panel'), item.ForegroundColor = text; end
        if isa(item, 'matlab.graphics.chart.WordCloudChart')
            item.Color = text;
        end
    end
end
end

function color = state_color(state, theme)
% 確認済み（ok）は緑、未確認（wait）は橙。背景に合わせて明るさを変える。
dark = strcmp(theme, 'ダーク');
if isequal(state, 'ok')
    color = [0.10, 0.50, 0.25]; if dark, color = [0.45, 0.85, 0.55]; end
else
    color = [0.75, 0.38, 0.05]; if dark, color = [1.00, 0.72, 0.35]; end
end
end
