function distances = CalculateDistances(target, base)
    distances = zeros(16,1);
    
    for i = 1:4
        for j = 1:4     
            distances((i-1)*4+j) = norm(target(:,i) - base(:,j));
        end
    end
end