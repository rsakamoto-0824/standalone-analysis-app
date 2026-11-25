# Energy Efficiency

建物エネルギーシミュレーション

- 入力するファイル: [data.csv](data.csv)（ヘッダー1行目）
- 行数: 768 / 列数: 10
- [配布元](https://archive.ics.uci.edu/dataset/242/energy+efficiency) / [元データ](https://archive.ics.uci.edu/static/public/242/energy+efficiency.zip)
- ライセンス: [CC-BY-4.0](../../licenses/CC-BY-4.0.txt)
- 取得日: 2026-11-25

2つの負荷を最小化する例。形状列は互いに制約されるので、公開済みの候補行の範囲で比較する。向き・窓配置は離散値。熱負荷の単位はUCI変数表に明記されていないため変換しない。

## 選ぶ列

説明変数: `RelativeCompactness`, `SurfaceArea`, `WallArea`, `RoofArea`, `OverallHeight`, `Orientation`, `GlazingArea`, `GlazingAreaDistribution`

| 目的変数 | 方向 |
|---|---|
| `Y_HeatingLoad` | 最小化 |
| `Y_CoolingLoad` | 最小化 |

候補内の非劣解は2行。[正解行番号](reference_pareto_indices.csv)はdata.csvの**データ先頭を1**とする番号（CSVの物理行番号ではない）。
実機や連続空間全体の大域最適解を表すものではない。

[分割表](split.csv): 同一入力を同じ群にして約80/20に分割。seed=20261125。
分割表・正解行番号を説明変数に入れない。全候補の真値は採点用に保持し、探索中のモデルへ全件を渡さない。

## 変換と確認

- XLSXの非空データ行のみをCSV化。単位・数値は未変更。
- 欠損・非有限値: 0 / 完全重複行: 0
- 定数列: なし
- 定数列はデータに保持し、説明変数の推奨選択からは外す。
- 数値をCSVへ書き戻して元データと一致することを確認。

| CSV列 | 元の列名 |
|---|---|
| `RelativeCompactness` | `X1` |
| `SurfaceArea` | `X2` |
| `WallArea` | `X3` |
| `RoofArea` | `X4` |
| `OverallHeight` | `X5` |
| `Orientation` | `X6` |
| `GlazingArea` | `X7` |
| `GlazingAreaDistribution` | `X8` |
| `Y_HeatingLoad` | `Y1` |
| `Y_CoolingLoad` | `Y2` |

## 出典・再配布

A. Tsanas and A. Xifara (2012), Energy Efficiency, UCI, doi:10.24432/C51307.

配布元のCC-BY-4.0に従って再配布。著作権・許諾文は上記ライセンスファイルを参照。変更点は「変換と確認」に記載。
