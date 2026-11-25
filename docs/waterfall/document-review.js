'use strict';

const reviewForm = document.getElementById('review-form');
const revisionForm = document.getElementById('revision-form');
const revisionBody = document.querySelector('#revision-table tbody');
const reviewMessage = document.getElementById('review-message');
const revisionMessage = document.getElementById('revision-message');
const reviewStatus = document.getElementById('review-status');
const revisionColumns = ['version', 'date', 'type', 'description', 'author'];
const revisionLabels = {version:'版',date:'改定日',type:'区分',description:'改定内容',author:'作成者'};
let nextRowId = Math.max(...Array.from(revisionBody.rows, row => Number(row.dataset.rowId)), 0) + 1;

function fieldValue(name) {
  return reviewForm.elements.namedItem(name).value.trim();
}
function allFields() {
  return Array.from(document.querySelectorAll('#review-form [name], #revision-form [name]'));
}
function revisions() {
  return Array.from(revisionBody.rows, row => Object.fromEntries(revisionColumns.map(key => [key, row.querySelector(`[data-revision-field="${key}"]`).value.trim()])));
}
function showMessage(text, error = false) {
  for (const message of [reviewMessage, revisionMessage]) {
    message.textContent = text;
    message.dataset.error = String(error);
  }
}
function syncDocumentInfo() {
  const latest = revisions().at(-1);
  if (latest?.version) reviewForm.dataset.version = latest.version;
  if (latest?.date) reviewForm.dataset.updated = latest.date;
  document.querySelectorAll('[data-document-version]').forEach(label => { label.textContent = reviewForm.dataset.version; });
  document.querySelectorAll('[data-document-updated]').forEach(label => { label.textContent = reviewForm.dataset.updated; });
}
function validateRevisions() {
  const records = revisions();
  if (!records.length) return '改定履歴を1行以上記入してください。';
  const versions = new Set();
  for (let index = 0; index < records.length; index++) {
    const row = records[index];
    for (const key of revisionColumns) {
      if (!row[key]) return `改定履歴${index + 1}行目の「${revisionLabels[key]}」を記入してください。`;
    }
    if (versions.has(row.version)) return `改定履歴の版「${row.version}」が重複しています。`;
    versions.add(row.version);
    if (index > 0 && row.date < records[index - 1].date) return '改定履歴の日付は上から古い順にしてください。';
  }
  return '';
}
function validateReview() {
  if (!fieldValue('author-name') || !fieldValue('author-date')) return '作成者の氏名・作成日を入力してください。';
  for (const [role, label, pending] of [['checker','係長','未確認'],['approver','課長','未承認']]) {
    if (fieldValue(`${role}-decision`) === pending) continue;
    if (!fieldValue(`${role}-name`) || !fieldValue(`${role}-date`)) return `${label}の判定には氏名とレビュー日が必要です。`;
    if (fieldValue(`${role}-date`) < fieldValue('author-date')) return `${label}のレビュー日は作成日以降にしてください。`;
    if (fieldValue(`${role}-date`) < reviewForm.dataset.updated) return `${label}のレビュー日は文書更新日（${reviewForm.dataset.updated}）以降にしてください。`;
  }
  if (fieldValue('approver-decision') === '承認') {
    if (fieldValue('checker-decision') !== '確認済み') return '課長の承認を記録する前に、係長の確認済み記録を入力してください。';
    if (fieldValue('approver-date') < fieldValue('checker-date')) return '課長の承認日は係長の確認日以降にしてください。';
  }
  return '';
}
function updateDisplay() {
  syncDocumentInfo();
  reviewStatus.textContent = `確認：${fieldValue('checker-decision')} ／ 承認：${fieldValue('approver-decision')}`;
  let summary = '確認・承認前';
  if (fieldValue('checker-decision') !== '未確認' || fieldValue('approver-decision') !== '未承認') {
    summary = validateRevisions() || validateReview() ? '記入中（履歴・氏名・日付等を確認）' : `係長：${fieldValue('checker-decision')} ／ 課長：${fieldValue('approver-decision')}`;
  }
  document.querySelectorAll('[data-review-summary]').forEach(label => { label.textContent = summary; });
  // 入力欄は印刷時に隠し、スクロールで欠けない通常の文章として値を出す。
  for (const field of allFields()) {
    const cell = field.closest('td');
    let mirror = cell.querySelector('.print-value');
    if (!mirror) {
      mirror = document.createElement('span');
      mirror.className = 'print-value';
      cell.append(mirror);
    }
    mirror.textContent = field.value || '未記入';
  }
}
function markChanged() {
  updateDisplay();
  showMessage('未保存の変更があります。改定履歴と記録をHTMLで保存、または印刷してください。');
}
function nextVersion() {
  const match = revisions().at(-1)?.version.match(/^(\d+)\.(\d+)$/);
  return match ? `${match[1]}.${Number(match[2]) + 1}` : '';
}
function addRevision() {
  const id = nextRowId++;
  const today = new Intl.DateTimeFormat('sv-SE', {timeZone:'Asia/Tokyo',year:'numeric',month:'2-digit',day:'2-digit'}).format(new Date());
  const previousDate = revisions().at(-1)?.date || today;
  const values = {version:nextVersion(),date:today < previousDate ? previousDate : today,type:'改定',description:'',author:fieldValue('author-name')};
  const row = document.createElement('tr');
  row.dataset.revisionRow = '';
  row.dataset.rowId = String(id);
  row.dataset.added = 'true';
  for (const key of revisionColumns) {
    const cell = document.createElement('td');
    const field = document.createElement(key === 'description' ? 'textarea' : key === 'type' ? 'select' : 'input');
    field.name = `revision-${id}-${key}`;
    field.dataset.revisionField = key;
    field.setAttribute('aria-label', `改定履歴${id}行目の${revisionLabels[key]}`);
    if (key === 'type') {
      for (const value of ['新規作成','改定']) field.add(new Option(value,value));
    } else if (key === 'description') field.rows = 3;
    else field.type = key === 'date' ? 'date' : 'text';
    field.value = values[key];
    cell.append(field);
    row.append(cell);
  }
  const action = document.createElement('td');
  action.className = 'revision-operation';
  const cancel = document.createElement('button');
  cancel.type = 'button';
  cancel.dataset.cancelRevision = '';
  cancel.textContent = '追加行を取り消す';
  action.append(cancel);
  row.append(action);
  revisionBody.append(row);
  markChanged();
  row.querySelector('[data-revision-field="description"]').focus();
}
function download(content, filename, type) {
  const address = URL.createObjectURL(new Blob([content], {type}));
  const link = document.createElement('a');
  link.href = address;
  link.download = filename;
  document.body.append(link);
  link.click();
  link.remove();
  window.setTimeout(() => URL.revokeObjectURL(address), 1000);
}
function recordFilename(extension) {
  const safeVersion = reviewForm.dataset.version.replace(/[\\/:*?"<>|\s]/g, '_');
  return `${reviewForm.dataset.file}-review-v${safeVersion}.${extension}`;
}
function checkBeforeSave() {
  updateDisplay();
  const error = validateRevisions() || validateReview();
  if (error) { showMessage(error, true); return false; }
  return true;
}
function saveHtml() {
  if (!checkBeforeSave()) return;
  const snapshot = document.documentElement.cloneNode(true);
  for (const field of allFields()) {
    const copy = snapshot.querySelector(`[name="${field.name}"]`);
    if (field.tagName === 'SELECT') {
      for (const option of copy.options) {
        if (option.value === field.value) option.setAttribute('selected', '');
        else option.removeAttribute('selected');
      }
    } else if (field.tagName === 'TEXTAREA') copy.textContent = field.value;
    else copy.setAttribute('value', field.value);
  }
  for (const id of ['review-message','revision-message']) {
    const message = snapshot.querySelector(`#${id}`);
    message.textContent = 'このHTMLには保存時点の改定履歴と記録が含まれています。変更後は再度保存してください。';
    message.dataset.error = 'false';
  }
  snapshot.querySelector('body').classList.remove('sidebar-open');
  snapshot.querySelector('#image-dialog').removeAttribute('open');
  download(`<!doctype html>\n${snapshot.outerHTML}\n`, recordFilename('html'), 'text/html;charset=utf-8');
  showMessage('改定履歴と記録をHTMLで保存しました。元HTMLと同じフォルダで開き直して確認してください。');
}

document.getElementById('add-revision').addEventListener('click', addRevision);
revisionBody.addEventListener('click', event => {
  const cancel = event.target.closest('[data-cancel-revision]');
  if (!cancel) return;
  const row = cancel.closest('[data-revision-row]');
  if (row.dataset.added !== 'true') return;
  row.remove();
  markChanged();
});
document.querySelectorAll('[data-save-html], #save-reviewed').forEach(button => button.addEventListener('click', saveHtml));
document.getElementById('export-review').addEventListener('click', () => {
  if (!checkBeforeSave()) return;
  const record = {documentId:reviewForm.dataset.documentId,documentVersion:reviewForm.dataset.version,
    created:reviewForm.dataset.created,updated:reviewForm.dataset.updated,savedAt:new Date().toISOString(),
    fields:Object.fromEntries(Array.from(reviewForm.querySelectorAll('[name]'),field=>[field.name,field.value])),revisionHistory:revisions()};
  download(`${JSON.stringify(record,null,2)}\n`, recordFilename('json'), 'application/json;charset=utf-8');
  showMessage('改定履歴と確認・承認記録をJSONで保存しました。文書本体と同じ版の記録として保管してください。');
});
document.getElementById('print-document').addEventListener('click', () => { if (checkBeforeSave()) window.print(); });
for (const form of [reviewForm,revisionForm]) {
  form.addEventListener('submit',event=>event.preventDefault());
  form.addEventListener('input',markChanged);
}
window.addEventListener('beforeprint', updateDisplay);
updateDisplay();

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
