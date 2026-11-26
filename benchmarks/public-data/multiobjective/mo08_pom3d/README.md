# MOOT pom3d

開発プロセスのシミュレーション

- 入力するファイル: [data.csv](data.csv)（ヘッダー1行目）
- 行数: 500 / 列数: 12
- [配布元](https://github.com/timm/moot/blob/ca6163861db7b231824ecabc11b15a492b75df34/optimize/process/pom3d.csv) / [元データ](https://raw.githubusercontent.com/timm/moot/ca6163861db7b231824ecabc11b15a492b75df34/optimize/process/pom3d.csv)
- ライセンス: [MIT](../../licenses/MOOT-MIT.txt)
- 取得日: 2026-11-25

公開済みシミュレーションの候補表。原本の列名末尾 + / - の目的方向を保持。 Scoreは原本で最小化と指定されているため、その符号を保持し、完了率の最大化へ読み替えない。

## 選ぶ列

説明変数: `Culture`, `Criticality`, `Criticality_Modifier`, `Initial_Known`, `Inter_Dependency`, `Dynamism`, `Size`, `Plan`, `Team_Size`

| 目的変数 | 方向 |
|---|---|
| `Y_Cost` | 最小化 |
| `Y_Score` | 最小化 |
| `Y_Idle` | 最小化 |

候補内の非劣解は7行。[正解行番号](reference_pareto_indices.csv)はdata.csvの**データ先頭を1**とする番号（CSVの物理行番号ではない）。
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
| `Culture` | `Culture` |
| `Criticality` | `Criticality` |
| `Criticality_Modifier` | `Criticality Modifier` |
| `Initial_Known` | `Initial Known` |
| `Inter_Dependency` | `Inter-Dependency` |
| `Dynamism` | `Dynamism` |
| `Size` | `Size` |
| `Plan` | `Plan` |
| `Team_Size` | `Team Size` |
| `Y_Cost` | `Cost-` |
| `Y_Score` | `Score-` |
| `Y_Idle` | `Idle-` |

## 出典・再配布

Tim Menzies et al. (2025), MOOT: a Repository of Many Multi-Objective Optimization Tasks, arXiv:2511.16882.

配布元のMITに従って再配布。著作権・許諾文は上記ライセンスファイルを参照。変更点は「変換と確認」に記載。
