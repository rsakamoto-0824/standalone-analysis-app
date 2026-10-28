# 残課題

- [ ] I-001 Windows / MATLAB R2025b で全単体テストを実行し、成功・失敗・未完了件数を記録する。
- [ ] I-002 R2025b App Designer で薄い入口 `app/AnalysisApp.mlapp` を作成し、画面の表示・操作を確認する（`docs/windows-build.md`）。
- [ ] I-003 MATLAB Compiler R2025b で Windows exe を生成し、Runtime R2025b のみの端末で全機能を確認する。
- [ ] I-004 ユーザーが旧・新モデルを用意し、`compare_models` で互換性を確認する。
- [ ] I-005 Q-01〜Q-11 の暫定方針をユーザー確認後に確定する。現在は原仕様の暫定方針を維持する。
- [ ] I-006 Runtime での `license('test','Statistics_Toolbox')`、学習、SHAP の動作を配布確認に含める。未確認のため成功とは扱わない。
- [x] I-007 ワードクラウドをアプリ内に移し、Titleプロパティで題名を設定。R2022bの補助描画試験で確認。R2025b / RuntimeはI-001・I-003で最終確認する。
- [x] I-008 ステータスの1文字改行、リサイズ、アプリ内グラフ、評価・要約統合、設定・Helpのソースと補助テストを追加。
- [x] I-009 ユーザー確認済みの同一水準直交表、I最適、固定点のD/I拡張、交絡表示を実装。計算方式・限界をdocs/ui-update.mdに記録。
