import { promises as fs } from 'node:fs';
import { createServer } from 'node:http';
import { createRequire } from 'node:module';
import { spawn } from 'node:child_process';
import { createHash } from 'node:crypto';
import { dirname, resolve, extname, relative, sep } from 'node:path';
import { fileURLToPath } from 'node:url';

const require = createRequire(import.meta.url);
const { chromium } = require('playwright');
const sourceFolder = dirname(fileURLToPath(import.meta.url));
const outputFolder = resolve(sourceFolder, '..');
const repository = resolve(sourceFolder, '../../../..');
const workFolder = resolve(repository, 'output/video/app-overview');
const specification = JSON.parse(await fs.readFile(resolve(sourceFolder, 'storyboard.json'), 'utf8'));
const framesPerSecond = 30;
const leadSeconds = 0.3;
const sentenceGap = 0.28;
const tailSeconds = 0.35;
const command = process.argv[2] || 'preview';
const durationOf = async file => Number(await run('ffprobe', ['-v', 'error', '-show_entries', 'format=duration', '-of', 'default=noprint_wrappers=1:nokey=1', file]));

function run(program, args) {
  return new Promise((accept, reject) => {
    const child = spawn(program, args, { stdio: ['ignore', 'pipe', 'pipe'] });
    let output = '', diagnostic = '';
    child.stdout.on('data', part => { output += part; });
    child.stderr.on('data', part => { diagnostic = (diagnostic + part).slice(-18000); });
    child.once('error', reject);
    child.once('exit', code => code === 0 ? accept(output.trim()) : reject(new Error(`${program} exited ${code}\n${diagnostic}`)));
  });
}

async function pool(items, workers, action) {
  let next = 0;
  await Promise.all(Array.from({ length: workers }, async () => {
    while (next < items.length) { const index = next++; await action(items[index], index); }
  }));
}

const exists = async file => fs.access(file).then(() => true, () => false);
const ffmpeg = args => run('ffmpeg', ['-hide_banner', '-loglevel', 'error', '-y', ...args]);
const listText = files => files.map(file => `file '${file.replaceAll("'", "'\\''")}'`).join('\n') + '\n';
const escapeHTML = text => String(text).replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;').replaceAll('"', '&quot;');
const stamp = seconds => {
  const milliseconds = Math.round(seconds * 1000);
  return [Math.floor(milliseconds / 3600000), Math.floor(milliseconds / 60000) % 60, Math.floor(milliseconds / 1000) % 60].map(x => String(x).padStart(2, '0')).join(':') + '.' + String(milliseconds % 1000).padStart(3, '0');
};

async function prepareNarration() {
  await fs.mkdir(workFolder, { recursive: true });
  const sentences = specification.scenes.flatMap(scene => scene.segments);
  await pool(sentences, 1, async (segment, index) => {
    const key = createHash('sha256').update(JSON.stringify([specification.voice, specification.rate, segment.speech])).digest('hex').slice(0, 18);
    const aiff = resolve(workFolder, `voice-${key}.aiff`);
    const wave = resolve(workFolder, `voice-${key}.wav`);
    if (!(await exists(wave))) {
      const textFile = resolve(workFolder, `voice-${key}.txt`);
      await fs.writeFile(textFile, segment.speech, 'utf8');
      await run('say', ['-v', specification.voice, '-r', String(specification.rate), '-o', aiff, '-f', textFile]);
      await ffmpeg(['-i', aiff, '-af', `apad=pad_dur=${sentenceGap}`, '-ar', '48000', '-ac', '1', '-c:a', 'pcm_s16le', wave]);
    }
    segment.wave = wave;
    segment.audioDuration = await durationOf(wave);
    if ((index + 1) % 5 === 0) console.log(`SPEECH ${index + 1}/${sentences.length}`);
  });
  let elapsed = 0;
  for (const [index, scene] of specification.scenes.entries()) {
    scene.index = index; scene.start = elapsed;
    let localTime = leadSeconds;
    for (const segment of scene.segments) {
      segment.start = localTime;
      segment.end = localTime + segment.audioDuration - 0.08;
      localTime += segment.audioDuration;
    }
    scene.frames = Math.ceil((localTime + tailSeconds) * framesPerSecond);
    scene.duration = scene.frames / framesPerSecond;
    elapsed += scene.duration;
  }
  specification.duration = elapsed;
  await fs.writeFile(resolve(workFolder, 'timeline.json'), JSON.stringify(specification, null, 2));
  console.log(`NARRATION_READY: ${specification.scenes.length} scenes / ${elapsed.toFixed(2)} seconds`);
}

