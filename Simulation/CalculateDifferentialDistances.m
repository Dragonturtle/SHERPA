function distances = CalculateDistances(target, base)
    distances = zeros(24,1);
    
    for i = 1:4
        distances((i-1)*6+1) = norm(target(:,i) - base(:,1)) - norm(target(:,i) - base(:,2));
        distances((i-1)*6+2) = norm(target(:,i) - base(:,1)) - norm(target(:,i) - base(:,3));
        distances((i-1)*6+3) = norm(target(:,i) - base(:,1)) - norm(target(:,i) - base(:,4));
        distances((i-1)*6+4) = norm(target(:,i) - base(:,2)) - norm(target(:,i) - base(:,3));
        distances((i-1)*6+5) = norm(target(:,i) - base(:,2)) - norm(target(:,i) - base(:,4));
        distances((i-1)*6+6) = norm(target(:,i) - base(:,3)) - norm(target(:,i) - base(:,4));
    end
end