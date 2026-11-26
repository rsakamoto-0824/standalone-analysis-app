# Concrete Slump Test

コンクリート配合の実測

- 入力するファイル: [data.csv](data.csv)（ヘッダー1行目）
- 行数: 103 / 列数: 10
- [配布元](https://archive.ics.uci.edu/dataset/182/concrete+slump+test) / [元データ](https://archive.ics.uci.edu/static/public/182/concrete+slump+test.zip)
- ライセンス: [CC-BY-4.0](../../licenses/CC-BY-4.0.txt)
- 取得日: 2026-11-25

成分量はkg/m^3、Slump/Flowはcm、28日圧縮強度はMPa。3値の最大化は動作比較用の設定であり、実務ではSlump/Flowに目標範囲を設ける。元のNo列は測定IDなので入力から除いた。配合量の独立な連続変更を推奨するデータではない。

## 選ぶ列

説明変数: `Cement`, `Slag`, `FlyAsh`, `Water`, `SP`, `CoarseAggregate`, `FineAggregate`

| 目的変数 | 方向 |
|---|---|
| `Y_Slump_cm` | 最大化 |
| `Y_Flow_cm` | 最大化 |
| `Y_CompressiveStrength_MPa` | 最大化 |

候補内の非劣解は4行。[正解行番号](reference_pareto_indices.csv)はdata.csvの**データ先頭を1**とする番号（CSVの物理行番号ではない）。
実機や連続空間全体の大域最適解を表すものではない。

[分割表](split.csv): 同一入力を同じ群にして約80/20に分割。seed=20261125。
分割表・正解行番号を説明変数に入れない。全候補の真値は採点用に保持し、探索中のモデルへ全件を渡さない。

## 変換と確認

- 元のNo列を除外。その他の値は未変更。
- 欠損・非有限値: 0 / 完全重複行: 0
- 定数列: なし
- 定数列はデータに保持し、説明変数の推奨選択からは外す。
- 数値をCSVへ書き戻して元データと一致することを確認。

| CSV列 | 元の列名 |
|---|---|
| `Cement` | `Cement` |
| `Slag` | `Slag` |
| `FlyAsh` | `Fly ash` |
| `Water` | `Water` |
| `SP` | `SP` |
| `CoarseAggregate` | `Coarse Aggr.` |
| `FineAggregate` | `Fine Aggr.` |
| `Y_Slump_cm` | `SLUMP(cm)` |
| `Y_Flow_cm` | `FLOW(cm)` |
| `Y_CompressiveStrength_MPa` | `Compressive Strength (28-day)(Mpa)` |

## 出典・再配布

I-Cheng Yeh (2007), Concrete Slump Test, UCI, doi:10.24432/C5FG7D.

配布元のCC-BY-4.0に従って再配布。著作権・許諾文は上記ライセンスファイルを参照。変更点は「変換と確認」に記載。
