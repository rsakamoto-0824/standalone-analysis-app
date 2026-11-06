import fs from 'node:fs/promises';
import path from 'node:path';
import {createRequire} from 'node:module';
import {fileURLToPath,pathToFileURL} from 'node:url';
const require=createRequire(process.env.PIT_ARTIFACT_RESOLVER ?? import.meta.url);
const {Workbook,SpreadsheetFile}=await import(pathToFileURL(require.resolve('@oai/artifact-tool')).href);
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const previews=process.env.PIT_SAMPLE_PREVIEWS ?? '/tmp/outputs/PIT_20261106';
await fs.mkdir(root,{recursive:true}); await fs.mkdir(previews,{recursive:true});
const wb=Workbook.create();
const titles=['使い方','APC','Swing_Base','Swing_NoBase','Generic','Predict_SHAP','Furnace','DOE_Existing','WordCloud'];
const sheets=Object.fromEntries(titles.map(name=>[name,wb.worksheets.add(name)]));
const navy='#203B59', amber='#FFF3CE';
function dataSheet(name,headers,rows){
  const s=sheets[name],last=String.fromCharCode(64+headers.length);
  s.getRange(`A1:${last}${rows.length+1}`).values=[headers,...rows];
  s.getRange(`A1:${last}${rows.length+1}`).format.font={name:'Arial',size:11};
  s.getRange(`A1:${last}1`).format={fill:navy,font:{name:'Arial',bold:true,color:'#FFFFFF'},rowHeight:30};
  s.getRange(`A1:${last}${rows.length+1}`).format.columnWidth=19;
  s.getRange(`A2:${last}${rows.length+1}`).format.rowHeight=23;
  s.getRange(`A2:${last}${rows.length+1}`).setNumberFormat('0.0000');
  s.showGridLines=false; s.freezePanes.freezeRows(1);
  return s;
}
const intro=sheets['使い方']; intro.showGridLines=false;
intro.getRange('A2:E2').values=[['Process Insight Tool サンプルデータ',null,null,null,null]];
intro.getRange('A2:E2').format.font={name:'Arial',size:15,bold:true};
intro.getRange('A4:E4').values=[['機能','読込シート','行数','目的変数','操作・入力の注意']];
intro.getRange('A5:E13').values=[
 ['APC','APC',120,'CD_X, CD_Y','4説明変数を割当て、モデリング条件で2目的変数を選択'],
 ['Swing Curve 下地あり','Swing_Base',80,'CD_X, CD_Y','膜厚RESIST_THと下地SIN_TH・SIN_RN・NSG_THを選択'],
 ['Swing Curve 下地なし','Swing_NoBase',80,'CD_X, CD_Y','説明変数はRESIST_THのみ'],
 ['汎用GPR','Generic',80,'Y1, Y2','説明変数数3。左の対応表にX1・X2・X3を割当て'],
 ['保存モデル推定・SHAP','Predict_SHAP',40,'CD_X, CD_Y','APCシートで保存したモデルと同じ説明変数。先にMATを作成'],
 ['炉内補間','Furnace',40,'膜厚_nm, 屈折率','WaferId・BoatSlot・Batchを指定。空欄は未計測。Runを分離'],
 ['実験計画の拡張','DOE_Existing',10,'なし','F1〜F3は符号化値。追加実験数の初期値25'],
 ['ワードクラウド','WordCloud',1,'なし','同梱sample_wordcloud.txtを開くか、シートのTextをコピー'],
 ['設定・Help','入力不要',null,'なし','設定で実験計画seed、炉内RBF幅・正則化を変更']
];
intro.getRange('A15:E18').values=[
 ['出所','すべて数式と規則で作った合成データ。実測値ではありません。',null,null,null],
 ['読込み','各データシートのヘッダー行は1です。「使い方」は解析へ読み込みません。',null,null,null],
 ['変更方法','黄色の光学条件を編集すると合成応答を再計算します。各式の係数はデモ用です。',null,null,null],
 ['単位','膜厚・CDはnm、屈折率は無次元。GenericのX/Yは任意単位。',null,null,null]
];
intro.getRange('G4:H4').values=[['合成条件','値']];
intro.getRange('G5:H13').values=[['露光波長_nm',248],['レジスト屈折率',1.77],['基準周期_nm',null],['CD基準_nm',50],['周期片振幅_nm',2.5],['膜厚トレンド',0.005],['下地膜厚係数',0.05],['屈折率係数',10],['NSG係数',0.03]];
intro.getRange('H7').formulas=[['=H5/H6']];
intro.getRange('H5:H6').format.fill=amber;
intro.getRange('H8:H13').format.fill=amber;
intro.getRange('G15:H16').values=[['出所','波長248nm・屈折率1.77は指定値。その他は合成データ用の仮定。'],['欠測','Furnaceの空欄は数式による意図的な未計測。0へ置き換えません。']];
intro.getRange('A4:E4').format={fill:navy,font:{name:'Arial',bold:true,color:'#FFFFFF'}};
intro.getRange('G4:H4').format={fill:navy,font:{name:'Arial',bold:true,color:'#FFFFFF'}};
intro.getRange('A4:H18').format.font.name='Arial'; intro.getRange('A4:H18').format.font.size=11;
intro.getRange('A:A').format.columnWidth=29; intro.getRange('B:B').format.columnWidth=28;
intro.getRange('C:D').format.columnWidth=20; intro.getRange('E:E').format.columnWidth=66;
intro.getRange('F:F').format.columnWidth=3; intro.getRange('G:G').format.columnWidth=24; intro.getRange('H:H').format.columnWidth=24;
intro.getRange('A4:H18').format.rowHeight=31;
intro.getRange('B15:E18').merge(true); intro.getRange('B15:E18').format.wrapText=true;
intro.getRange('H15:H16').format.wrapText=true; intro.getRange('G15:H16').format.rowHeight=56;
const phase="2*PI()*D{r}/'使い方'!$H$7";
function processData(name,count,start=0){
 const rows=Array.from({length:count},(_,i)=>{const t=i+start;return [100+2*Math.sin(t*.43),1.9+.012*Math.cos(t*.37),60+1.5*Math.sin(t*.61),800+450*i/(count-1),null,null,`Lot-${1+Math.floor(i/20)}`];});
 const s=dataSheet(name,['SIN_TH','SIN_RN','NSG_TH','RESIST_TH','CD_X','CD_Y','Lot'],rows);
 s.getRange(`B2:B${count+1}`).setNumberFormat('0.00000');
 for(let i=0;i<count;i++){const r=i+2, angle=phase.replace('{r}',r);
  s.getRange(`E${r}:F${r}`).formulas=[[
   `='使い方'!$H$8+'使い方'!$H$9*SIN(${angle})+'使い方'!$H$10*(D${r}-1000)+'使い方'!$H$11*(A${r}-100)+'使い方'!$H$12*(B${r}-1.9)+'使い方'!$H$13*(C${r}-60)`,
   `='使い方'!$H$8+'使い方'!$H$9*COS(${angle})+'使い方'!$H$10*(D${r}-1000)+'使い方'!$H$11*(A${r}-100)`
  ]];
 }
}
processData('APC',120); processData('Swing_Base',80); processData('Predict_SHAP',40,131);
const simple=dataSheet('Swing_NoBase',['RESIST_TH','CD_X','CD_Y'],Array.from({length:80},(_,i)=>[800+450*i/79,null,null]));
for(let i=0;i<80;i++){const r=i+2; simple.getRange(`B${r}:C${r}`).formulas=[[
 `='使い方'!$H$8+'使い方'!$H$9*SIN(2*PI()*A${r}/'使い方'!$H$7)+'使い方'!$H$10*(A${r}-1000)`,
 `='使い方'!$H$8+'使い方'!$H$9*COS(2*PI()*A${r}/'使い方'!$H$7)+'使い方'!$H$10*(A${r}-1000)`]];}