async function renderImages() {
  const types = { '.html': 'text/html', '.js': 'text/javascript', '.png': 'image/png', '.css': 'text/css' };
  const server = createServer(async (request, response) => {
    try {
      const pathname = decodeURIComponent(new URL(request.url, 'http://localhost').pathname);
      const file = resolve(repository, '.' + pathname);
      if (file !== repository && !file.startsWith(repository + sep)) throw new Error('Outside project');
      const content = await fs.readFile(file);
      response.writeHead(200, { 'Content-Type': types[extname(file)] || 'application/octet-stream' }); response.end(content);
    } catch { response.writeHead(404); response.end('Not found'); }
  });
  await new Promise(accept => server.listen(0, '127.0.0.1', accept));
  const port = server.address().port;
  const candidates = [process.env.VIDEO_BROWSER_PATH, chromium.executablePath(), ...(process.platform === 'darwin' ? ['/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'] : [])].filter(Boolean);
  let executablePath;
  for (const candidate of candidates) { if (await exists(candidate)) { executablePath = candidate; break; } }
  if (!executablePath) throw new Error('Chromiumがありません。VIDEO_BROWSER_PATHで実行ファイルを指定してください。');
  const browser = await chromium.launch({ headless: true, executablePath, args: ['--disable-gpu', '--force-color-profile=srgb'] });
  const page = await browser.newPage({ viewport: { width: 1920, height: 1080 }, deviceScaleFactor: 1 });
  const panelPage = await browser.newPage({ viewport: { width: 1248, height: 690 }, deviceScaleFactor: 1 });
  const captionPage = await browser.newPage({ viewport: { width: 1744, height: 100 }, deviceScaleFactor: 1 });
  const browserErrors = [];
  page.on('pageerror', error => browserErrors.push(error.message));
  try {
    const frameURL = `http://127.0.0.1:${port}/${relative(repository, resolve(sourceFolder, 'frame.html')).split(sep).join('/')}`;
    await Promise.all([page.goto(frameURL), panelPage.goto(frameURL), captionPage.goto(frameURL)]);
    for (const scene of specification.scenes) {
      const prefix = resolve(workFolder, String(scene.index + 1).padStart(2, '0'));
      await page.evaluate(args => window.show(...args), [scene, scene.index, specification.scenes.length, 'full']);
      const problems = await page.evaluate(() => [...document.querySelectorAll('.title,.bullet,.note,.screen')].filter(element => element.scrollWidth > element.clientWidth + 3 || element.scrollHeight > element.clientHeight + 3).map(element => ({ className: element.className, width: element.scrollWidth, height: element.scrollHeight, clientWidth: element.clientWidth, clientHeight: element.clientHeight })));
      // The image is deliberately larger than its crop container; inspect text boxes only.
      const textProblems = problems.filter(item => item.className !== 'screen');
      if (textProblems.length) throw new Error(`${scene.id}: text overflow ${JSON.stringify(textProblems)}`);
      await page.screenshot({ path: prefix + '-full.png' });
      await page.evaluate(args => window.show(...args), [scene, scene.index, specification.scenes.length, 'base']);
      await page.screenshot({ path: prefix + '-base.png' });
      await panelPage.evaluate(args => window.show(...args), [scene, scene.index, specification.scenes.length, 'panel']);
      await panelPage.screenshot({ path: prefix + '-panel.png' });
      for (const [part, segment] of scene.segments.entries()) {
        await captionPage.evaluate(args => window.show(...args), [scene, scene.index, specification.scenes.length, 'caption', segment.caption]);
        const fits = await captionPage.evaluate(() => document.querySelector('.caption').scrollHeight <= 100);
        if (!fits) throw new Error(`${scene.id}: caption does not fit`);
        await captionPage.screenshot({ path: prefix + `-caption-${part}.png`, omitBackground: true });
      }
    }
    if (browserErrors.length) throw new Error(browserErrors.join('\n'));
  } finally { await browser.close(); await new Promise(accept => server.close(accept)); }
  const sharp = require('sharp');
  const columns = 4, cellWidth = 480, cellHeight = 270;
  const composites = await Promise.all(specification.scenes.map(async scene => ({
    input: await sharp(resolve(workFolder, String(scene.index + 1).padStart(2, '0') + '-full.png')).resize(cellWidth, cellHeight).toBuffer(),
    left: (scene.index % columns) * cellWidth, top: Math.floor(scene.index / columns) * cellHeight
  })));
  await sharp({ create: { width: columns * cellWidth, height: Math.ceil(specification.scenes.length / columns) * cellHeight, channels: 3, background: '#091b2b' } }).composite(composites).png().toFile(resolve(workFolder, 'storyboard-sheet.png'));
  console.log(`FRAMES_READY: ${workFolder}/storyboard-sheet.png`);
}

