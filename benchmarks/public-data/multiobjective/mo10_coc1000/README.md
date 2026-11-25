# MOOT coc1000

開発プロセスのシミュレーション

- 入力するファイル: [data.csv](data.csv)（ヘッダー1行目）
- 行数: 1,000 / 列数: 25
- [配布元](https://github.com/timm/moot/blob/ca6163861db7b231824ecabc11b15a492b75df34/optimize/process/coc1000.csv) / [元データ](https://raw.githubusercontent.com/timm/moot/ca6163861db7b231824ecabc11b15a492b75df34/optimize/process/coc1000.csv)
- ライセンス: [MIT](../../licenses/MOOT-MIT.txt)
- 取得日: 2026-11-25

公開済みシミュレーションの候補表。原本の列名末尾 + / - の目的方向を保持。 LOC・AEXP・PLExも配布元が目的列としているため、5目的として保持する。実プロジェクトの推奨目標を意味しない。

## 選ぶ列

説明変数: `ACAP`, `ARCH`, `CPLx`, `DATA`, `DOCU`, `FLEx`, `LTEx`, `PCAP`, `PCON`, `PMAT`, `PREC`, `PVOL`, `RELY`, `RUSE`, `SCED`, `SITE`, `STOR`, `TEAM`, `TIME`, `TOOL`

| 目的変数 | 方向 |
|---|---|
| `Y_LOC` | 最大化 |
| `Y_AEXP` | 最小化 |
| `Y_PLEx` | 最小化 |
| `Y_RISK` | 最小化 |
| `Y_EFFORT` | 最小化 |

候補内の非劣解は144行。[正解行番号](reference_pareto_indices.csv)はdata.csvの**データ先頭を1**とする番号（CSVの物理行番号ではない）。
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
| `Y_LOC` | `LOC+` |
| `ACAP` | `ACAP` |
| `Y_AEXP` | `AEXP-` |
| `ARCH` | `ARCH` |
| `CPLx` | `CPLx` |
| `DATA` | `DATA` |
| `DOCU` | `DOCU` |
| `FLEx` | `FLEx` |
| `LTEx` | `LTEx` |
| `PCAP` | `PCAP` |
| `PCON` | `PCON` |
| `Y_PLEx` | `PLEx-` |
| `PMAT` | `PMAT` |
| `PREC` | `PREC` |
| `PVOL` | `PVOL` |
| `RELY` | `RELY` |
| `RUSE` | `RUSE` |
| `SCED` | `SCED` |
| `SITE` | `SITE` |
| `STOR` | `STOR` |
| `TEAM` | `TEAM` |
| `TIME` | `TIME` |
| `TOOL` | `TOOL` |
| `Y_RISK` | `RISK-` |
| `Y_EFFORT` | `EFFORT-` |

## 出典・再配布

Tim Menzies et al. (2025), MOOT: a Repository of Many Multi-Objective Optimization Tasks, arXiv:2511.16882.

配布元のMITに従って再配布。著作権・許諾文は上記ライセンスファイルを参照。変更点は「変換と確認」に記載。
