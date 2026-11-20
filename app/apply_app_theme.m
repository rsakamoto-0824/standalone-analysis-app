function apply_app_theme(window, theme, font_size)
% 画面全体の配色をライト／ダークへそろえ、文字の大きさを設定の値にする。
% Tag が accent の部品（主要ボタン）と state の部品（確認状況の色文字）は、意味を持つ色を残す。
% 文字の大きさは、部品ごとに作成時の大きさ（標準12ポイントでの大きさ）を覚えておき、同じ比率で拡大・縮小する。
% 見出しなど最初から大きい文字も、比率を保って大きくなる。何度呼んでも大きさが積み重ならない。
% font_size を省略したとき（一部の部品だけ配色を直すとき）は、文字の大きさを変えない。
if nargin < 3, font_size = []; end
ACCENT_TAG = 'accent'; STATE_TAG = 'state'; KEEP_COLOR_TAG = 'keep-color';
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
    if ~isempty(font_size), scale_font(item, font_size); end
    % 利用者が選んだ色（ワードクラウドの色など）や、背景に合わせた文字色（相関マトリックスの数値）は変えない。
    if keeps_color(item, KEEP_COLOR_TAG), continue; end
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

function scale_font(item, font_size)
DESIGN_KEY = 'DesignFontSize'; MINIMUM_SIZE = 6;
if ~isprop(item, 'FontSize') || is_axes_label(item), return; end
try
    if ~isappdata(item, DESIGN_KEY), setappdata(item, DESIGN_KEY, item.FontSize); end
    design = getappdata(item, DESIGN_KEY);
    if isnan(design), return; end
    target = max(MINIMUM_SIZE, round(design * font_size / DESIGN_FONT_SIZE(), 1));
    if item.FontSize ~= target, item.FontSize = target; end
catch
    % タブの見出し（TabGroup）など一部の部品は、リリースによってはアプリの画面で文字の大きさを変えられない（R2022b で確認）。次から対象外にする。
    try
        setappdata(item, DESIGN_KEY, NaN);
    catch
    end
end
end

function label = is_axes_label(item)
% グラフの題名・軸ラベルは、軸の文字の大きさに合わせて自動で変わるため、個別に変えない。
label = false; parent = item.Parent;
if ~isa(item, 'matlab.graphics.primitive.Text') || isempty(parent), return; end
names = {'Title', 'Subtitle', 'XLabel', 'YLabel', 'ZLabel', 'Label'};
for index = 1:numel(names)
    if isprop(parent, names{index}) && isequal(item, parent.(names{index})), label = true; return; end
end
end

function value = DESIGN_FONT_SIZE()
% 各部品の大きさを決めたときの基準（MATLAB の画面の標準）。
value = 12;
end

function keep = keeps_color(item, tag)
% Tag が keep-color の部品、または appdata の KeepColor を持つ部品（Tag を変えられないワードクラウドなど）は色を変えない。
keep = (isprop(item, 'Tag') && strcmp(item.Tag, tag)) || (isprop(item, 'ApplicationData') && isappdata(item, 'KeepColor'));
end
