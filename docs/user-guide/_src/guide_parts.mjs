// HTML 手順書の共通部品。build_guide.mjs（ビルド・利用手順書）と build_user_manual.mjs（利用者向け手順書）で使う。
import fs from 'node:fs';
import path from 'node:path';

export const escape = (text) => String(text).replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;').replaceAll('"', '&quot;');
export const table = (heads, rows) => `<table class="guide-table"><thead><tr>${heads.map(x=>`<th scope="col">${x}</th>`).join('')}</tr></thead><tbody>${rows.map(row=>`<tr>${row.map(x=>`<td>${x}</td>`).join('')}</tr>`).join('')}</tbody></table>`;
export const code = (label, text) => `<div class="code-block"><div class="code-header"><span>${escape(label)}</span><button type="button" class="copy-button" aria-label="${escape(label)}をコピー">コピー</button></div><pre><code>${escape(text)}</code></pre></div>`;
export const note = (title, text, type='info') => `<div class="callout ${type}"><div class="callout-icon" aria-hidden="true">${type==='warning'?'!':'i'}</div><div><h3>${title}</h3><p>${text}</p></div></div>`;
export const step = (number, title, body, expected='') => `<article class="step-card"><h3><span class="step-label">${number}</span>${title}</h3>${body}${expected?`<p class="expected"><strong>確認：</strong>${expected}</p>`:''}</article>`;
export const check = (text) => `<label><input type="checkbox"> <span>${text}</span></label>`;
export const DEFAULT_SHOT_DETAIL = 'R2022b / macOS で、同梱の合成サンプルを実際に学習して撮影した参考画面です（SHAPだけ代替計算）。R2025b / Windows の画面とは細部が異なる場合があります。';

// 図番号は手順書ごとに数えるため、画像の部品は手順書ごとに作る。
export function createShots(guideRoot, { tag = '参考撮影 · R2022b / macOS', defaultDetail = DEFAULT_SHOT_DETAIL } = {}) {
  let count = 0;
  const shot = (name, caption, detail=defaultDetail) => {
    count += 1;
    const png = fs.readFileSync(path.join(guideRoot, 'images', `${name}.png`));
    const width = png.readUInt32BE(16), height = png.readUInt32BE(20);
    return `<figure class="screenshot"><button type="button" class="image-open" aria-label="${escape(caption)}を拡大"><img src="images/${name}.png" alt="${escape(caption)}" loading="lazy" width="${width}" height="${height}"></button><figcaption><span class="shot-tag">${tag}</span><span class="shot-zoom">クリックで拡大 / Escで閉じる</span><strong>図${count}　${caption}</strong><span class="shot-note">${detail}</span></figcaption></figure>`;
  };
  return { shot, count: () => count };
}

// 左に章目次、右下に「トップへ戻る」を置いたページ全体を組み立てる（共通テンプレートの構成）。
export function renderPage({ sections, groups, sidebarTitle, sidebarSubtitle, updated, heroEyebrow, heroTitle, heroSubtitle, heroLead, badges, status, footer, title, description }) {
  const nav = `<aside id="sidebar" class="sidebar" aria-label="目次"><div class="sidebar-header"><p class="eyebrow">PROCESS INSIGHT TOOL</p><p class="sidebar-title">${sidebarTitle}</p><p class="sidebar-subtitle">${sidebarSubtitle}</p></div><nav><ol class="toc-list">${sections.map((s,i)=>`${groups[i]?`<li class="toc-group">${groups[i]}</li>`:''}<li><a href="#${s.id}">${i+1}. ${s.title}</a></li>`).join('')}</ol></nav><div class="sidebar-footer"><span class="status-dot" aria-hidden="true"></span>更新 ${updated} · PC閲覧用</div></aside>`;
  const main = `<main id="main-content" class="main-content"><header class="hero"><div class="hero-content"><p class="eyebrow">${heroEyebrow}</p><h1>${heroTitle}<br><span>${heroSubtitle}</span></h1><p class="hero-lead">${heroLead}</p><div class="hero-badges">${badges.map(b=>`<span>${b}</span>`).join('')}</div></div></header>${status?`<p class="guide-status">${status}</p>`:''}${sections.map((s,i)=>`<section id="${s.id}" class="content-section"><div class="section-heading"><span class="section-number">${String(i+1).padStart(2,'0')}</span><div><p class="section-kicker">${s.kicker}</p><h2>${s.title}</h2></div></div>${s.body}</section>`).join('\n')}<footer class="page-footer">${footer.map(f=>`<p>${f}</p>`).join('')}</footer></main>`;
  return `<!doctype html>
<html lang="ja"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="description" content="${escape(description)}"><title>${escape(title)}</title>
<link rel="icon" href="data:,"><link rel="stylesheet" href="procedure-guide.css"><script src="procedure-guide.js" defer></script>
  <link rel="stylesheet" href="guide-extra.css">
  <script src="guide-extra.js" defer></script>
</head><body id="top"><a class="skip-link" href="#main-content">本文へ移動</a>
<button id="toc-toggle" class="toc-toggle" type="button" aria-controls="sidebar" aria-expanded="false"><span aria-hidden="true">☰</span> 目次</button>
${nav}<div id="sidebar-overlay" class="sidebar-overlay" aria-hidden="true"></div>
${main}
<button id="back-to-top" class="back-to-top" type="button" aria-label="ページ上部へ戻る"><span aria-hidden="true">↑</span> トップへ戻る</button>
<dialog id="image-dialog" class="lightbox" aria-labelledby="dialog-caption"><div class="lightbox-bar"><p id="dialog-caption"></p><button id="dialog-close" class="lightbox-close" type="button">閉じる（Esc）</button></div><img id="dialog-image" alt=""></dialog>
</body></html>`;
}
