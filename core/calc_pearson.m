function r = calc_pearson(x, y)
[x, y] = metric_inputs(x, y, 2, mfilename);
C = corrcoef(x, y);
r = C(1,2);
end
