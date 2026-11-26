# GraN-DAG ER 20変数・疎

公開済み非線形GPシミュレーション

- 入力するファイル: [data.csv](data.csv)（ヘッダー1行目）
- 行数: 1,000 / 列数: 20
- [配布元](https://github.com/kurowasan/GraN-DAG/tree/d86ab59325730d742d67b4a1c964bde5145a9b9c/data) / [元データ](https://raw.githubusercontent.com/kurowasan/GraN-DAG/d86ab59325730d742d67b4a1c964bde5145a9b9c/data/data_p20_e20_n1000_GP.zip)
- ライセンス: [MIT](../../licenses/GraN-DAG-MIT.txt)
- 取得日: 2026-11-25

各公開パッケージのreplicate 1（data1/DAG1/CPDAG1）を1件として採用。独自生成・再学習は行わない。非線形GPのため現在の偏相関PC・線形DirectLiNGAMに対するストレステスト。公開元のDAG・CPDAGをともに収録する。

因果探索で選ぶ列: `X0`, `X1`, `X2`, `X3`, `X4`, `X5`, `X6`, `X7`, `X8`, `X9`, `X10`, `X11`, `X12`, `X13`, `X14`, `X15`, `X16`, `X17`, `X18`, `X19`

正解は20変数・21辺。
[隣接行列](reference_adjacency.csv)の行Xi・列Xjが1なら **Xi → Xj**。行見出し列はなく、行順・列順とも観測データと同じ。
[辺の一覧](reference_edges.csv)はsourceが原因、targetが結果。正解ファイルはアプリの入力データに混ぜない。

[CPDAG](reference_cpdag.csv)は公開元のマルコフ同値類の参照。両方向が1の辺は向き未確定を表す。
PCの未確定辺を誤って2本の有向辺として数えない。

## 変換と確認

- 元の列順・行順・数値を保持し、X0から始まるヘッダーを付加。NPYは17桁CSVへ変換。
- 観測データのみを収録。値の補間・標準化・外れ値削除は行わない。
- 欠損・非有限値: 0 / 完全重複行: 0
- 定数列: なし
- 定数列はデータに保持し、説明変数の推奨選択からは外す。
- 数値をCSVへ書き戻して元データと一致することを確認。

| CSV列 | 元の列名 |
|---|---|
| `X0` | `source_column_0` |
| `X1` | `source_column_1` |
| `X2` | `source_column_2` |
| `X3` | `source_column_3` |
| `X4` | `source_column_4` |
| `X5` | `source_column_5` |
| `X6` | `source_column_6` |
| `X7` | `source_column_7` |
| `X8` | `source_column_8` |
| `X9` | `source_column_9` |
| `X10` | `source_column_10` |
| `X11` | `source_column_11` |
| `X12` | `source_column_12` |
| `X13` | `source_column_13` |
| `X14` | `source_column_14` |
| `X15` | `source_column_15` |
| `X16` | `source_column_16` |
| `X17` | `source_column_17` |
| `X18` | `source_column_18` |
| `X19` | `source_column_19` |

## 出典・再配布

Sébastien Lachapelle, Philippe Brouillard, Tristan Deleu and Simon Lacoste-Julien (2020), Gradient-Based Neural DAG Learning, ICLR 2020, arXiv:1906.02226.

配布元のMITに従って再配布。著作権・許諾文は上記ライセンスファイルを参照。変更点は「変換と確認」に記載。
