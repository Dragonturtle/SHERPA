function distances = CalculateCombinedDistances(target, base)
    distances = zeros(40,1);
    
    for i = 1:4
        for j = 1:4     
            distances((i-1)*10+j) = norm(target(:,i) - base(:,j));
        end
        
        distances((i-1)*10+5)  = norm(target(:,i) - base(:,1)) - norm(target(:,i) - base(:,2));
        distances((i-1)*10+6)  = norm(target(:,i) - base(:,1)) - norm(target(:,i) - base(:,3));
        distances((i-1)*10+7)  = norm(target(:,i) - base(:,1)) - norm(target(:,i) - base(:,4));
        distances((i-1)*10+8)  = norm(target(:,i) - base(:,2)) - norm(target(:,i) - base(:,3));
        distances((i-1)*10+9)  = norm(target(:,i) - base(:,2)) - norm(target(:,i) - base(:,4));
        distances((i-1)*10+10) = norm(target(:,i) - base(:,3)) - norm(target(:,i) - base(:,4));
    end
end