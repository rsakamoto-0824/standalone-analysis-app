# CSuite large_backdoor

9変数・バックドア

- 入力するファイル: [train.csv](train.csv)（ヘッダー1行目）
- 行数: 2,000 / 列数: 9
- [配布元](https://github.com/microsoft/csuite#large_backdoor) / [元データ](https://github.com/microsoft/csuite/releases/download/v0.1/csuite_large_backdoor.zip)
- ライセンス: [MIT](../../licenses/CSuite-MIT.txt)
- 取得日: 2026-11-25

交絡調整の候補が複数ある構造。正解は同梱adj_matrix.csvを採用。配布元READMEは10辺と記すが、v0.1の行列は9辺のため、実ファイルを基準にする。 正解は生成過程のDAG。介入データは観測データに混ぜず、今回は収録しない。 配布元の概要は学習4,000行と記すが、このv0.1ファイルの学習行数は2000行。収録数は実ファイルを基準にする。

因果探索で選ぶ列: `X0`, `X1`, `X2`, `X3`, `X4`, `X5`, `X6`, `X7`, `X8`

正解は9変数・9辺。
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
| `X2` | `x2_0` |
| `X3` | `x3_0` |
| `X4` | `x4_0` |
| `X5` | `x5_0` |
| `X6` | `x6_0` |
| `X7` | `x7_0` |
| `X8` | `x8_0` |

## 出典・再配布

Tomas Geffner et al. (2022), Deep End-to-end Causal Inference, arXiv:2202.02195.

配布元のMITに従って再配布。著作権・許諾文は上記ライセンスファイルを参照。変更点は「変換と確認」に記載。
