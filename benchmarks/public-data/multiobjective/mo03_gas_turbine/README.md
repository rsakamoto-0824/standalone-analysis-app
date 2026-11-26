# Gas Turbine CO and NOx Emission

タービンの時系列実測

- 入力するファイル: [data.csv](data.csv)（ヘッダー1行目）
- 行数: 36,733 / 列数: 11
- [配布元](https://archive.ics.uci.edu/dataset/551/gas+turbine+co+and+nox+emission+data+set) / [元データ](https://archive.ics.uci.edu/static/public/551/gas+turbine+co+and+nox+emission+data+set.zip)
- ライセンス: [CC-BY-4.0](../../licenses/CC-BY-4.0.txt)
- 取得日: 2026-11-25

入力は環境・装置の計測値。環境量を操作可能とは扱わず、候補行を比較するベンチマークに限る。TEY:MWh、CO/NOX:mg/m^3。2011→2015年の順に連結し、2011～2013年をtrain、2014～2015年をtestとする。時間依存があるのでランダム行分割では評価しない。

## 選ぶ列

説明変数: `AT`, `AP`, `AH`, `AFDP`, `GTEP`, `TIT`, `TAT`, `CDP`

| 目的変数 | 方向 |
|---|---|
| `Y_TEY` | 最大化 |
| `Y_CO` | 最小化 |
| `Y_NOX` | 最小化 |

候補内の非劣解は75行。[正解行番号](reference_pareto_indices.csv)はdata.csvの**データ先頭を1**とする番号（CSVの物理行番号ではない）。
実機や連続空間全体の大域最適解を表すものではない。

[分割表](split.csv): UCIの年別分割（2011～2013 train、2014～2015 test）。
分割表・正解行番号を説明変数に入れない。全候補の真値は採点用に保持し、探索中のモデルへ全件を渡さない。

## 変換と確認

- 2011～2015年を年順・元の行順で連結。列を入力→目的の順へ並べ替え。
- 欠損・非有限値: 0 / 完全重複行: 7
- 定数列: なし
- 定数列はデータに保持し、説明変数の推奨選択からは外す。
- 数値をCSVへ書き戻して元データと一致することを確認。

| CSV列 | 元の列名 |
|---|---|
| `AT` | `AT` |
| `AP` | `AP` |
| `AH` | `AH` |
| `AFDP` | `AFDP` |
| `GTEP` | `GTEP` |
| `TIT` | `TIT` |
| `TAT` | `TAT` |
| `CDP` | `CDP` |
| `Y_TEY` | `TEY` |
| `Y_CO` | `CO` |
| `Y_NOX` | `NOX` |

## 出典・再配布

Gas Turbine CO and NOx Emission Data Set (2019), UCI, doi:10.24432/C5WC95.

配布元のCC-BY-4.0に従って再配布。著作権・許諾文は上記ライセンスファイルを参照。変更点は「変換と確認」に記載。
