function apply_app_theme(window, theme)
if strcmp(theme, 'ダーク')
    background = [0.09, 0.12, 0.18]; surface = [0.14, 0.18, 0.25]; text = [0.92, 0.95, 0.98];
else
    background = [0.94, 0.96, 0.98]; surface = [1, 1, 1]; text = [0.12, 0.17, 0.25];
end
window.Color = background;
objects = findall(window);
for index = 1:numel(objects)
    item = objects(index);
    if isa(item, 'matlab.ui.control.UIAxes')
        item.Color = surface; item.XColor = text; item.YColor = text;
        item.Title.Color = text; item.XLabel.Color = text; item.YLabel.Color = text;
    elseif isa(item, 'matlab.graphics.illustration.ColorBar')
        item.Color = text;
    elseif isa(item, 'matlab.ui.control.Table')
        item.BackgroundColor = [surface; background]; item.ForegroundColor = text;
    else
        if isprop(item, 'BackgroundColor'), item.BackgroundColor = background; end
        if isprop(item, 'FontColor'), item.FontColor = text; end
        if isa(item, 'matlab.graphics.chart.WordCloudChart')
            item.Color = text;
        end
    end
end
end
