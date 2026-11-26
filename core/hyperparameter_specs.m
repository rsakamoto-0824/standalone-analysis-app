function specs = hyperparameter_specs(method)
% 回帰方式ごとのハイパーパラメータの一覧。
% 各行は Name（内部名）、Label（画面の名前）、Default（既定値）、Limits（範囲）、Integer（整数か）、
% Candidates（探索の初期候補。空なら探索せず Default を使う）、Short（方式名の後ろに付ける略記。空なら付けない）、
% Description（説明）を持つ。
% 探索の初期候補は、各方式で効きやすい2つだけに3通りずつ入れる（初期状態の探索を9通りに抑えるため）。
switch method
    case 'forest'
        specs = [
            spec('NumTrees', '木の本数', 100, [10, 1000], true, [], '本', '作る回帰木の数。多いほど予測が安定し、学習に時間がかかります。')
            spec('MinLeafSize', '葉の最小行数', 5, [1, 100], true, [1, 5, 10], '', '葉（末端）に残す最少の行数。大きいほど滑らかで、過学習しにくくなります。')
            spec('VariableFraction', '分岐で使う変数の割合', 1 / 3, [0.05, 1], false, [1 / 3, 2 / 3, 1], '', '分岐ごとに候補にする説明変数の割合。1にするとバギング木と同じです。')];
    case 'bagging'
        specs = [
            spec('NumTrees', '木の本数', 100, [10, 1000], true, [50, 100, 200], '本', '作る回帰木の数。多いほど予測が安定し、学習に時間がかかります。')
            spec('MinLeafSize', '葉の最小行数', 5, [1, 100], true, [1, 5, 10], '', '葉（末端）に残す最少の行数。大きいほど滑らかで、過学習しにくくなります。')];
    case 'xgboost'
        specs = [
            spec('NumRounds', '学習の回数（木の本数）', 200, [10, 3000], true, [], '回', '木を1本ずつ足していく回数。学習率を小さくしたときは増やします。')
            spec('LearningRate', '学習率 η', 0.1, [0.001, 1], false, [0.05, 0.1, 0.3], '', '1本の木の予測をどれだけ足すか。小さいほど慎重に学習します。')
            spec('MaxDepth', '木の深さ', 4, [1, 10], true, [2, 4, 6], '深さ', '1本の木の分岐の段数。深いほど複雑な関係を表せます。')
            spec('Lambda', 'L2正則化 λ', 1, [0, 1000], false, [], '', '葉の値を0へ引き寄せる強さ。大きいほど過学習しにくくなります。')
            spec('Gamma', '分岐に必要な改善 γ', 0, [0, 1000], false, [], '', 'この値より改善しない分岐は作りません。大きいほど木が小さくなります。')
            spec('MinChildWeight', '葉の最小行数', 1, [1, 1000], true, [], '', '分岐後の各側に残す最少の行数（二乗誤差では最小重みと同じ）。')
            spec('Subsample', '行の抽出割合', 1, [0.1, 1], false, [], '', '木ごとに使う行の割合。1未満にすると乱数で行を選びます。')
            spec('ColsampleByTree', '列の抽出割合', 1, [0.1, 1], false, [], '', '木ごとに使う説明変数の割合。1未満にすると乱数で列を選びます。')
            spec('MaxBins', '値の区間数', 64, [8, 256], true, [], '', '分岐の候補を作るために、各説明変数を分ける区間の数（ヒストグラム法）。')];
    case 'lightgbm'
        specs = [
            spec('NumRounds', '学習の回数（木の本数）', 200, [10, 3000], true, [], '回', '木を1本ずつ足していく回数。学習率を小さくしたときは増やします。')
            spec('LearningRate', '学習率', 0.1, [0.001, 1], false, [0.05, 0.1, 0.3], '', '1本の木の予測をどれだけ足すか。小さいほど慎重に学習します。')
            spec('NumLeaves', '葉の数', 15, [2, 256], true, [7, 15, 31], '葉', '1本の木の葉の数の上限。効果の大きい葉から順に分けます（葉ごとの成長）。')
            spec('MinDataInLeaf', '葉の最小行数', 5, [1, 1000], true, [], '', '葉に残す最少の行数。大きいほど過学習しにくくなります。')
            spec('Lambda', 'L2正則化 λ', 0, [0, 1000], false, [], '', '葉の値を0へ引き寄せる強さ。')
            spec('FeatureFraction', '列の抽出割合', 1, [0.1, 1], false, [], '', '木ごとに使う説明変数の割合。')
            spec('BaggingFraction', '行の抽出割合', 1, [0.1, 1], false, [], '', '木ごとに使う行の割合。')
            spec('MaxBins', '値の区間数', 64, [8, 256], true, [], '', '各説明変数を分ける区間の数（ヒストグラム法）。')];
    case 'catboost'
        specs = [
            spec('NumRounds', '学習の回数（木の本数）', 200, [10, 3000], true, [], '回', '木を1本ずつ足していく回数。')
            spec('LearningRate', '学習率', 0.1, [0.001, 1], false, [0.05, 0.1, 0.3], '', '1本の木の予測をどれだけ足すか。')
            spec('Depth', '木の深さ（対称木）', 4, [1, 8], true, [3, 4, 6], '深さ', '同じ段では全ての枝が同じ条件で分かれる木（対称木）の段数。葉の数は2の深さ乗です。')
            spec('L2LeafReg', 'L2正則化', 3, [0, 1000], false, [], '', '葉の値を0へ引き寄せる強さ。')
            spec('Subsample', '行の抽出割合', 1, [0.1, 1], false, [], '', '木ごとに使う行の割合。')
            spec('MaxBins', '値の区間数', 64, [8, 256], true, [], '', '各説明変数を分ける区間の数。')
            spec('OrderedBoosting', '順序付きブースティング（1=使う）', 0, [0, 1], true, [], '', ['1にすると、各行の勾配を、並べた順で前の行だけで学習したモデルから求めます（Ordered Boosting）。' ...
                '目的変数の情報が漏れにくくなり、行数の少ないデータで過学習しにくくなります。並べる順は「CatBoost の並べ替え列」で指定します。'])];
    case 'ebm'
        specs = [
            spec('OuterRounds', '繰り返し回数', 300, [10, 5000], true, [], '回', '全ての説明変数を1つずつ順に学習する周回の数。')
            spec('LearningRate', '学習率', 0.05, [0.001, 1], false, [0.02, 0.05, 0.1], '', '1回の更新の大きさ。小さいほど滑らかな形になります。')
            spec('MaxLeaves', '1変数の木の葉の数', 3, [2, 16], true, [], '', '1回の更新で、1つの説明変数を分ける区間の数。')
            spec('MinSamplesLeaf', '葉の最小行数', 2, [1, 100], true, [], '', '1回の更新で、各区間に残す最少の行数。')
            spec('Interactions', '交互作用の組の数', 3, [0, 20], true, [0, 3, 6], '交互作用', '2つの説明変数の組み合わせの効果を何組まで入れるか（GA2M）。0なら各変数の効果の和だけ（GAM）。')
            spec('MaxBins', '値の区間数', 32, [8, 256], true, [], '', '1変数の効果を表す区間の数。')
            spec('InteractionBins', '交互作用の区間数', 8, [4, 32], true, [], '', '交互作用の効果を表す、各変数の区間の数。')];
    otherwise
        error('hyperparameter_specs:method', 'ハイパーパラメータを持たない回帰方式です: %s', method);
end
end

function row = spec(name, label, default, limits, integer, candidates, short, description)
row = struct('Name', name, 'Label', label, 'Default', default, 'Limits', limits, 'Integer', integer, ...
    'Candidates', candidates, 'Short', short, 'Description', description);
end
