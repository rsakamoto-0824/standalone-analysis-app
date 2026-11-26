# サンプルデータ（通常版・別配布用）

通常版のインストーラーにはサンプルと手順書を入れません。このフォルダのファイルは、インストーラーとは別に配ります。利用者は各学習画面・炉内補間の「サンプルデータを開く」を押し、表示された画面でこのブック（`ProcessInsight_Samples.xlsx`）を選びます（起動中は同じブックを使います）。

`ProcessInsight_Samples.xlsx` は、すべて数式と規則で作成した合成データです。実測値や推奨成膜条件ではありません。各データシートのヘッダー行は **1** です。「使い方」は操作案内と合成式の条件を記載したシートで、解析には読み込みません。

| 機能 | シート | 行数 | 指定する列 |
|---|---|---:|---|
| APC 学習 | APC | 120 | 説明変数 SIN_TH / SIN_RN / NSG_TH / RESIST_TH、目的変数 CD_X / CD_Y |
| Swing Curve学習（下地あり） | Swing_Base | 80 | 膜厚 RESIST_TH、下地 SIN_TH / SIN_RN / NSG_TH、目的変数 CD_X / CD_Y |
| Swing Curve学習（下地なし） | Swing_NoBase | 80 | 膜厚 RESIST_TH のみ、目的変数 CD_X / CD_Y |
| 汎用回帰学習 | Generic | 80 | 説明変数 X1 / X2 / X3、目的変数 Y1 / Y2 |
| 保存モデルで推定・SHAP | Predict_SHAP | 40 | APC で保存したモデルと同じ4説明変数。評価用の実測列に CD_X など |
| 炉内補間 | Furnace | 40 | WaferId / BoatSlot / Batch、目的変数 膜厚_nm / 屈折率 |

各学習画面と炉内補間の「サンプルデータを開く」を押すと、このブックの対応するシートを開きます（APC → APC、Swing Curve → Swing_Base、汎用回帰 → Generic、炉内補間 → Furnace）。ほかのシートは「① データを開く」の「シート」で選びます。

炉内補間の膜厚と屈折率の空欄は未計測です（0 ではありません）。WaferId は架空の識別子です。
