# CSuite lingauss

線形・正規ノイズ

- 入力するファイル: [train.csv](train.csv)（ヘッダー1行目）
- 行数: 4,000 / 列数: 2
- [配布元](https://github.com/microsoft/csuite#lingauss) / [元データ](https://github.com/microsoft/csuite/releases/download/v0.1/csuite_lingauss.zip)
- ライセンス: [MIT](../../licenses/CSuite-MIT.txt)
- 取得日: 2026-11-25

観測データだけでは2変数の向きは識別できない。PCの無向辺は正常な結果であり、DirectLiNGAMの非正規性の前提を満たさない。 正解は生成過程のDAG。介入データは観測データに混ぜず、今回は収録しない。

因果探索で選ぶ列: `X0`, `X1`

正解は2変数・1辺。
[隣接行列](reference_adjacency.csv)の行Xi・列Xjが1なら **Xi → Xj**。行見出し列はなく、行順・列順とも観測データと同じ。
[辺の一覧](reference_edges.csv)はsourceが原因、targetが結果。正解ファイルはアプリの入力データに混ぜない。

`train.csv`で探索し、`val.csv`で条件選択、`test.csv`を最終確認に使用。各ファイルは元の公開分割を保持する。

## 変換と確認

- 元の列順・行順・数値を保持し、X0から始まるヘッダーを付加。NPYは17桁CSVへ変換。
- 観測データのみを収録。値の補間・標準化・外れ値削除は行わない。
- 欠損・非有限値: 0 / 完全重複行: 0
- 定数列: なし
- 定数列はデータに保持し、説明変数の推奨選択からは外す。
- 数値をCSVへ書き戻して元データと一致することを確認。

| CSV列 | 元の列名 |
|---|---|
| `X0` | `x0_0` |
| `X1` | `x1_0` |

## 出典・再配布

Tomas Geffner et al. (2022), Deep End-to-end Causal Inference, arXiv:2202.02195.

配布元のMITに従って再配布。著作権・許諾文は上記ライセンスファイルを参照。変更点は「変換と確認」に記載。
