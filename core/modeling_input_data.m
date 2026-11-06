function [inputs, responses, names, targets] = modeling_input_data(source, mapping, targets)
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
inputs = assign_required_columns(source, names, selected);
responses = extract_numeric_columns(source, targets);
end