const generic=dataSheet('Generic',['X1','X2','X3','Y1','Y2'],Array.from({length:80},(_,i)=>[Math.sin(i*.3),Math.cos(i*.7),i/79,null,null]));
for(let i=0;i<80;i++){const r=i+2; generic.getRange(`D${r}:E${r}`).formulas=[[`=2*A${r}+B${r}^2+SIN(PI()*C${r})`,`=A${r}*B${r}+3*C${r}`]];}
const furnace=dataSheet('Furnace',['WaferId','BoatSlot','膜厚_nm','屈折率','Batch','Lot'],Array.from({length:40},(_,i)=>[`DEMO-${Math.floor(i/20)+1}-${String(i%20+1).padStart(3,'0')}`,5+(i%20)*10,null,null,`Run-${1+Math.floor(i/20)}`,`Lot-${1+Math.floor((i%20)/5)}`]));
furnace.getRange('A2:A41').setNumberFormat('@'); furnace.getRange('B2:B41').setNumberFormat('0'); furnace.getRange('D2:D41').setNumberFormat('0.000000');
for(let i=0;i<40;i++){const r=i+2,shift=Math.floor(i/20);furnace.getRange(`C${r}:D${r}`).formulas=[[
 `=IF(MOD(ROW()-2,2)=0,100+${shift}*5+0.02*B${r}-0.00005*(B${r}-100)^2,"")`,
 `=IF(MOD(ROW()-2,2)=1,1.46+${shift}*0.01+0.00002*B${r}+0.0001*SIN(B${r}/40),"")`]];}
dataSheet('DOE_Existing',['F1','F2','F3'],[[-1,-1,-1],[1,-1,-1],[-1,1,-1],[-1,-1,1],[1,1,-1],[1,-1,1],[-1,1,1],[1,1,1],[0,0,0],[0.5,-0.5,0]]);
const text='成膜 露光 解析 成膜 モデル SHAP 補間 解析 露光 条件比較 モデル 成膜';
dataSheet('WordCloud',['Text'],[[text]]); sheets.WordCloud.getRange('A1:A2').format.columnWidth=110;
await fs.writeFile(path.join(root,'sample_wordcloud.txt'),text+'\n');
wb.recalculate();
const errors=await wb.inspect({kind:'match',searchTerm:'#REF!|#DIV/0!|#VALUE!|#NAME\\?|#N/A|#NUM!|#NULL!',options:{useRegex:true,maxResults:30},summary:'Sample formula errors'});
await fs.writeFile(path.join(previews,'formula-scan.ndjson'),errors.ndjson);
const probes={}; for(const name of titles)probes[name]=sheets[name].getRange(name==='使い方'?'G5:H8':'A1:G4').values;
await fs.writeFile(path.join(previews,'sample-probes.json'),JSON.stringify(probes,null,2));
for(const name of titles){const preview=await wb.render({sheetName:name,range:name==='使い方'?'A1:H18':name==='WordCloud'?'A1:A2':'A1:G12',scale:1.5,format:'png'}); await fs.writeFile(path.join(previews,`${name}.png`),new Uint8Array(await preview.arrayBuffer()));}
const output=await SpreadsheetFile.exportXlsx(wb); await output.save(path.join(previews,'ProcessInsight_Samples.xlsx'));
await fs.copyFile(path.join(previews,'ProcessInsight_Samples.xlsx'),path.join(root,'ProcessInsight_Samples.xlsx'));
console.log(JSON.stringify({path:path.join(root,'ProcessInsight_Samples.xlsx'),sheets:titles.length,previews,formulaScan:errors.ndjson}));
