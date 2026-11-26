# MOOT SS-D

ソフトウェア設定の計測

- 入力するファイル: [data.csv](data.csv)（ヘッダー1行目）
- 行数: 196 / 列数: 5
- [配布元](https://github.com/timm/moot/blob/ca6163861db7b231824ecabc11b15a492b75df34/optimize/config/SS-D.csv) / [元データ](https://raw.githubusercontent.com/timm/moot/ca6163861db7b231824ecabc11b15a492b75df34/optimize/config/SS-D.csv)
- ライセンス: [MIT](../../licenses/MOOT-MIT.txt)
- 取得日: 2026-11-25

原本の列名末尾の + を最大化、- を最小化として採用。設定値は離散候補を含むため、既存の候補行を比較する。SSのA/B等の詳細な物理的意味・単位は公開資料に明記されないため補わない。

## 選ぶ列

説明変数: `Max_spout`, `Spliters`, `Counters`

| 目的変数 | 方向 |
|---|---|
| `Y_Throughput` | 最大化 |
| `Y_Latency` | 最小化 |

候補内の非劣解は15行。[正解行番号](reference_pareto_indices.csv)はdata.csvの**データ先頭を1**とする番号（CSVの物理行番号ではない）。
実機や連続空間全体の大域最適解を表すものではない。

[分割表](split.csv): 同一入力を同じ群にして約80/20に分割。seed=20261125。
分割表・正解行番号を説明変数に入れない。全候補の真値は採点用に保持し、探索中のモデルへ全件を渡さない。

## 変換と確認

- 列名の空白・記号を整理。目的列にY_を付加。数値・行順は未変更。
- 欠損・非有限値: 0 / 完全重複行: 0
- 定数列: なし
- 定数列はデータに保持し、説明変数の推奨選択からは外す。
- 数値をCSVへ書き戻して元データと一致することを確認。

| CSV列 | 元の列名 |
|---|---|
| `Max_spout` | `Max_spout` |
| `Spliters` | `Spliters` |
| `Counters` | `Counters` |
| `Y_Throughput` | `Throughput+` |
| `Y_Latency` | `Latency-` |

## 出典・再配布

Tim Menzies et al. (2025), MOOT: a Repository of Many Multi-Objective Optimization Tasks, arXiv:2511.16882.

配布元のMITに従って再配布。著作権・許諾文は上記ライセンスファイルを参照。変更点は「変換と確認」に記載。
