classdef TestDataTools < matlab.unittest.TestCase
    % データからの Sobol 感度解析、予測値の分布の要約、帯の色の列、コピュラによる乱数生成、ワードクラウドの除く語の確認。
    methods (TestClassSetup)
        function paths(testCase)
            root=fileparts(fileparts(mfilename('fullpath')));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(root)); setup_paths();
        end
    end
    methods (Test)
        function givenDataFirstOrderMatchesLinearModel(testCase)
            % y = 2a + b（a・b は独立な一様分布）の1次の指数は 4/5 と 1/5。
            rng(3); x=rand(4000,3); y=2*x(:,1)+x(:,2);
            s1=calc_sobol_given_data(x,y);
            testCase.verifyEqual(s1,[0.8,0.2,0],'AbsTol',0.03);
            testCase.verifyError(@()calc_sobol_given_data(x(1:5,:),y(1:5)),'sobol:rows');
        end
        function sobolUsesEmpiricalMarginals(testCase)
            % 経験分布で動かすと、入力は元のデータの範囲に収まり、y = a の指数は a だけが1になる。
            rng(4); data=[randn(500,1).^2, rand(500,1)];
            result=calc_sobol_indices(@(x) x(:,1),min(data),max(data),{'a','b'},struct('SampleSize',512,'Bootstrap',20,'Marginals',{num2cell(data,1)}));
            testCase.verifyEqual(result.Table.ST',[1,0],'AbsTol',0.02);
            testCase.verifyGreaterThanOrEqual(min(result.Predictions),min(data(:,1)));
            testCase.verifyLessThanOrEqual(max(result.Predictions),max(data(:,1)));
        end
        function distributionSummaryOfNormalSample(testCase)
            rng(5); values=10+2*randn(20000,1);
            summary=calc_distribution_summary(values,3);
            testCase.verifyEqual([summary.Average,summary.Deviation],[10,2],'AbsTol',0.1);
            % 最頻値は密度の山の頂点で、正規分布の山は平らなため平均より大きくずれうる。
            testCase.verifyEqual(summary.Mode,10,'AbsTol',0.3);
            testCase.verifyEqual(summary.Interval,10+2*norminv([0.025,0.975]),'AbsTol',0.1);
            rows=summary.Table(startsWith(summary.Table.("項目"),"平均 ± "),:);
            testCase.verifyEqual(rows.("入る割合_percent"),[68.27;95.45;99.73],'AbsTol',1);
        end
        function flowColorsByCategoryAndNumber(testCase)
            groups=[1,1;1,2;2,2;2,2;1,1;2,1]; values=[1;2;3;4;5;6];
            for style={'sets','sankey'}
                category=category_flow_layout(groups,[2,2],style{1},struct('Mode','category','Values',[1;2;1;2;1;2]));
                testCase.verifyEqual(sum(category.Ribbons.Count(category.Ribbons.Column==1)),6,style{1});
                testCase.verifyTrue(all(ismember(category.Ribbons.Color,[1,2])),style{1});
                numeric=category_flow_layout(groups,[2,2],style{1},struct('Mode','numeric','Values',values));
                testCase.verifyTrue(all(isnan(numeric.Ribbons.Color)) && all(isfinite(numeric.Ribbons.Value)),style{1});
                % 1→1 の帯（行1と5）の平均は3。
                first=numeric.Ribbons(numeric.Ribbons.FromLevel==1 & numeric.Ribbons.ToLevel==1,:);
                testCase.verifyEqual(first.Value,3,style{1});
            end
        end
        function copulaFromDataKeepsRankCorrelation(testCase)
            rng(6); z=mvnrnd([0,0,0],[1,0.7,0.3;0.7,1,0.5;0.3,0.5,1],800); data=[exp(z(:,1)),10+2*z(:,2),z(:,3).^3];
            for family={'Gaussian','t'}
                model=copula_fit_data(data,{'a','b','c'},family{1},'empirical');
                samples=copula_generate(model,4000,1); report=copula_compare(model,samples);
                testCase.verifyEqual(report.Dependence{:,4},report.Dependence{:,3},'AbsTol',0.05,family{1});
                testCase.verifyGreaterThanOrEqual(min(samples(:,1)),min(data(:,1)));
            end
            again=copula_generate(model,10,1); testCase.verifyEqual(again,copula_generate(model,10,1));
            testCase.verifyError(@()copula_fit_data(data,{'a','b','c'},'Clayton','empirical'),'copula:bivariate');
            testCase.verifyError(@()copula_fit_data([data(:,1),-data(:,1)],{'a','b'},'Gaussian','Lognormal'),'copula:positive');
        end
        function copulaFromSpecificationMatchesTargets(testCase)
            spec={struct('Code','Normal','Parameters',[0,1]),struct('Code','Uniform','Parameters',[0,10]),struct('Code','Lognormal','Parameters',[0,0.5])};
            target=[1,0.5,0.2;0.5,1,0.3;0.2,0.3,1];
            model=copula_from_spec({'p','q','r'},spec,target,'spearman','Gaussian');
            samples=copula_generate(model,20000,2); report=copula_compare(model,samples);
            testCase.verifyEqual(report.Dependence{:,6},[0.5;0.2;0.3],'AbsTol',0.03);
            testCase.verifyTrue(all(samples(:,2)>=0 & samples(:,2)<=10) && all(samples(:,3)>0));
            gumbel=copula_from_spec({'p','q'},spec(1:2),[1,0.4;0.4,1],'kendall','Gumbel');
            report=copula_compare(gumbel,copula_generate(gumbel,5000,3));
            testCase.verifyEqual(report.Dependence{1,4},0.4,'AbsTol',0.03);
            testCase.verifyError(@()copula_from_spec({'p','q','r'},spec,[1,0.9,-0.9;0.9,1,0.9;-0.9,0.9,1],'kendall','Gaussian'),'copula:positiveDefinite');
            testCase.verifyError(@()copula_from_spec({'p','q'},spec(1:2),[1,-0.3;-0.3,1],'kendall','Clayton'),'copula:negative');
            testCase.verifyError(@()copula_from_spec({'p','q'},spec(1:2),[1,0.3;0.2,1],'kendall','Gaussian'),'copula:symmetric');
        end
        function wordCloudExcludesCommonWords(testCase)
            [words,counts]=create_wordCloud('I think it is good and We are happy. It was data data',[english_stop_words(),{'data'}]);
            testCase.verifyEqual(sort(words)',{'good','happy','think'}); testCase.verifyEqual(counts',[1,1,1]);
            words=create_wordCloud('It is it');
            testCase.verifyEqual(words',{'is','it'});
        end
    end
end
