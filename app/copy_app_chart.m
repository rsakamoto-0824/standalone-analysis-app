function copied_name = copy_app_chart(charts, names)
% 表示中の図を優先し、表の表示中などはコピー対象を選択する。
COPY_RESOLUTION = 150;
copied_name = '';
valid = cellfun(@(chart) isgraphics(chart) && ...
    (~isa(chart, 'matlab.ui.control.UIAxes') || ~isempty(chart.Children)), charts);
charts = charts(valid); names = names(valid);
if isempty(charts), error('AnalysisApp:noChart', 'コピーするグラフがありません。先に解析を実行してください。'); end
visible = find(cellfun(@isDisplayed, charts));
if numel(visible) == 1
    choice = visible;
elseif numel(charts) == 1
    choice = 1;
else
    % 表示中の図を先に選んだ状態で一覧を出す（並べた図があればそれが先頭）。
    initial = 1; if ~isempty(visible), initial = visible(1); end
    [choice, accepted] = listdlg('ListString', names, 'SelectionMode', 'single', 'PromptString', 'コピーするグラフ', ...
        'ListSize', [360, 240], 'InitialValue', initial);
    if ~accepted, return; end
end
chart = charts{choice}; container = chart.Parent;
while ~isempty(container)
    if isa(container, 'matlab.ui.container.Tab'), container.Parent.SelectedTab = container; end
    if isa(container, 'matlab.ui.Figure'), break; end
    container = container.Parent;
end
drawnow;
background = [1, 1, 1]; container = chart.Parent;
while ~isempty(container)
    if isprop(container, 'BackgroundColor') && isnumeric(container.BackgroundColor)
        background = container.BackgroundColor; break;
    end
    if isa(container, 'matlab.ui.Figure'), background = container.Color; break; end
    container = container.Parent;
end
if isa(chart, 'matlab.ui.container.Panel')
    % 並べた図は、図を横につないだ画像を、見えない一時的な図に置いてからコピーする（パネルを直接渡さない）。
    picture = stitch_axes_image(chart, COPY_RESOLUTION);
    holder = uifigure('Visible', 'off', 'Position', [0, 0, size(picture, 2), size(picture, 1)]);
    holder_cleanup = onCleanup(@() delete(holder));
    ax = uiaxes(holder, 'Position', [0, 0, size(picture, 2), size(picture, 1)]);
    image(ax, picture); axis(ax, 'image'); axis(ax, 'off');
    copygraphics(ax, 'ContentType', 'image', 'Resolution', COPY_RESOLUTION);
    clear holder_cleanup;
else
    copygraphics(chart, 'ContentType', 'image', 'Resolution', COPY_RESOLUTION, 'BackgroundColor', background);
end
copied_name = names{choice};
end

function displayed = isDisplayed(chart)
displayed = true; container = chart;
while ~isempty(container)
    if isprop(container, 'Visible') && strcmp(container.Visible, 'off')
        displayed = false; return;
    end
    if isa(container, 'matlab.ui.container.Tab') && ~isequal(container.Parent.SelectedTab, container)
        displayed = false; return;
    end
    if isa(container, 'matlab.ui.Figure'), break; end
    container = container.Parent;
end
end
