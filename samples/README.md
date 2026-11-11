# 機能評価用サンプル

[ProcessInsight_Samples.xlsx](ProcessInsight_Samples.xlsx)をダウンロードして使用します。すべて数式と規則で作成した合成データで、実測値や推奨成膜条件ではありません。各データシートのヘッダー行は **1** です。「使い方」は操作案内と合成式の条件を記載したシートです。

| 機能 | シート | 行数 | 指定する列 |
|---|---|---:|---|
| APC | APC | 120 | 説明変数 SIN_TH / SIN_RN / NSG_TH / RESIST_TH、目的変数 CD_X / CD_Y |
| Swing Curve 下地あり | Swing_Base | 80 | 膜厚 RESIST_TH、下地 SIN_TH / SIN_RN / NSG_TH、目的変数 CD_X / CD_Y |
| Swing Curve 下地なし | Swing_NoBase | 80 | 膜厚 RESIST_THのみ、目的変数 CD_X / CD_Y |
| 汎用GPR | Generic | 80 | 入力数3、X1 / X2 / X3、目的変数 Y1 / Y2 |
| 保存モデル推定・SHAP | Predict_SHAP | 40 | APCで保存したモデルと同じ4説明変数。評価用実測列に保存した目的変数を選択 |
| 炉内補間 | Furnace | 40 | WaferId / BoatSlot / Batch、目的変数 膜厚_nm / 屈折率 |
| 実験計画の拡張 | DOE_Existing | 10 | F1 / F2 / F3（−1〜1の符号化値） |
| ワードクラウド | WordCloud | 1 | Textをコピー、または[sample_wordcloud.txt](sample_wordcloud.txt)を開く |

APCの120行は学習可能ですが、従来の150行未満の注意が表示されます。炉内補間は2Run・各20Waferで、各目的変数を10点ずつ計測した構成です。膜厚と屈折率の空欄は未計測であり、0へ置き換えません。WaferIdは架空の識別子です。

左の入力欄の「目的変数」で複数列を選択し、モデリング・SHAP評価を実行します。複数列はCtrl（MacはCommand）を押しながら選択します。「条件比較・モデル保存」で対象と条件を比較してから、選択したモデルをMATへ保存します。推定・SHAPを試すMATはこの手順で作成してください。サンプルに学習済みRegressionGPは含めていません。

「使い方」の黄色セルは合成式の入力です。波長248nm・屈折率1.77は指定値で、その他の係数はデモ用の仮定です。値を変えた場合はExcelで再計算・保存してからアプリに読み込みます。膜厚・CDはnm、屈折率は無次元です。

9シートを画像で確認し、881個の数式、エラー0件、外部リンク・VBAなしを確認しました。MacのMicrosoft Excelで再計算・保存・再オープンを確認しています。アプリのR2025b実GPR／実SHAP、Windowsでのビルド・実行は別途確認が必要です。

炉内補間ではBatch・目的変数・方式を比較後、「選択モデルをMAT保存」で1モデルを保存します。専用のFurnace_Model形式で、APC等のTrain_Modelとは別形式です。再利用関数はHTML手順書を参照してください。
