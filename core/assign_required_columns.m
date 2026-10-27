function matrix = assign_required_columns(source, required_names, selected_names, allow_missing)
if nargin < 3 || isempty(selected_names), selected_names = required_names; end
if nargin < 4, allow_missing = false; end
if numel(required_names) ~= numel(selected_names)
    error('assign_required_columns:columnCount', '必須変数と割当列の数が一致しません。');
end
matrix = extract_numeric_columns(source, selected_names, allow_missing);
end
