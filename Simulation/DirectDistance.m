clear; clc;
%% Initialization
baseline = 1; c = 299792458;
XCVRBase = [[+1 +0 -1/sqrt(2)]; [-1 +0 -1/sqrt(2)]; ...
           [+0 +1 +1/sqrt(2)]; [+0 -1 +1/sqrt(2)]]' / 2 * baseline;

N = 10000;
distanceError = zeros(18,1);
G = zeros(18,7);
m = ones(7,1);
epsilon = 1e-5; diffOffset = zeros(7,1);
errors = zeros(N,4);
for kk = 1:N
    %% Generate Simulated Measurements
    targetPos = randn(3,1);
    targetPos = targetPos / norm(targetPos) * rand(1) * 100;
    targetRot = (rand(1,3).*[2 1 2]-[1 1/2 1]) * pi;

    R = SpinCalc('EA321toDCM',rad2deg(targetRot),1e-10,0);
    XCVRTarget = R * XCVRBase + repmat((targetPos),1,4);

    measurements = CalculateDistances(XCVRTarget, XCVRBase);
    measurements = measurements + mean(randn(1000,16)*0.01)';

    %% Perform LSQ
    for k=1:20
        estXCVRTarget = EstimateTargetPoints(m, 4, XCVRBase);
        estDistances  = CalculateDistances(estXCVRTarget, XCVRBase);
        distanceError = measurements - estDistances;
        distanceError(17) = 1 - sum(m(4:7).^2);   % norm(q) = 1
        distanceError(18) = 1 - sum(m(4:7).^2)^3; % determinant(R) = 1

        % Calculate Jacobian
        for i=1:7
            diffOffset = circshift([epsilon;0;0;0;0;0;0],i-1);
            pointsTemp =  EstimateTargetPoints(m + diffOffset, 4, XCVRBase);
            G(1:16,i)  = (CalculateDistances(pointsTemp, XCVRBase) - ...
                          estDistances) / epsilon;
        end
        G(17,4:7)    = 2 * m(4:7);                    % norm(q) = 1
        G(18,4:7)    = 6 * sum(m(4:7).^2)^2 * m(4:7); % determinant(R) = 1

        % Matrix Inversion
        dM  = (G'*G)^(-1)*G' * distanceError;
        m      = m + dM;
        m(4:7) = m(4:7) / norm(m(4:7)); % Enforce norm(q) = 1
    end
    estTargetPos = m(1:3);
    estTargetRot = GenerateRotationMatrix(m(4:7),'q');
   
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

%% Plot the Error Distribution
figure; 
subplot(1,3,1); plot(errors(:,1),errors(:,2),'.'); title('Parallel Pos');
xlabel('Distance [m]'); ylabel('Error [cm]'); ylim([0 0.03])
subplot(1,3,2); plot(errors(:,1),errors(:,3),'.'); title('Transverse Pos');
xlabel('Distance [m]'); ylabel('Error [cm]'); ylim([0 10])
subplot(1,3,3); plot(errors(:,1),errors(:,4),'.'); title('Angle');
xlabel('Distance [m]'); ylabel('Error [^\circ]'); ylim([0 10])
suptitle('Direct Distance Measurements (1000 Samples)')
