classdef TestCancellation < matlab.unittest.TestCase
    % 処理の途中停止（進捗バーの「キャンセル」）の確認。
    methods (TestClassSetup)
        function paths(testCase)
            root=fileparts(fileparts(mfilename('fullpath')));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(root)); setup_paths();
        end
    end
    methods (Test)
        function reporterUpdatesAndStopsWhenCancelled(testCase)
            dialog=FakeProgressDialog(); reporter=AnalysisController.progressReporter(dialog,'テストを中止しました。');
            reporter(1,4,'1つ目');
            testCase.verifyEqual(dialog.Value,0.25); testCase.verifyTrue(contains(dialog.Message,'1つ目'));
            testCase.verifyEqual(char(dialog.Indeterminate),'off');
            % 画面の更新とキャンセルの受け取りは0.2秒に1回だけのため、間隔をあけてから呼ぶ
            % （すぐ次の呼び出しが飛ばされるかは計算機の混み具合で変わるため、ここでは確かめない）。
            dialog.CancelRequested=true;
            pause(0.25); testCase.verifyError(@()reporter(2,4,'2つ目'),'AnalysisApp:cancelled');
            % 最後（done = total）は間隔によらず受け取る。
            dialog.CancelRequested=false; reporter(3,4,'3つ目'); dialog.CancelRequested=true;
            testCase.verifyError(@()reporter(4,4,'最後'),'AnalysisApp:cancelled');
            % 閉じた（削除した）進捗バーでは何もしない。
            delete(dialog); reporter(3,4,'3つ目');
        end
        function designStopsWhenCancelled(testCase)
            calls=0; stop=@(done,total,stage) TestCancellation.stopAt(3);
            testCase.verifyError(@()create_experiment_design('D',3,12,0,'quadratic',3,[],stop),'AnalysisApp:cancelled');
            % 進捗の関数を渡しても、渡さないときと同じ計画になる。
            [plain,~]=create_experiment_design('D',3,12,0,'quadratic',3);
            [watched,~]=create_experiment_design('D',3,12,0,'quadratic',3,[],@count);
            testCase.verifyEqual(watched,plain); testCase.verifyGreaterThan(calls,0);
            function count(done,total,~)
                calls=calls+1; testCase.assertLessThanOrEqual(done,total);
            end
        end
    end
    methods (Test, TestTags = {'Pro'})
        function proAnalysesStopWhenCancelled(testCase)
            rng(1); x=rand(200,3); y=x*[1;2;3]+0.1*randn(200,1);
            testCase.verifyError(@()calc_sobol_indices(@(v) v*[1;2;3],[0 0 0],[1 1 1],{'a','b','c'}, ...
                struct('SampleSize',256,'Bootstrap',20,'Progress',@(~,~,~) TestCancellation.stopAt(2))),'AnalysisApp:cancelled');
            testCase.verifyError(@()causal_discovery(x,{'a','b','c'},'pc',struct('Progress',@(~,~,~) TestCancellation.stopAt(2))),'AnalysisApp:cancelled');
            testCase.verifyError(@()causal_discovery(x,{'a','b','c'},'lingam',struct('Progress',@(~,~,~) TestCancellation.stopAt(2))),'AnalysisApp:cancelled');
            groups=repelem((1:4)',50);
            testCase.verifyError(@()hierarchical_bayes(y,x(:,1),groups,{'a'},"G"+(1:4), ...
                struct('Iterations',400,'BurnIn',100,'Progress',@(~,~,~) TestCancellation.stopAt(3))),'AnalysisApp:cancelled');
            % 進捗の関数を渡しても結果は同じ（Sobol の予測を分けて計算しても値は変わらない）。
            f=@(v) sin(v(:,1))+v(:,2).^2;
            plain=calc_sobol_indices(f,[0 0],[1 1],{'a','b'},struct('SampleSize',8192,'Bootstrap',20));
            last=[0,0];
            watched=calc_sobol_indices(f,[0 0],[1 1],{'a','b'},struct('SampleSize',8192,'Bootstrap',20,'Progress',@remember));
            testCase.verifyEqual(watched.Table,plain.Table); testCase.verifyEqual(last(1),last(2));
            function remember(done,total,~)
                last=[done,total];
            end
        end
    end
    methods (Static)
        function stopAt(limit)
            % limit 回目に呼ばれたら、キャンセルが押されたときと同じエラーで止める。
            persistent calls
            if isempty(calls), calls=0; end
            calls=calls+1;
            if calls>=limit, calls=0; error('AnalysisApp:cancelled','テストの途中停止'); end
        end
    end
end
