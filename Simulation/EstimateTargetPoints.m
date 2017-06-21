function estPoints = EstimateTargetPoints(m, n, offset)
    estRot = GenerateRotationMatrix([m(4) m(5) m(6) m(7)],'q');
    estPoints = repmat([m(1),m(2),m(3)]',1,n) + estRot * offset;
end