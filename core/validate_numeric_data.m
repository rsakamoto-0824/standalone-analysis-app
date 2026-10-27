function validate_numeric_data(values, name, identifier, allow_missing)
if nargin < 4
    allow_missing = false;
end
if ~isnumeric(values) || ~ismatrix(values) || ~isreal(values) || isempty(values)
    error([identifier ':invalidNumericData'], '%s は空でない実数行列で渡してください。', name);
end
% TODO(要確認 Q-09) 欠損行を fitrgp に暗黙に除去させない。
missing_rows = find(any(isnan(values), 2));
if ~allow_missing && ~isempty(missing_rows)
    error([identifier ':missingRows'], '%s に欠損値を含む行があります: %s', ...
        name, strjoin(string(missing_rows'), ', '));
end
infinite_rows = find(any(isinf(values), 2));
if ~isempty(infinite_rows)
    error([identifier ':infiniteRows'], '%s に無限大を含む行があります: %s', ...
        name, strjoin(string(infinite_rows'), ', '));
end
end
