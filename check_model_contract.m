function checks = check_model_contract()
% 原仕様の正本と学習・保存本体を比較する。空行と行頭の字下げだけを除外する。
root = fileparts(mfilename('fullpath'));
specification = fileread(fullfile(root, 'docs', 'specification.md'));
blocks = regexp(specification, '```matlab\s*\n([\s\S]*?)```', 'tokens');
names = {'train_apc_model.m', 'train_swing_curve_model.m', 'train_in_plane_model.m', ...
    'train_generic_gpr_model.m', 'save_train_model.m'};
canonical = {};
for index = 1:numel(blocks)
    text = blocks{index}{1};
    if contains(text, 'Train_Model = fitrgp') || contains(text, 'function save_train_model(')
        canonical{end + 1} = normalize(text); %#ok<AGROW>
    end
end
if numel(canonical) ~= numel(names)
    error('check_model_contract:missingReference', '原仕様の正本コード5件を抽出できません。');
end
passed = false(numel(names), 1);
for index = 1:numel(names)
    source = normalize(fileread(fullfile(root, 'core', names{index})));
    passed(index) = contains(source, canonical{index});
end
checks = table(names(:), passed, 'VariableNames', {'SourceFile', 'CanonicalBodyUnchanged'});
disp(checks);
if ~all(passed)
    error('check_model_contract:modifiedBody', '学習・保存本体が原仕様の正本コードと一致しません。');
end
end

function text = normalize(text)
lines = strtrim(splitlines(string(text)));
text = strjoin(lines(strlength(lines) > 0), newline);
end
