function [inputs, responses, names, targets, levels] = modeling_input_data(source, mapping, targets, categorical)
% 学習に使う説明変数・目的変数を取り出す。categorical（省略可）に入れた入力列は質的変数として、水準の番号に置き換える（Pro 版の GPR）。
% levels は説明変数ごとの水準の一覧（連続の列は空）。
if nargin < 4, categorical = {}; end
targets = cellstr(string(targets(:)')); names = cellstr(string(mapping(:,2)'));
selected = cellstr(string(mapping(:,3)'));
if isempty(targets) || numel(targets) > 20 || numel(unique(targets)) ~= numel(targets)
    error('modeling:targets', '目的変数は異なる1〜20列を選択してください。');
end
if isempty(names) || numel(unique(names)) ~= numel(names) || numel(unique(selected)) ~= numel(selected)
    error('modeling:predictors', '説明変数と割当列を重複させずに指定してください。');
end
if any(ismember(selected, targets))
    error('modeling:responseLeak', '目的変数を説明変数に含めることはできません。');
end
qualitative = ismember(selected, cellstr(string(categorical)));
inputs = zeros(size(source.Cells, 1), numel(selected)); levels = cell(1, numel(selected));
if any(~qualitative), inputs(:, ~qualitative) = assign_required_columns(source, names(~qualitative), selected(~qualitative)); end
for column = find(qualitative), [inputs(:, column), levels{column}] = encode_categories(source, selected{column}); end
responses = extract_numeric_columns(source, targets);
end
