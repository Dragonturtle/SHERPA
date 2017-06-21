function distances = CalculateDistances(target, base)
    distances = zeros(24,1);
    
    for i = 1:4    
        center = (base(:,1)+base(:,2))/2; dir = center - target(:,i);
        distances((i-1)*6+1) = dot(base(:,1) - base(:,2), dir) / norm(dir);        
        center = (base(:,1)+base(:,3))/2; dir = center - target(:,i);
        distances((i-1)*6+2) = dot(base(:,1) - base(:,3), dir) / norm(dir);        
        center = (base(:,1)+base(:,4))/2; dir = center - target(:,i);
        distances((i-1)*6+3) = dot(base(:,1) - base(:,4), dir) / norm(dir);
        center = (base(:,2)+base(:,3))/2; dir = center - target(:,i);
        distances((i-1)*6+4) = dot(base(:,2) - base(:,3), dir) / norm(dir);      
        center = (base(:,2)+base(:,4))/2; dir = center - target(:,i);
        distances((i-1)*6+5) = dot(base(:,2) - base(:,4), dir) / norm(dir);  
        center = (base(:,3)+base(:,4))/2; dir = center - target(:,i);
        distances((i-1)*6+6) = dot(base(:,3) - base(:,4), dir) / norm(dir);
    end
end