function lines = status_lines(value)
% char を列ベクトルへ変換すると1文字ずつ別行になるため、先に string 化する。
if ischar(value)
    value = string(value);
end
lines = cellstr(splitlines(join(string(value(:)), newline)));
lines = lines(:);
end
