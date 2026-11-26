classdef (TestTags = {'Pro'}) TestCausalKnowledge < matlab.unittest.TestCase
    % 因果探索の事前の知識（あり得ない向き・因果はない・因果がある）の確認。
    methods (TestClassSetup)
        function paths(testCase)
            root=fileparts(fileparts(mfilename('fullpath')));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(root)); setup_paths();
        end
    end
    methods (Test)
        function knowledgeMatricesAndConflicts(testCase)
            names={'a','b','c'};
            knowledge=causal_knowledge(names,{'a','forbidden','b';'b','none','c';'a','required','c'});
            testCase.verifyEqual(knowledge.Forbidden,logical([0,1,0;0,0,1;0,1,0]));
            testCase.verifyEqual(knowledge.Required,logical([0,0,1;0,0,0;0,0,0]));
            testCase.verifyError(@()causal_knowledge(names,{'a','required','b';'a','forbidden','b'}),'causal:knowledgeConflict');
            testCase.verifyError(@()causal_knowledge(names,{'a','required','b';'b','required','a'}),'causal:knowledgeConflict');
            testCase.verifyError(@()causal_knowledge(names,{'a','required','b';'b','required','c';'c','required','a'}),'causal:knowledgeCycle');
            testCase.verifyError(@()causal_knowledge(names,{'a','forbidden','x'}),'causal:knowledgeColumn');
            testCase.verifyError(@()causal_knowledge(names,{'a','forbidden','a'}),'causal:knowledgeSelf');
        end
        function pcFollowsKnowledge(testCase)
            % 鎖 a→b→c は、データだけでは向きが決まらない（a―b―c）。知識で向きを決め、Meek の規則で残りも決まる。
            rng(1); n=800; a=randn(n,1); b=0.8*a+0.5*randn(n,1); c=0.8*b+0.5*randn(n,1); values=[a,b,c]; names={'a','b','c'};
            plain=causal_discovery(values,names,'pc',struct());
            testCase.verifyEqual(plain.Adjacency,[0,1,0;1,0,1;0,1,0]);
            % b→a はあり得ない → a→b、さらに R1 で b→c。
            given=causal_discovery(values,names,'pc',struct('Knowledge',causal_knowledge(names,{'b','forbidden','a'})));
            testCase.verifyEqual(given.Adjacency,[0,1,0;0,0,1;0,0,0]);
            % b と c の間に因果はない → 辺を作らない。
            none=causal_discovery(values,names,'pc',struct('Knowledge',causal_knowledge(names,{'b','none','c'})));
            testCase.verifyEqual(none.Adjacency,[0,1,0;1,0,0;0,0,0]);
            % 独立な列どうしでも、「因果がある」と指定した辺は残り、表に指定と書く。
            rng(2); x=randn(n,1); y=randn(n,1);
            kept=causal_discovery([x,y],{'x','y'},'pc',struct('Knowledge',causal_knowledge({'x','y'},{'x','required','y'})));
            testCase.verifyEqual(kept.Adjacency,[0,1;0,0]); testCase.verifyEqual(kept.Edges.("事前の知識"),"因果がある（指定）");
        end
        function meekRuleOrientsAfterCollider(testCase)
            % x→z←y（V字構造）のあと、z―w は Meek の規則 R1 で z→w に決まる。
            % 以前は規則の判定が更新前の向きを見ていたため、規則で向きが決まると繰り返しが終わらなかった。
            rng(3); n=1000; x=randn(n,1); y=randn(n,1); z=x+y+0.5*randn(n,1); w=0.8*z+0.5*randn(n,1);
            result=causal_discovery([x,y,z,w],{'x','y','z','w'},'pc',struct());
            testCase.verifyEqual(result.Adjacency,[0,0,1,0;0,0,1,0;0,0,0,1;0,0,0,0]);
        end
        function lingamFollowsKnowledge(testCase)
            rng(0); n=1000; noise=@() 0.3*(rand(n,1)*2-1); a=rand(n,1)*2-1; b=0.8*a+noise(); c=0.8*b+noise();
            values=[a,b,c]; names={'a','b','c'};
            % 「c → a の因果がある」と指定すると、c を a より前に並べ、その辺を残す。
            given=causal_discovery(values,names,'lingam',struct('Knowledge',causal_knowledge(names,{'c','required','a'})));
            testCase.verifyLessThan(find(given.Order==3),find(given.Order==1)); testCase.verifyEqual(given.Adjacency(3,1),1);
            % 「a → b はあり得ない」と指定すると、a→b の辺を作らない。
            blocked=causal_discovery(values,names,'lingam',struct('Knowledge',causal_knowledge(names,{'a','forbidden','b'})));
            testCase.verifyEqual(blocked.Adjacency(1,2),0);
            testCase.verifyEqual(blocked.Edges.Properties.VariableNames,{'元','向き','先','係数_標準化','事前の知識'});
        end
    end
end
