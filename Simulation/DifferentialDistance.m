clear; clc;
%% Initialization
baseline = 1; c = 299792458;
XCVRBase = [[+1 +0 -1/sqrt(2)]; [-1 +0 -1/sqrt(2)]; ...
           [+0 +1 +1/sqrt(2)]; [+0 -1 +1/sqrt(2)]]' / 2 * baseline;
     
N = 10000;
distanceError = zeros(26,1);
G = zeros(26,7);
epsilon = 1e-5; diffOffset = zeros(7,1);
errors = zeros(N,4);
%%
for kk = 1:N
    %% Generate Simulated Measurements
    targetPos = randn(3,1);
    targetPos = targetPos / norm(targetPos) * rand(1) * 100;
    targetRot = (rand(1,3).*[2 1 2]-[1 1/2 1]) * pi;

    R = SpinCalc('EA321toDCM',rad2deg(targetRot),1e-10,0);
    XCVRTarget = R * XCVRBase + repmat((targetPos),1,4);

    measurements = CalculateDifferentialDistances(XCVRTarget, XCVRBase);
    errorSeed = randn(16,1000)*0.01;
    error     = zeros(24,1000);
    for i = 1:4
        error((i-1)*6+1,:) = errorSeed((i-1)*4+1,:) - errorSeed((i-1)*4+2,:);
        error((i-1)*6+2,:) = errorSeed((i-1)*4+1,:) - errorSeed((i-1)*4+3,:);
        error((i-1)*6+3,:) = errorSeed((i-1)*4+1,:) - errorSeed((i-1)*4+4,:);
        error((i-1)*6+4,:) = errorSeed((i-1)*4+2,:) - errorSeed((i-1)*4+3,:);
        error((i-1)*6+5,:) = errorSeed((i-1)*4+2,:) - errorSeed((i-1)*4+4,:);
        error((i-1)*6+6,:) = errorSeed((i-1)*4+3,:) - errorSeed((i-1)*4+4,:);
    end
    measurements = measurements + mean(error')';
    
    m = ones(7,1);
    %% Perform LSQ
    for k=1:20
        estXCVRTarget = EstimateTargetPoints(m, 4, XCVRBase);
        estDistances  = CalculateDifferentialDistances(estXCVRTarget, XCVRBase);
        distanceError = measurements - estDistances;
        distanceError(25) = 1 - sum(m(4:7).^2);   % norm(q) = 1
        distanceError(26) = 1 - sum(m(4:7).^2)^3; % determinant(R) = 1

        % Calculate Jacobian
        for i=1:7
            diffOffset = circshift([epsilon;0;0;0;0;0;0],i-1);
            pointsTemp =  EstimateTargetPoints(m + diffOffset, 4, XCVRBase);
            G(1:24,i)  = (CalculateDifferentialDistances(pointsTemp, XCVRBase) - ...
                          estDistances) / epsilon;
        end
        G(25,4:7)    = 2 * m(4:7);                    % norm(q) = 1
        G(26,4:7)    = 6 * sum(m(4:7).^2)^2 * m(4:7); % determinant(R) = 1

        % Matrix Inversion
        alpha = 1e-4;
        dM  = (G'*G + alpha^2)^(-1)*G' * distanceError;
        m      = m + dM * 0.5;
        m(4:7) = m(4:7) / norm(m(4:7)); % Enforce norm(q) = 1  
    end
    estTargetPos = m(1:3);
    estTargetRot = GenerateRotationMatrix(m(4:7),'q');
    
    if (length(find(isnan(estTargetRot))) < 1)
         %% Determine Errors    
        x = SpinCalc('DCMtoQ',R,1e-10,0);
        y = SpinCalc('DCMtoQ',estTargetRot,1e-10,0);
        z = quatmultiply(x,quatconj(y));

        err_pos = norm(targetPos - estTargetPos);
        err_rot = rms(wrapTo360(fliplr(SpinCalc('DCMtoEA321',estTargetRot,1e-10,0))) - ...
            wrapTo360(rad2deg(targetRot)) );

        errors(kk,:) = [norm(targetPos), ...
                       abs(dot(estTargetPos-targetPos,targetPos)/norm(targetPos))*100, ...
                       norm(cross(estTargetPos-targetPos,targetPos)/norm(targetPos))*100, ...
                       abs(wrapTo180(rad2deg(2*acos(z(1)))))]';
    end
end

%% Plot the Error Distribution
figure; 
subplot(1,3,1); plot(errors(:,1),errors(:,2),'.'); title('Parallel Pos');
xlabel('Distance [m]'); ylabel('Error [cm]'); ylim([0 2000])
subplot(1,3,2); plot(errors(:,1),errors(:,3),'.'); title('Transverse Pos');
xlabel('Distance [m]'); ylabel('Error [cm]'); ylim([0 10])
subplot(1,3,3); plot(errors(:,1),errors(:,4),'.'); title('Angle');
xlabel('Distance [m]'); ylabel('Error [^\circ]'); ylim([0 10])
suptitle('Differential Distance Measurements (1000 Samples)')
