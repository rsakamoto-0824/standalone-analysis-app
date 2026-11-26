classdef TestFileReaders < matlab.unittest.TestCase
    % Excel・CSV の自前の読み取り（配布版で readcell・sheetnames・readtable が止まる問題への対策）の確認。
    methods (TestClassSetup)
        function paths(testCase)
            root=fileparts(fileparts(mfilename('fullpath')));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(root)); setup_paths();
        end
    end
    methods (Test)
        function xlsxMatchesReadcellOnSampleSheets(testCase)
            root=fileparts(fileparts(mfilename('fullpath'))); file=fullfile(root,'samples','ProcessInsight_Samples.xlsx');
            [~,sheets]=read_xlsx_cells(file);
            testCase.verifyEqual(sheets,cellstr(sheetnames(file))');
            for sheet={'使い方','APC','Swing_Base','Generic','Predict_SHAP','DOE_Existing','WordCloud'}
                testCase.verifyTrue(TestFileReaders.sameCells(read_xlsx_cells(file,sheet{1}),readcell(file,'Sheet',sheet{1},'UseExcel',false)),sheet{1});
            end
            % 数式が空の文字を返すセル（Furnace の未計測）は、空欄として読む。
            furnace=read_xlsx_cells(file,'Furnace');
            testCase.verifyTrue(isscalar(furnace{3,3}) && ismissing(furnace{3,3}));
            testCase.verifyError(@()read_xlsx_cells(file,'ありません'),'read_xlsx_cells:sheet');
        end
        function xlsxHandlesTextTypesAndLeadingBlanks(testCase)
            fixture=testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture); file=fullfile(fixture.Folder,'t.xlsx');
            writecell({'名前','値','真偽';'a&b <x>',1.25,true;'',[],false},file,'Sheet','S','Range','B3');
            cells=read_xlsx_cells(file,'S'); expected=readcell(file,'Sheet','S','UseExcel',false);
            testCase.verifyTrue(TestFileReaders.sameCells(cells,expected));
            testCase.verifyEqual(cells{2,1},'a&b <x>'); testCase.verifyEqual(cells{1,1},'名前');
        end
        function xlsxDropsPhoneticReading(testCase)
            % 日本語の Excel は、漢字の読み（ふりがな）を <rPh> に入れて保存する。読みを文字の末尾へ足さない。
            fixture=testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture); folder=fixture.Folder;
            plain=fullfile(folder,'plain.xlsx'); writecell({'温度','地名';1,'東京'},plain);
            parts=fullfile(folder,'parts'); unzip(plain,parts);
            shared=fullfile(parts,'xl','sharedStrings.xml'); xml=fileread(shared);
            xml=strrep(xml,'<t>温度</t>','<t>温度</t><rPh sb="0" eb="2"><t>オンド</t></rPh><phoneticPr fontId="1"/>');
            xml=strrep(xml,'<t>東京</t>',sprintf('<r><t>東京</t></r><rPh sb="0" eb="2">\n<t>トウキョウ</t></rPh>'));
            testCase.assertEqual(numel(strfind(xml,'<rPh ')),2);
            file_id=fopen(shared,'w','n','UTF-8'); fwrite(file_id,xml,'char'); fclose(file_id);
            phonetic=fullfile(folder,'phonetic.xlsx'); zip(fullfile(folder,'phonetic.zip'),{'*'},parts); movefile(fullfile(folder,'phonetic.zip'),phonetic);
            testCase.verifyEqual(read_xlsx_cells(phonetic,1),{'温度','地名';1,'東京'});
        end
        function csvParsesQuotesEncodingsAndText(testCase)
            fixture=testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            quoted=fullfile(fixture.Folder,'q.csv'); write(quoted,unicode2native(sprintf('名前,"値, 含む",X\n"a""b",1.5,\n,,3\n'),'UTF-8'));
            testCase.verifyTrue(TestFileReaders.sameCells(read_csv_cells(quoted),readcell(quoted,'FileType','text','Delimiter',',','EmptyLineRule','read')));
            sjis=fullfile(fixture.Folder,'s.csv'); write(sjis,unicode2native(sprintf('膜厚,屈折率\r\n1,2\r\n'),'Shift_JIS'));
            testCase.verifyEqual(read_csv_cells(sjis),{'膜厚','屈折率';1,2});
            bom=fullfile(fixture.Folder,'b.csv'); write(bom,[uint8([239,187,191]),unicode2native(sprintf('列A,列B\n0012,x\n'),'UTF-8')]);
            testCase.verifyEqual(read_csv_cells(bom),{'列A','列B';12,'x'});
            testCase.verifyEqual(read_csv_cells(bom,true),{'列A','列B';'0012','x'});
            broken=fullfile(fixture.Folder,'e.csv'); write(broken,uint8('a,"b\n'));
            testCase.verifyError(@()read_csv_cells(broken),'read_csv_cells:quote');
            function write(path,bytes)
                file=fopen(path,'w'); fwrite(file,bytes,'uint8'); fclose(file);
            end
        end
        function inputDataUsesOwnReaders(testCase)
            root=fileparts(fileparts(mfilename('fullpath'))); file=fullfile(root,'samples','ProcessInsight_Samples.xlsx');
            source=read_input_data(file,'Generic',1);
            testCase.verifyEqual(source.Headers,{'X1','X2','X3','Y1','Y2'}); testCase.verifyEqual(source.RowNumbers(1),2);
            fixture=testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture); csv=fullfile(fixture.Folder,'f.csv');
            file_id=fopen(csv,'w'); fprintf(file_id,'WaferId,BoatSlot,膜厚\n0001,5,100\n0002,15,\n'); fclose(file_id);
            furnace=read_furnace_data(csv,1,1);
            testCase.verifyEqual(furnace.Cells{1,1},"0001"); testCase.verifyTrue(ismissing(furnace.Cells{2,3}));
        end
    end
    methods (Static)
        function same=sameCells(a,b)
            same=isequal(size(a),size(b));
            for index=1:numel(a)
                if ~same, return; end
                x=a{index}; y=b{index}; xm=isscalar(x)&&ismissing(x); ym=isscalar(y)&&ismissing(y);
                if xm||ym, same=xm==ym; elseif isnumeric(x)&&isnumeric(y), same=abs(x-y)<=1e-9*max(1,abs(y));
                else, same=isequal(string(x),string(y)); end
            end
        end
    end
end
