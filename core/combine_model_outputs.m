function output = combine_model_outputs(parts)
% 元データの説明変数・目的変数と、予測値・残差・SHAP値を1つの表にまとめる（CSV / Excel の1ファイルで出力するため）。
%   parts.SourceRows    元ファイルの行番号（N×1）
%   parts.InputColumns  説明変数の列名（入力ファイルの列名、1×P）
%   parts.Inputs        説明変数の値（N×P）
%   parts.TargetName    目的変数・実測の列名（なければ ''）
%   parts.Actual        実測値（N×1、なければ []）
%   parts.Predicted     予測値（N×1）
%   parts.Extra         予測値の後ろへ加える列（N行の table、任意）
%   parts.ShapColumns   SHAP値の列名（1×Q、任意）
%   parts.ShapValues    SHAP値（M×Q、M≦N。先頭M行だけ計算した場合は残りを NaN にする）
% 列名は入力ファイルの列名を使い、重複する場合だけ番号を付けて区別する。
rows = numel(parts.SourceRows);
if size(parts.Inputs, 1) ~= rows || numel(parts.Predicted) ~= rows
    error('combine_model_outputs:rows', '説明変数・予測値の行数と、元ファイルの行番号の数を一致させてください。');
end
if size(parts.Inputs, 2) ~= numel(parts.InputColumns)
    error('combine_model_outputs:columns', '説明変数の列数と列名の数を一致させてください。');
end
target = ''; if isfield(parts, 'TargetName'), target = char(parts.TargetName); end
actual = []; if isfield(parts, 'Actual'), actual = parts.Actual(:); end
if ~isempty(actual) && numel(actual) ~= rows
    error('combine_model_outputs:rows', '実測値の行数を一致させてください。');
end
names = [{'SourceRow'}, cellstr(string(parts.InputColumns(:)'))];
values = [{parts.SourceRows(:)}, num2cell(parts.Inputs, 1)];
predicted_name = '予測値'; residual_name = '残差';
if ~isempty(target), predicted_name = [target '_予測値']; residual_name = [target '_残差']; end
if ~isempty(actual)
    names = [names, {target, predicted_name, residual_name}];
    values = [values, {actual, parts.Predicted(:), actual - parts.Predicted(:)}];
else
    names = [names, {predicted_name}]; values = [values, {parts.Predicted(:)}];
end
if isfield(parts, 'Extra') && ~isempty(parts.Extra)
    if height(parts.Extra) ~= rows, error('combine_model_outputs:rows', '追加する列の行数を一致させてください。'); end
    names = [names, parts.Extra.Properties.VariableNames];
    values = [values, cellfun(@(name) parts.Extra.(name), parts.Extra.Properties.VariableNames, 'UniformOutput', false)];
end
if isfield(parts, 'ShapColumns') && ~isempty(parts.ShapColumns)
    shap = parts.ShapValues;
    if size(shap, 2) ~= numel(parts.ShapColumns) || size(shap, 1) > rows
        error('combine_model_outputs:shap', 'SHAP値の列数・行数が説明変数と一致しません。');
    end
    padded = NaN(rows, size(shap, 2)); padded(1:size(shap, 1), :) = shap;
    names = [names, cellstr(string(parts.ShapColumns(:)'))]; values = [values, num2cell(padded, 1)];
end
names = matlab.lang.makeUniqueStrings(names);
output = table(values{:}, 'VariableNames', names);
end