async function renderVideo() {
  const lead = resolve(workFolder, 'lead.wav'), tail = resolve(workFolder, 'tail.wav');
  await ffmpeg(['-f', 'lavfi', '-i', 'anullsrc=r=48000:cl=mono', '-t', String(leadSeconds), '-c:a', 'pcm_s16le', lead]);
  await ffmpeg(['-f', 'lavfi', '-i', 'anullsrc=r=48000:cl=mono', '-t', String(tailSeconds + 0.1), '-c:a', 'pcm_s16le', tail]);
  await pool(specification.scenes, 2, async scene => {
    const prefix = resolve(workFolder, String(scene.index + 1).padStart(2, '0'));
    const audioList = prefix + '-audio.txt';
    await fs.writeFile(audioList, listText([lead, ...scene.segments.map(x => x.wave), tail]));
    await ffmpeg(['-f', 'concat', '-safe', '0', '-i', audioList, '-af', 'apad', '-t', String(scene.duration), '-ar', '48000', '-ac', '1', '-c:a', 'pcm_s16le', prefix + '-audio.wav']);
    const args = ['-filter_complex_threads', '1', '-threads', '1', '-loop', '1', '-framerate', '30', '-i', prefix + '-base.png', '-threads', '1', '-loop', '1', '-framerate', '30', '-i', prefix + '-panel.png'];
    for (let part = 0; part < scene.segments.length; part++) args.push('-threads', '1', '-loop', '1', '-framerate', '1', '-i', prefix + `-caption-${part}.png`);
    const filters = [
      `[1:v]scale=2496:1380,zoompan=z='1+0.012*on/${scene.frames}':x='iw/2-iw/zoom/2':y='ih/2-ih/zoom/2':d=1:s=1248x690:fps=${framesPerSecond},format=yuv420p[camera]`,
      '[0:v][camera]overlay=600:194:shortest=1[panel]'
    ];
    let previous = 'panel';
    for (const [part, segment] of scene.segments.entries()) {
      const name = 'caption' + part;
      filters.push(`[${previous}][${part + 2}:v]overlay=88:928:enable='between(t,${segment.start},${segment.end})'[${name}]`);
      previous = name;
    }
    filters.push(`[${previous}]fade=t=in:st=0:d=0.18,fade=t=out:st=${scene.duration - 0.18}:d=0.18,format=yuv420p[video]`);
    args.push('-filter_complex', filters.join(';'), '-map', '[video]', '-frames:v', String(scene.frames), '-r', String(framesPerSecond), '-c:v', 'libx264', '-preset', 'veryfast', '-crf', '20', '-threads', '3', '-pix_fmt', 'yuv420p', '-an', '-movflags', '+faststart', prefix + '-video.mp4');
    await ffmpeg(args);
    console.log(`ENCODED ${scene.index + 1}/${specification.scenes.length}: ${scene.id}`);
  });
  const clips = specification.scenes.map(scene => resolve(workFolder, String(scene.index + 1).padStart(2, '0')));
  await fs.writeFile(resolve(workFolder, 'video-list.txt'), listText(clips.map(x => x + '-video.mp4')));
  await fs.writeFile(resolve(workFolder, 'audio-list.txt'), listText(clips.map(x => x + '-audio.wav')));
  await ffmpeg(['-f', 'concat', '-safe', '0', '-i', resolve(workFolder, 'video-list.txt'), '-c', 'copy', resolve(workFolder, 'silent.mp4')]);
  await ffmpeg(['-f', 'concat', '-safe', '0', '-i', resolve(workFolder, 'audio-list.txt'), '-af', 'loudnorm=I=-16:TP=-1.5:LRA=7', '-ar', '48000', '-ac', '2', '-c:a', 'pcm_s16le', resolve(workFolder, 'narration.wav')]);
  const metadata = ';FFMETADATA1\ntitle=MATLAB解析アプリ 機能と基本操作\ncomment=参考画面・合成データによる解説。R2025bとWindowsでの最終検証は未実施。\n' + specification.scenes.map(scene => `[CHAPTER]\nTIMEBASE=1/1000\nSTART=${Math.round(scene.start * 1000)}\nEND=${Math.round((scene.start + scene.duration) * 1000)}\ntitle=${scene.title.replaceAll('\n', '')}`).join('\n');
  await fs.writeFile(resolve(workFolder, 'chapters.txt'), metadata);
  await ffmpeg(['-i', resolve(workFolder, 'silent.mp4'), '-i', resolve(workFolder, 'narration.wav'), '-f', 'ffmetadata', '-i', resolve(workFolder, 'chapters.txt'), '-map', '0:v:0', '-map', '1:a:0', '-map_metadata', '2', '-map_chapters', '2', '-c:v', 'copy', '-c:a', 'aac', '-b:a', '160k', '-t', String(specification.duration), '-movflags', '+faststart', resolve(outputFolder, 'app-overview-ja.mp4')]);
  await ffmpeg(['-ss', '2', '-i', resolve(outputFolder, 'app-overview-ja.mp4'), '-frames:v', '1', '-update', '1', resolve(outputFolder, 'poster.png')]);
  console.log(`VIDEO_READY: ${outputFolder}/app-overview-ja.mp4`);
}

