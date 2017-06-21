%%%%%%%%%%%%%%%
%% Load Data %%
%%%%%%%%%%%%%%%
clear; clc;

fprintf('Loading Data..');
fileID = fopen('data.bin');
dataRaw = uint8(fread(fileID,inf,'uint8'));

sampleRate = 3276600;
msgLength  = 32767;
CA1 = PRNCode(1,msgLength);

fprintf('.Done!\n');

%%%%%%%%%%%%%%%%%%
%% Unfold Data %%%
%%%%%%%%%%%%%%%%%%
fprintf('Unfolding Data..');

I = zeros(length(dataRaw),4);
I(:,1) = bitand(dataRaw,1)   / 1;
I(:,2) = bitand(dataRaw,2)   / 2;
I(:,3) = bitand(dataRaw,4)   / 4;
I(:,4) = bitand(dataRaw,8)   / 8;
I = I * 2 - 1;

Q = zeros(length(dataRaw),4);
Q(:,1) = bitand(dataRaw,16)  / 16;
Q(:,2) = bitand(dataRaw,32)  / 32;
Q(:,3) = bitand(dataRaw,64)  / 64;
Q(:,4) = bitand(dataRaw,128) / 128;
Q = Q * 2 - 1; Q = -Q; % Q is inverted on the PCB

t = ((0:length(I)-1)/sampleRate)';
N = floor(length(I)/msgLength)-4;

fprintf('.Done!\n');

clear dataRaw dataUnfold fileID;
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Find initial integer delay %%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
fprintf('Determining Initial Integer Delay..');

CA1_S  = fft(CA1,msgLength);
A_S    = fft(I(1:msgLength,1));
B_S    = fft(Q(1:msgLength,1));

ACA1_S = A_S .* conj(CA1_S);
BCA1_S = B_S .* conj(CA1_S);
ACA1   = ifft(ACA1_S);
BCA1   = ifft(BCA1_S);

index = find(sqrt(BCA1.^2+ACA1.^2) > 2000);
%index = index(1) + msgLength-1;
startIndices = index:(msgLength-1): ...
              (index+(msgLength-1)*(N-1));
initialIntDelay = index - (msgLength-1);    

fprintf('.Done!\n');

figure
plot(sqrt(BCA1.^2+ACA1.^2))
hold on; plot(sqrt(BCA1.^2+ACA1.^2),'o'); hold off;
xlim([-10 10] + startIndices(1))
xlabel('Sample #')
ylabel('Correlation (XCVR 1)')

%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Find fractional delay %%
%%%%%%%%%%%%%%%%%%%%%%%%%%%
pulseformAvg1 = zeros(3*msgLength,1);
pulseformAvg2 = zeros(3*msgLength,1);
mixIQ1 = zeros(3*msgLength,1);
mixIQ2 = zeros(3*msgLength,1);
fracDelay1 = zeros(length(startIndices)-50,1);
fracDelay2 = zeros(length(startIndices)-50,1);

risingEdge1 = 0; risingEdge2 = 0;
fallingEdge1 = 0; fallingEdge2 = 0;
startOffset = 0;

ii1 = 0; ii2 = 0;
qq1 = 0; qq2 = 0;
n = 3; start = -2;
code = repmat(CA1,n,1);
for i = 1:length(startIndices)
    idx = startIndices(i) + 1 + startOffset;  
    
    % Mixing with code
    mixI1 = code .* I(idx+start:idx+(2^15-1)*n-1+start,1);
    mixI2 = code .* I(idx+start:idx+(2^15-1)*n-1+start,2);
    mixQ1 = code .* Q(idx+start:idx+(2^15-1)*n-1+start,1);
    mixQ2 = code .* Q(idx+start:idx+(2^15-1)*n-1+start,2);
    
    % Averaging and combination of channels
    ii1 = 0; ii2 = 0;
    qq1 = 0; qq2 = 0;
    for j = 1:32767*3
        ii1 = ii1 * 0.9998 + 0.0002 * mixI1(j);
        ii2 = ii2 * 0.9998 + 0.0002 * mixI2(j);
        qq1 = qq1 * 0.9998 + 0.0002 * mixQ1(j);
        qq2 = qq2 * 0.9998 + 0.0002 * mixQ2(j);
        
        mixIQ1(j) = sqrt(ii1^2 + qq1^2);
        mixIQ2(j) = sqrt(ii2^2 + qq2^2);
    end
    
    % Averaging pulseforms
    pulseformAvg1 = min(pulseformAvg1 * 0.95 + 0.05 * mixIQ1,1);
    pulseformAvg2 = min(pulseformAvg2 * 0.95 + 0.05 * mixIQ2,1);

    % Finding rising and falling edges
    if (i > 50)
        risingEdge1 = find(pulseformAvg1 > 0.2);
        risingEdge2 = find(pulseformAvg2 > 0.2);
        if (length(risingEdge1) > 1)
            fracDelay1(i-50) = risingEdge1(1);
            fracDelay2(i-50) = risingEdge2(1);
            fallingEdge1 = find(pulseformAvg1 < 0.3);
            fallingEdge2 = find(pulseformAvg2 < 0.3);
            if (length(fallingEdge1) > 0)
                fallingEdge1 = ...
                    fallingEdge1(fallingEdge1 > risingEdge1(1)+30000);
                fallingEdge2 = ...
                    fallingEdge2(fallingEdge2 > risingEdge2(1)+30000);
                if (length(fallingEdge1) > 0)
                   fracDelay1(i-20) = (fallingEdge1(1) + risingEdge1(1))/2;
                   fracDelay2(i-20) = (fallingEdge2(1) + risingEdge2(1))/2;
                end
             end
        end
    end
    
    % Handling edge cases
    if (i > 50)
        if (risingEdge1(1) < 32766*0.25 || ...
            risingEdge2(1) < 32766*0.25)
            startOffset = startOffset - 1;
            pulseformAvg1 = circshift(pulseformAvg1,32766);
            pulseformAvg2 = circshift(pulseformAvg2,32766);
        elseif (fallingEdge1(1) > 32766*2.75 || ...
                fallingEdge2(1) > 32766*2.75)
            startOffset = startOffset + 1;
            pulseformAvg1 = circshift(pulseformAvg1,-32766);
            pulseformAvg2 = circshift(pulseformAvg2,-32766);
        end
    end
end
