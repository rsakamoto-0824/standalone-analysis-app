# 残課題

- [ ] I-001 Windows / MATLAB R2025b で全単体テストを実行し、成功・失敗・未完了件数を記録する。
- [ ] I-002 R2025b App Designer で薄い入口 `app/AnalysisApp.mlapp` を作成し、画面の表示・操作を確認する（`docs/windows-build.md`）。
- [ ] I-003 MATLAB Compiler R2025b で Windows exe を生成し、Runtime R2025b のみの端末で全機能を確認する。
- [ ] I-004 ユーザーが旧・新モデルを用意し、`compare_models` で互換性を確認する。
- [ ] I-005 Q-01〜Q-11 の暫定方針をユーザー確認後に確定する。現在は原仕様の暫定方針を維持する。
- [ ] I-006 Runtime での `license('test','Statistics_Toolbox')`、学習、SHAP の動作を配布確認に含める。未確認のため成功とは扱わない。
- [ ] I-007 ワードクラウドのタイトル指定（`title` のフォント引数）を R2025b で確認する。R2022b の手順書用描画では当該引数が非対応だったため、参考画像の生成だけは `Title` プロパティを使用した。アプリ本体は未変更。
