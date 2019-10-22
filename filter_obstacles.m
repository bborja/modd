function gtl = filter_obstacles(gtl, img_size, inv_water_mask)
    gtl.largeobjects = [];
    gtl.smallobjects = [];
    
    for i = 1 : size(gtl.obstacles, 1)
        tmp_rectangle = gtl.obstacles(i, :);
        tmp_rectangle = round(tmp_rectangle);

        % Make sure that the obstacle is fully inside the image frame
        tmp_rectangle(1) = min([tmp_rectangle(1), img_size(2)]);
        tmp_rectangle(1) = max([tmp_rectangle(1), 1]);

        tmp_rectangle(2) = min([tmp_rectangle(2), img_size(1)]);
        tmp_rectangle(2) = max([tmp_rectangle(2), 1]);

        tmp_rectangle(3) = min([tmp_rectangle(3), img_size(2) - tmp_rectangle(1)]);
        tmp_rectangle(4) = min([tmp_rectangle(4), img_size(1) - tmp_rectangle(2)]);

        % get blank mask for obstacle i
        tmp_msk_obs_i = zeros(img_size(1), img_size(2));
        
        % draw obstacle i in the mask
        tmp_msk_obs_i(tmp_rectangle(2):tmp_rectangle(2)+tmp_rectangle(4), tmp_rectangle(1):tmp_rectangle(1)+tmp_rectangle(3)) = 1;
        
        % element-wise multiplication of mask for the i-th obstacle and
        % inverse of the water mask. 
        tmp_overlap = tmp_msk_obs_i .* inv_water_mask;
        % This will tell us, if the i-th obstacle is above the water 
        % surface with at least one of its edge-points...
        if(sum(tmp_overlap(:)) > 0)
           % update list of large obstacles if it is in fact above the
           % water edge
           gtl.largeobjects = [gtl.largeobjects; tmp_rectangle(1), tmp_rectangle(2), tmp_rectangle(1)+tmp_rectangle(3), tmp_rectangle(2)+tmp_rectangle(4)];
           
        else
           % else update the list of small obstacles
           gtl.smallobjects = [gtl.smallobjects; tmp_rectangle(1), tmp_rectangle(2), tmp_rectangle(1)+tmp_rectangle(3), tmp_rectangle(2)+tmp_rectangle(4)];
           
        end

        % Update location of obstacles with respect to filtering in the
        % begining of the code
        gtl.obstacles(i, :) = [tmp_rectangle(1), ...
                               tmp_rectangle(2), ...
                               tmp_rectangle(1) + tmp_rectangle(3), ...
                               tmp_rectangle(2) + tmp_rectangle(4)];
    end

end