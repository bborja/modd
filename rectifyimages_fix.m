function [S, map_L1, map_L2, map_R1, map_R2] = rectifyimages_fix(S, fs, sim)      
    % Fix narrow field of view after rectification
    croi = S.roi2;
    aroi = zeros(1,4);
    
    if(croi(3) > croi(4)*4/3)
        aroi(1) = croi(1) + (croi(3) - croi(4)*4/3)/2;
        aroi(2) = croi(2);
        aroi(3) = croi(4)*4/3;
        aroi(4) = croi(4);
    else
        aroi(1) = croi(1);
        aroi(2) = croi(2) + (croi(4) - croi(3)*3/4)/2;
        aroi(3) = croi(3);
        aroi(4) = croi(3)*3/4;
    end
    
    tmp_u = fs.imageSize{1} / aroi(3);
    tmp_v = fs.imageSize{2} / aroi(4);
    tmp_M = [tmp_u, 0, -aroi(1) * tmp_u; ...
             0, tmp_v, -aroi(2) * tmp_v; ...
             0, 0, 1];
     
    % fixed projection matrices
    S.P1 = tmp_M * S.P1;
    S.P2 = tmp_M * S.P2;
    
    [ map_L1, map_L2 ] = cv.initUndistortRectifyMap(fs.M1, fs.D1, S.P1, sim, 'R', S.R1);
    [ map_L1, map_L2 ] = cv.convertMaps(map_L1, map_L2, 'DstMap1Type', 'int16');

    [ map_R1, map_R2 ] = cv.initUndistortRectifyMap(fs.M2, fs.D2, S.P2, sim, 'R', S.R2);
    [ map_R1, map_R2 ] = cv.convertMaps(map_R1, map_R2, 'DstMap1Type', 'int16');

end