async function writeCompanions() {
  const cues = specification.scenes.flatMap(scene => scene.segments.map(segment => ({ start: scene.start + segment.start, end: scene.start + segment.end, text: segment.caption })));
  await fs.writeFile(resolve(outputFolder, 'subtitles-ja.srt'), cues.map((cue, index) => `${index + 1}\n${stamp(cue.start).replace('.', ',')} --> ${stamp(cue.end).replace('.', ',')}\n${cue.text}\n`).join('\n'));
  await fs.writeFile(resolve(outputFolder, 'subtitles-ja.vtt'), 'WEBVTT\n\n' + cues.map(cue => `${stamp(cue.start)} --> ${stamp(cue.end)}\n${cue.text}\n`).join('\n'));
  const transcript = `# ${specification.title}\n\n日本語ナレーション・字幕付き。合成データによる参考画面を使用。実操作の録画ではありません。R2025b / Windows / Runtimeでの最終検証は未実施です。\n\n` + specification.scenes.map(scene => `## ${stamp(scene.start).slice(0, 8)} ${scene.title.replaceAll('\n', '')}\n\n${scene.segments.map(part => part.caption).join('\n\n')}\n`).join('\n');
  await fs.writeFile(resolve(outputFolder, 'transcript.md'), transcript);
  const report = { title: specification.title, date: '2026-10-29', language: 'ja', durationSeconds: specification.duration, width: 1920, height: 1080, fps: framesPerSecond, voice: specification.voice, voiceRate: specification.rate, sourceCommit: await run('git', ['-C', repository, 'rev-parse', 'HEAD']), sourceImages: [...new Set(specification.scenes.map(x => x.image).filter(Boolean))], chapters: specification.scenes.map(scene => ({ start: scene.start, duration: scene.duration, title: scene.title.replaceAll('\n', '') })), limitations: ['R2022bの表示専用コピーと合成データの参考画面を使用', '実操作を録画した動画ではない', '参考画像では実GPRの学習・モデル保存・実SHAPは未実施', 'R2025b / Windows exe / Runtimeでの最終確認は未実施'] };
  await fs.writeFile(resolve(outputFolder, 'video-info.json'), JSON.stringify(report, null, 2) + '\n');
  const chaptersHTML = report.chapters.map((chapter, index) => `<li><button data-time="${chapter.start}"><span>${stamp(chapter.start).slice(3, 8)}</span>${escapeHTML(chapter.title)}</button></li>`).join('');
  const html = `<!doctype html><html lang="ja"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>${escapeHTML(specification.title)}</title><style>*{box-sizing:border-box}body{margin:0;background:#edf2f7;color:#14293d;font:14px/1.7 -apple-system,BlinkMacSystemFont,"Hiragino Kaku Gothic ProN",sans-serif}aside{position:fixed;width:260px;inset:0 auto 0 0;background:#10263e;color:#fff;padding:22px 16px;overflow:auto}aside h1{font-size:18px;line-height:1.6;margin:0 0 12px}aside p{color:#b5d0df;font-size:12px}ol{list-style:none;padding:0}li{margin:3px 0}button{border:0;border-radius:5px;background:none;color:inherit;font:inherit;text-align:left;width:100%;padding:8px;cursor:pointer}button:hover,button:focus-visible{background:#254b67;outline:2px solid #67c6d5}button span{display:inline-block;color:#7ed6df;font-size:12px;min-width:48px}main{margin-left:260px;max-width:1600px;padding:26px 32px}h2{font-size:22px;margin:0 0 12px}video{display:block;width:100%;background:#091b2b;border-radius:8px;box-shadow:0 8px 24px #10263e22}.notice{padding:12px 16px;background:#fff5df;border-left:4px solid #b77c20}.links{display:flex;gap:20px;flex-wrap:wrap}a{color:#175b85}.top{position:fixed;bottom:22px;right:22px;width:auto;background:#10263e;color:white;padding:10px 14px}.caption-note{color:#53687a}@media(max-width:800px){aside{position:static;width:auto;max-height:250px}main{margin:0;padding:18px}.top{bottom:12px;right:12px}}</style></head><body><aside aria-label="動画の章"><h1>MATLAB解析アプリ<br>機能と基本操作</h1><p>日本語音声・字幕付き<br>${Math.floor(specification.duration / 60)}分${String(Math.round(specification.duration % 60)).padStart(2, '0')}秒 / Full HD</p><nav><ol>${chaptersHTML}</ol></nav></aside><main id="top"><h2>アプリ解説動画</h2><p>章を選ぶと、その説明へ移動します。再生ボタンで開始してください。</p><video id="video" controls preload="metadata" poster="poster.png" playsinline><source src="app-overview-ja.mp4" type="video/mp4">MP4に対応するプレーヤーで動画を開いてください。</video><p class="caption-note">字幕は映像内に表示しています。音声はmacOSの日本語合成音声です。</p><p class="notice">合成データを使った参考画面による解説です。実操作の録画や、実GPRの性能を示す動画ではありません。MATLAB R2025b・Windows・Runtimeでの最終検証は未実施です。</p><div class="links"><a href="app-overview-ja.mp4" download>MP4を保存</a><a href="subtitles-ja.srt" download>字幕（SRT）</a><a href="transcript.md">解説文</a><a href="../../user-guide/procedure-guide.html">画像付き手順書</a></div></main><button class="top" onclick="scrollTo({top:0,behavior:'smooth'})">↑ 上へ</button><script>const video=document.getElementById('video');const status=document.createElement('p');status.setAttribute('role','status');video.before(status);let objectURL;const mediaReady=(async()=>{if(location.protocol.startsWith('http')){status.textContent='動画を読み込んでいます。';const response=await fetch(video.querySelector('source').src);if(!response.ok)throw new Error('Video download failed');objectURL=URL.createObjectURL(await response.blob());video.src=objectURL;video.load();await new Promise((resolve,reject)=>{video.addEventListener('loadedmetadata',resolve,{once:true});video.addEventListener('error',reject,{once:true});});}status.textContent='';return true;})().catch(()=>{status.textContent='動画を読み込めませんでした。「MP4を保存」からファイルを開いてください。';return false;});document.querySelectorAll('[data-time]').forEach(button=>button.addEventListener('click',async()=>{if(!await mediaReady)return;video.currentTime=Number(button.dataset.time);video.play().catch(()=>{});}));addEventListener('beforeunload',()=>{if(objectURL)URL.revokeObjectURL(objectURL);});</script></body></html>`;
  await fs.writeFile(resolve(outputFolder, 'index.html'), html.replace('</title>', '</title><link rel="icon" href="data:,">'));
}

await prepareNarration();
await renderImages();
await writeCompanions();
if (command === 'video') await renderVideo();
else if (command !== 'preview') throw new Error('Use preview or video');
