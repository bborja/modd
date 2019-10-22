function msk = mask_parts_of_usv(msk, paths, seq, eval_params)
    %% Read masks of USV parts
    % Read mask that filters out the areas of the USV visible in the image
    if(seq.id >= 1 && seq.id <= 9)
        boat_parts_mask = imread(fullfile(paths.USV_parts_masks, 'plovba_1_L.png'));
        black_areas = imread(fullfile(paths.dataset_path, 'masks_rectification_black_area', 'plovba01.png'));
    elseif(seq.id >= 10 && seq.id <= 14)
        boat_parts_mask = imread(fullfile(paths.USV_parts_masks, 'plovba_2_L.png'));
        black_areas = imread(fullfile(paths.dataset_path, 'masks_rectification_black_area', 'plovba02.png'));
    elseif(seq.id >= 15 && seq.id <= 18)
        boat_parts_mask = imread(fullfile(paths.USV_parts_masks, 'plovba_3_L.png'));
        black_areas = imread(fullfile(paths.dataset_path, 'masks_rectification_black_area', 'plovba03.png'));
    elseif(seq.id >= 19 && seq.id <= 26)
        boat_parts_mask = imread(fullfile(paths.USV_parts_masks, 'plovba_4_L.png'));
        black_areas = imread(fullfile(paths.dataset_path, 'masks_rectification_black_area', 'plovba04.png'));
    elseif(seq.id >= 27 && seq.id <= 28)
        boat_parts_mask = imread(fullfile(paths.USV_parts_masks, 'plovba_5_L.png'));
        black_areas = imread(fullfile(paths.dataset_path, 'masks_rectification_black_area', 'plovba05.png'));
    end
    
    black_areas = imresize(black_areas, [384, 512], 'method', 'nearest');
    se = strel('disk', 10);
    black_areas = imbinarize(imdilate(uint8(black_areas), se));
    
    % Override possible detections that are a couse of usv parts
    [msk_size_y, msk_size_x, ~] = size(msk);
    boat_parts_mask_resized = imresize(boat_parts_mask, [msk_size_y, msk_size_x], 'method', 'nearest');
    for rgb_counter = 1 : 3 % loop through color channels
        % extract current color channel
        tmp = msk(:, :, rgb_counter);
        % change with the corresponding value of the water component
        tmp(boat_parts_mask_resized == 1) = eval_params.labels(3, rgb_counter);
        % update the segmentation mask
        msk(:, :, rgb_counter) = tmp;
    end
    
    if(eval_params.rectified == 1 && seq.is_rectified == 0)
        msk = imresize(cv.remap(imresize(msk, eval_params.img_size, 'Method', 'nearest'), map_L1, map_L2), [msk_size_y, msk_size_x], 'Method', 'nearest');
    end

    if(eval_params.rectified == 1)
        % remove black areas
        for rgb_counter = 1 : 3
            tmp = msk(:, :, rgb_counter); % extract color
            tmp(black_areas == 1) = eval_params.labels(3, rgb_counter);
            msk(:, :, rgb_counter) = tmp;
        end
    end
    
end