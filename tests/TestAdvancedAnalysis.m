classdef TestAdvancedAnalysis < matlab.unittest.TestCase
    % 変数重要度（Permutation Importance・VIP）、Pro 版の GPR（加法カーネル・質的変数）、
    % Sobol 感度解析・因果探索・階層ベイズ、メニューの番号の確認。
    methods (TestClassSetup)
        function paths(testCase)
            root=fileparts(fileparts(mfilename('fullpath')));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(root)); setup_paths();
            testCase.assumeTrue(strcmp(version('-release'),'2025b') || strcmp(getenv('PROCESS_INSIGHT_DEV_RELEASE'),'allow'), ...
                'GPR の学習は R2025b（または開発用の例外）で確認します。');
        end
    end
    methods (Test)
        function permutationImportanceRanksEffects(testCase)
            rng(1); x=randn(200,3); y=3*x(:,1)+x(:,2);
            result=calc_permutation_importance(@(z) 3*z(:,1)+z(:,2),x,y,{'A','B','C'},5,0);
            testCase.verifyEqual(result.BaseRMSE,0,'AbsTol',1e-12);
            testCase.verifyGreaterThan(result.Table.("RMSEの増加")(1),result.Table.("RMSEの増加")(2));
            testCase.verifyEqual(result.Table.("RMSEの増加")(3),0,'AbsTol',1e-12);
            again=calc_permutation_importance(@(z) 3*z(:,1)+z(:,2),x,y,{'A','B','C'},5,0);
            testCase.verifyEqual(again.Table,result.Table);
        end
        function vipSquaresAverageToOne(testCase)
            rng(2); x=randn(60,4); y=x(:,1)-0.5*x(:,2)+0.1*randn(60,1);
            model=ProcessRegressionModel(x,y,{'A','B','C','D'},'pls',2);
            testCase.verifyEqual(mean(model.Vip.^2),1,'AbsTol',1e-10);
            testCase.verifyGreaterThan(model.Vip(1),1); testCase.verifyLessThan(model.Vip(4),1);
        end
        function menuNumbersDependOnEdition(testCase)
            standard=AnalysisController.menuTitles('standard'); pro=AnalysisController.menuTitles('pro');
            testCase.verifyEqual({standard.predict,standard.doe,standard.settings,standard.help},{'5 保存モデルで推定・SHAP','6 実験計画作成','7 設定','8 Help'});
            testCase.verifyFalse(any(isfield(standard,{'sobol','causal','bayes','copula','words'})));
            testCase.verifyEqual({pro.sobol,pro.causal,pro.bayes,pro.copula,pro.doe,pro.words,pro.settings,pro.help}, ...
                {'6 Sobol感度解析','7 因果探索','8 階層ベイズ','9 コピュラ乱数生成','10 実験計画作成','11 ワードクラウド','12 設定','13 Help'});
        end
    end
    % Pro 版だけの機能のテスト。通常版のビルド（run_tests('standard')）では実行しない。
    methods (Test, TestTags = {'Pro'})
        function additiveAndCategoricalGprFitAndRoundtrip(testCase)
            rng(3); n=80; group=randi(3,n,1); offsets=[0;2;-1]; x=[rand(n,2)*2-1,group];
            y=sin(2*x(:,1))+x(:,2).^2+offsets(group)+0.05*randn(n,1); levels={[],[],["T1";"T2";"T3"]};
            fixture=testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            for additive=[true,false]
                model=ProcessRegressionModel(x,y,{'A','B','Tool'},'gpr_pro',2,[],struct('Additive',additive,'Categorical',[false,false,true],'Levels',{levels}));
                testCase.verifyLessThan(sqrt(mean((predict(model,x)-y).^2)),0.2);
                path=fullfile(fixture.Folder,sprintf('gp%d.mat',additive)); report=save_regression_model(model,path);
                testCase.verifyTrue(report.Success); loaded=load_analysis_model(path);
                testCase.verifyEqual(predict(loaded,x),predict(model,x),'AbsTol',1e-10);
            end
            testCase.verifyEqual(model.methodLabel(),'GPR（ARD二乗指数×質的変数）');
            testCase.verifyError(@()predict(model,[0,0,4]),'regression:categoricalCodes');
        end
        function categoricalColumnsAreEncodedForTrainingAndPrediction(testCase)
            data=struct('Headers',{{'X','Tool','Y'}},'Cells',{{1,'B',3;2,'A',4;3,'B',5;4,'C',6}},'RowNumbers',(2:5)');
            [inputs,~,~,~,levels]=modeling_input_data(data,{1,'X','X';2,'Tool','Tool'},{'Y'},{'Tool'});
            testCase.verifyEqual(inputs(:,2)',[2,1,2,3]); testCase.verifyEqual(levels{2},["A";"B";"C"]);
            other=data; other.Cells{1,2}='D';
            testCase.verifyError(@()encode_categories(other,'Tool',levels{2}),'encode_categories:unknownLevel');
            conditions=modeling_conditions({'additive'},{'gpr'},'exact',2,100,struct(),[],struct('Mask',[false,true],'Levels',{levels}));
            testCase.verifyEqual(modeling_condition_label(conditions(1)),'GPR（加法カーネル・質的変数）');
            % 質的変数は GPR 以外の方式でも使える（2026-11-26 から）。各条件に同じ質的変数の情報を持たせる。
            mixed=modeling_conditions({'additive'},{'gpr','linear'},'exact',2,100,struct(),[],struct('Mask',[false,true],'Levels',{levels}));
            testCase.verifyEqual(mixed(2).Categorical.Mask,[false,true]); testCase.verifyEqual(modeling_condition_label(mixed(2)),'重回帰');
        end
        function sobolMatchesIshigamiFunction(testCase)
            % Ishigami 関数（a=7, b=0.1）の理論値：S1 = [0.314, 0.442, 0]、ST = [0.558, 0.442, 0.244]。
            f=@(x) sin(x(:,1))+7*sin(x(:,2)).^2+0.1*x(:,3).^4.*sin(x(:,1))+100;
            result=calc_sobol_indices(f,-pi*[1,1,1],pi*[1,1,1],{'x1','x2','x3'},struct('SampleSize',4096,'Bootstrap',50));
            testCase.verifyEqual(result.Table.S1',[0.314,0.442,0],'AbsTol',0.03);
            testCase.verifyEqual(result.Table.ST',[0.558,0.442,0.244],'AbsTol',0.03);
            testCase.verifyEqual(result.Evaluations,4096*5);
            testCase.verifyError(@()calc_sobol_indices(f,[0,0,0],[1,-1,1],{'a','b','c'},struct()),'sobol:range');
        end
        function sobolSamplesCategoricalLevels(testCase)
            offsets=[0;5;-5]; f=@(x) offsets(x(:,2))+0.1*x(:,1);
            result=calc_sobol_indices(f,[0,1],[1,3],{'x','g'},struct('SampleSize',512,'Bootstrap',20,'Categorical',[false,true],'LevelCounts',[0,3]));
            testCase.verifyGreaterThan(result.Table.ST(2),0.95);
        end
        function causalDiscoveryRecoversChain(testCase)
            % 誤差は一様分布（非正規）。各段の効果を誤差より十分大きくして、順序がはっきり決まるデータにする。
            rng(0); n=1000; noise=@() 0.3*(rand(n,1)*2-1); a=rand(n,1)*2-1; b=0.8*a+noise(); c=0.8*b+noise(); d=0.8*c+noise();
            pc=causal_discovery([a,b,c,d],{'a','b','c','d'},'pc',struct());
            skeleton=pc.Adjacency|pc.Adjacency';
            testCase.verifyEqual(skeleton,logical([0,1,0,0;1,0,1,0;0,1,0,1;0,0,1,0]));
            lingam=causal_discovery([a,b,c,d],{'a','b','c','d'},'lingam',struct());
            testCase.verifyEqual(lingam.Order,[1,2,3,4]);
            % 本当の辺（a→b→c→d）はすべて残り、ほかに残った辺の係数は小さい（検定の偶然による誤検出）。
            testCase.verifyTrue(all(lingam.Adjacency([5,10,15])==1));
            extra=lingam.Strength; extra([5,10,15])=0; testCase.verifyLessThan(max(abs(extra(:))),0.1);
            % V字構造 x→z←y は向きが決まる。
            rng(7); x=randn(n,1); y=randn(n,1); z=x+y+0.3*randn(n,1);
            collider=causal_discovery([x,y,z],{'x','y','z'},'pc',struct());
            testCase.verifyEqual(collider.Adjacency,[0,0,1;0,0,1;0,0,0]);
        end
        function hierarchicalBayesShrinksSmallGroups(testCase)
            rng(5); sizes=[3,40,40,40]; groups=repelem(1:4,sizes)'; x=randn(numel(groups),1);
            intercepts=[6;1;2;3]; y=intercepts(groups)+1.5*x+0.5*randn(numel(groups),1);
            result=hierarchical_bayes(y,x,groups,{'x'},"G"+(1:4),struct('Varying','intercept','Iterations',1500,'BurnIn',500));
            testCase.verifyLessThan(result.MaxRhat,1.1);
            slope=result.Overall(result.Overall.("項")=="x",:);
            testCase.verifyEqual(slope.("事後平均"),1.5,'AbsTol',0.15);
            first=result.Groups(result.Groups.("グループ")=="G1" & result.Groups.("項")=="切片",:);
            % データの少ないグループの切片は、グループ単独の最小二乗より全体の平均に近い（縮小）。
            overall=result.Overall.("事後平均")(1);
            testCase.verifyLessThan(abs(first.("事後平均")-overall),abs(first.("グループ単独の最小二乗")-overall));
            testCase.verifyError(@()hierarchical_bayes(y,x,ones(size(y)),{'x'},"G1",struct()),'bayes:groups');
        end
    end
end
