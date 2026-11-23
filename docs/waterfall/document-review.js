'use strict';

const reviewForm = document.getElementById('review-form');
const reviewMessage = document.getElementById('review-message');
const reviewStatus = document.getElementById('review-status');
const reviewFields = Array.from(reviewForm.querySelectorAll('input, select, textarea'));

function fieldValue(name) {
  return reviewForm.elements.namedItem(name).value.trim();
}

function showReviewMessage(text, error = false) {
  reviewMessage.textContent = text;
  reviewMessage.dataset.error = String(error);
}

function updateReviewDisplay() {
  reviewStatus.textContent = `確認：${fieldValue('checker-decision')} ／ 承認：${fieldValue('approver-decision')}`;
  let summary = '確認・承認前';
  if (fieldValue('checker-decision') !== '未確認' || fieldValue('approver-decision') !== '未承認') {
    summary = validateReview() ? '記入中（氏名・日付等を確認）' : `係長：${fieldValue('checker-decision')} ／ 課長：${fieldValue('approver-decision')}`;
  }
  document.querySelectorAll('[data-review-summary]').forEach(label => { label.textContent = summary; });
  for (const field of reviewFields) {
    let mirror = field.closest('td').querySelector('.print-value');
    if (!mirror) {
      mirror = document.createElement('span');
      mirror.className = 'print-value';
      field.closest('td').append(mirror);
    }
    mirror.textContent = field.value || '未記入';
  }
}

// 日付だけで判定を切り替えず、記録として必要な氏名・日付と順序を確認する。
function validateReview() {
  if (!fieldValue('author-name') || !fieldValue('author-date')) return '作成者の氏名・作成日を入力してください。';
  for (const [role, label, pending] of [['checker', '係長', '未確認'], ['approver', '課長', '未承認']]) {
    if (fieldValue(`${role}-decision`) === pending) continue;
    if (!fieldValue(`${role}-name`) || !fieldValue(`${role}-date`)) return `${label}の判定を記録するには氏名とレビュー日が必要です。`;
    if (fieldValue(`${role}-date`) < fieldValue('author-date')) return `${label}のレビュー日は作成日以降にしてください。`;
  }
  if (fieldValue('approver-decision') === '承認') {
    if (fieldValue('checker-decision') !== '確認済み') return '課長の承認を記録する前に、係長の確認済み記録を入力してください。';
    if (fieldValue('approver-date') < fieldValue('checker-date')) return '課長の承認日は係長の確認日以降にしてください。';
  }
  return '';
}

function download(content, filename, mimeType) {
  const address = URL.createObjectURL(new Blob([content], { type: mimeType }));
  const link = document.createElement('a');
  link.href = address;
  link.download = filename;
  document.body.append(link);
  link.click();
  link.remove();
  window.setTimeout(() => URL.revokeObjectURL(address), 1000);
}

function reviewedFilename(extension) {
  return `${reviewForm.dataset.file}-review-v${reviewForm.dataset.version}.${extension}`;
}

function checkBeforeSave() {
  const error = validateReview();
  if (error) { showReviewMessage(error, true); return false; }
  updateReviewDisplay();
  return true;
}

document.getElementById('save-reviewed').addEventListener('click', () => {
  if (!checkBeforeSave()) return;
  const snapshot = document.documentElement.cloneNode(true);
  for (const field of reviewFields) {
    const copy = snapshot.querySelector(`[name="${field.name}"]`);
    if (field.tagName === 'SELECT') {
      for (const option of copy.options) {
        if (option.value === field.value) option.setAttribute('selected', '');
        else option.removeAttribute('selected');
      }
    } else if (field.tagName === 'TEXTAREA') copy.textContent = field.value;
    else copy.setAttribute('value', field.value);
  }
  const message = snapshot.querySelector('#review-message');
  message.textContent = 'このHTMLの入力欄は保存時点の記録です。変更したときは再度保存してください。';
  message.dataset.error = 'false';
  snapshot.querySelector('body').classList.remove('sidebar-open');
  snapshot.querySelector('#image-dialog').removeAttribute('open');
  download(`<!doctype html>\n${snapshot.outerHTML}\n`, reviewedFilename('html'), 'text/html;charset=utf-8');
  showReviewMessage('HTMLを保存しました。元HTMLと同じフォルダへ置き、開き直して記録を確認してください。');
});

document.getElementById('export-review').addEventListener('click', () => {
  if (!checkBeforeSave()) return;
  const record = { documentId: reviewForm.dataset.documentId, documentVersion: reviewForm.dataset.version,
    issued: reviewForm.dataset.issued, sourceRevision: reviewForm.dataset.baseline,
    savedAt: new Date().toISOString(), fields: Object.fromEntries(reviewFields.map(field => [field.name, field.value])) };
  download(`${JSON.stringify(record, null, 2)}\n`, reviewedFilename('json'), 'application/json;charset=utf-8');
  showReviewMessage('レビュー記録をJSON保存しました。文書本体と同じ版の記録として保管してください。');
});

document.getElementById('print-document').addEventListener('click', () => {
  if (checkBeforeSave()) window.print();
});
reviewForm.addEventListener('submit', event => event.preventDefault());
reviewForm.addEventListener('input', () => {
  updateReviewDisplay();
  showReviewMessage('未保存の入力があります。HTMLを保存または印刷してください。');
});
window.addEventListener('beforeprint', updateReviewDisplay);
updateReviewDisplay();

const imageDialog = document.getElementById('image-dialog');
document.querySelectorAll('.image-open').forEach(button => button.addEventListener('click', () => {
  const image = button.querySelector('img');
  const enlarged = document.getElementById('dialog-image');
  enlarged.src = image.src;
  enlarged.alt = image.alt;
  document.getElementById('dialog-caption').textContent = image.alt;
  imageDialog.showModal();
}));
document.getElementById('dialog-close').addEventListener('click', () => imageDialog.close());
