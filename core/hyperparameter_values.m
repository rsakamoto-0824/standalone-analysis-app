function values = hyperparameter_values(method, given)
% 既定値に、指定した値（given の同名フィールド）を重ねて、範囲と整数を確かめる。
% given にない項目は既定値を使う。一覧にない名前は誤りとして止める（綴りの誤りを見逃さないため）。
if nargin < 2 || isempty(given), given = struct(); end
specs = hyperparameter_specs(method); values = struct();
for index = 1:numel(specs), values.(specs(index).Name) = specs(index).Default; end
names = fieldnames(given);
for index = 1:numel(names)
    name = names{index};
    if strcmp(name, 'Seed'), values.Seed = given.Seed; continue; end
    position = find(strcmp({specs.Name}, name), 1);
    if isempty(position), error('hyperparameter:name', '%s にはハイパーパラメータ「%s」がありません。', method, name); end
    value = given.(name); row = specs(position);
    if ~isnumeric(value) || ~isscalar(value) || ~isfinite(value) || value < row.Limits(1) || value > row.Limits(2) || ...
            (row.Integer && value ~= round(value))
        kind = '数値'; if row.Integer, kind = '整数'; end
        error('hyperparameter:value', '%s は %g〜%g の%sで指定してください（指定値: %s）。', row.Label, row.Limits(1), row.Limits(2), kind, mat2str(value));
    end
    values.(name) = double(value);
end
if ~isfield(values, 'Seed'), values.Seed = 0; end
end
