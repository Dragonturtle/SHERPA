function distances = CalculateCombinedDistances(target, base)
    distances = zeros(40,1);
    
    for i = 1:4
        for j = 1:4     
            distances((i-1)*10+j) = norm(target(:,i) - base(:,j));
        end

        center = (base(:,1)+base(:,2))/2; dir = center - target(:,i);
        distances((i-1)*10+5) = dot(base(:,1) - base(:,2), dir) / norm(dir);        
        center = (base(:,1)+base(:,3))/2; dir = center - target(:,i);
        distances((i-1)*10+6) = dot(base(:,1) - base(:,3), dir) / norm(dir);        
        center = (base(:,1)+base(:,4))/2; dir = center - target(:,i);
        distances((i-1)*10+7) = dot(base(:,1) - base(:,4), dir) / norm(dir);
        center = (base(:,2)+base(:,3))/2; dir = center - target(:,i);
        distances((i-1)*10+8) = dot(base(:,2) - base(:,3), dir) / norm(dir);      
        center = (base(:,2)+base(:,4))/2; dir = center - target(:,i);
        distances((i-1)*10+9) = dot(base(:,2) - base(:,4), dir) / norm(dir);  
        center = (base(:,3)+base(:,4))/2; dir = center - target(:,i);
        distances((i-1)*10+10)= dot(base(:,3) - base(:,4), dir) / norm(dir);
    end
end