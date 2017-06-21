function CA = PRNCode(PRN, num)
%% SHERPA Gold Code Generator
if nargin == 1
    n = 1023;
else
    n = num;
end
num = 15;
CA = zeros(1,n)';

fbIndices1 = [8 15];
fbIndices2 = [15, 14, 13, 12, 11, 9];

SV = [
        [2 6]; % 1
        [3 7]; % 2
        [4 8]; % 3
        [5 9]; % 4
      ];

G1 = ones(1,num);
G2 = ones(1,num);

for i = 1:n
    
    CA(i) = mod(sum([G1(num), G2(SV(PRN,:))]), 2);
    
    fb1 = mod(sum(G1(fbIndices1)), 2);
    fb2 = mod(sum(G2(fbIndices2)), 2);

    
    G1 = [fb1 G1(1:num-1)];
    G2 = [fb2 G2(1:num-1)];
end

CA = CA * 2 - 1;
end