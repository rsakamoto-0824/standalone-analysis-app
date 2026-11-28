function values = order_column_values(source, name)
% 行を並べる順に使う列の値（CatBoost の並べ替え列）。
% 数値の列はその値、文字を含む列は文字の順（あいうえお順・アルファベット順）の番号を返す。空欄があれば止める。
% 日時を文字で入れた列は、「2024/01/05」のように桁をそろえておくと、文字の順が日時の順と一致する。
column = data_column(source, name);
if any(column.Missing)
    error('order_column_values:missing', '並べ替え列「%s」に空欄があります（元ファイルの行 %s）。空欄のない列を選んでください。', name, ...
        strjoin(string(source.RowNumbers(find(column.Missing, 5))'), ', '));
end
if column.IsNumeric
    values = column.Numbers;
    % 無限大などは並べる順を決められない（後の学習で分かりにくい言葉で止まらないよう、ここで止める）。
    bad = ~isfinite(values);
    if any(bad)
        error('order_column_values:nonFinite', '並べ替え列「%s」に、並べる順を決められない値（無限大など）があります（元ファイルの行 %s）。', name, ...
            strjoin(string(source.RowNumbers(find(bad, 5))'), ', '));
    end
else
    [~, ~, values] = unique(column.Labels); values = double(values);
end
end
