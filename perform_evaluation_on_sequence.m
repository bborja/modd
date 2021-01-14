%% Perform evaluation
% Function performs evaluation of the given method on the selected sequence
function [output_results_cell, output_detections] = perform_evaluation_on_sequence(paths, seq, eval_params)
    if(nargin < 3)
        error('Not enough input parameters');
    end
    
    %% Initialize output results
    % (num_frames x 4) matrix of RMSE_water, TP, FP, FN
    output_results_cell = cell(1, 4);
    counter = 1;
    
    % In first cell we store extracted water-mask, while in the second cell
    % we store detections list
    output_detections = cell(1, 2);
    
    %% Read masks of USV parts
    % Read mask that filters out the areas of the USV visible in the image
    if(seq.id >= 1 && seq.id <= 9)
        boat_parts_mask_l = imread(fullfile(paths.USV_parts_masks, 'kope67_L.png'));
        boat_parts_mask_r = imread(fullfile(paths.USV_parts_masks, 'kope67_R.png'));
        
    elseif(seq.id >= 10 && seq.id <= 14)
        boat_parts_mask_l = imread(fullfile(paths.USV_parts_masks, 'kope71_L.png'));
        boat_parts_mask_r = imread(fullfile(paths.USV_parts_masks, 'kope71_R.png'));

    elseif(seq.id >= 15 && seq.id <= 18)
        boat_parts_mask_l = imread(fullfile(paths.USV_parts_masks, 'kope75_L.png'));
        boat_parts_mask_r = imread(fullfile(paths.USV_parts_masks, 'kope75_R.png'));

    elseif(seq.id >= 19 && seq.id <= 26)
        boat_parts_mask_l = imread(fullfile(paths.USV_parts_masks, 'kope81_L.png'));
        boat_parts_mask_r = imread(fullfile(paths.USV_parts_masks, 'kope81_R.png'));
        
    elseif(seq.id >= 27 && seq.id <= 28)
        boat_parts_mask_l = imread(fullfile(paths.USV_parts_masks, 'kope82_L.png'));
        boat_parts_mask_r = imread(fullfile(paths.USV_parts_masks, 'kope82_R.png'));

    end
    
    %% Loop through the images....
    % Get the number of total frames in the sequence
    total_frames = seq.end_frame - seq.start_frame;
    
    %% Get calibration details...
    % Get calibration file
	fs = cv.FileStorage(fullfile(paths.dataset_path, 'video_data', seq.name, 'calibration.yaml'));
	% Get resolution of raw image
	sim = [fs.imageSize{1}, fs.imageSize{2}];
	% Get parameters for rectification
	S = cv.stereoRectify(fs.M1, fs.D1, fs.M2, fs.D2, sim, fs.R, fs.T, 'ZeroDisparity', true, 'Alpha', 1);
	% Fix rectification bug...
	[S, map_L1, map_L2, ~, ~] = rectifyimages_fix(S, fs, sim); % Fix narrow view bug after rectification

    f = waitbar(0, 'Initializing sequence...');
    for frm_num = seq.start_frame + 1 : seq.end_frame
        % update progress bar
        if(mod(counter, 10) == 0)
           waitbar(counter/total_frames, f, sprintf('Processing sequence %02d...', seq.id));
        end
        
        % load segmentation mask
        msk = imread(fullfile(paths.output, sprintf('%08dL_pred.png', frm_num)));
        %msk = imread(fullfile(paths.output, sprintf('%08dL.png', frm_num)));

        
        % Override possible detections that are a couse of usv parts
        [msk_size_y, msk_size_x, ~] = size(msk);
        
        boat_parts_mask_resized_l = imresize(boat_parts_mask_l, [msk_size_y, msk_size_x], 'method', 'nearest');
        boat_parts_mask_resized_r = imresize(boat_parts_mask_r, [msk_size_y, msk_size_x], 'method', 'nearest');
        
        for rgb_counter = 1 : 3 % loop through color channels
            % extract current color channel
            tmp = msk(:, :, rgb_counter);
            % change with the corresponding value of the water component
            tmp(boat_parts_mask_resized_l == 1) = eval_params.labels(3, rgb_counter);
            % update the segmentation mask
            msk(:, :, rgb_counter) = tmp;
        end
        
        % Load ground truth file
        gtl = load(fullfile(paths.ground_truth, sprintf('%08dL.mat', frm_num)));
        gtl = gtl.annotations;
        
        % Filter sea-edge
        gtl.sea_edge = filter_sea_edge(gtl.sea_edge, eval_params.img_size);
        sea_edge_line = gtl.sea_edge;
        
        % create inverse sea mask
        tmp_inv_sea_mask = poly2mask([1; sea_edge_line(:,1); eval_params.img_size(2)], [1; sea_edge_line(:,2); 1], eval_params.img_size(1), eval_params.img_size(2));
        
        % Separate obstacles to large and small ones + filter them
        gtl = filter_obstacles(gtl, eval_params.img_size, tmp_inv_sea_mask);
        
        %% Rectify image if it is needed
        % remap segmentation mask to rectified images if we are evaluation
        % on the rectified dataset and if the segmentation masks were
        % obtained on raw images
        if(eval_params.rectified == 1 && seq.is_rectified == 0)
            msk = imresize(cv.remap(imresize(msk, eval_params.img_size, 'Method', 'nearest'), map_L1, map_L2), [msk_size_y, msk_size_x], 'Method', 'nearest');
        end
        
        %{
        if(eval_params.rectified == 1)
            % remove black areas
            for rgb_counter = 1 : 3
                tmp = msk(:, :, rgb_counter); % extract color
                tmp(black_areas == 1) = eval_params.labels(3, rgb_counter);
                msk(:, :, rgb_counter) = tmp;
            end
        end
        %}

        
        %% Postprocess output segmentation images
        % Get extracted sea-mask and a list of all detections
        [det_objs, sea_mask] = postprocess_output_image(msk, eval_params);
        output_detections{counter, 1} = logical(sea_mask);
        output_detections{counter, 2} = det_objs;
        
        %% Perform evaluation of detections...
        [rmse_water, tp, fp, fn, ~, ~, ~] = evaluate_detections_modd2(sea_mask, det_objs, gtl, eval_params);
        output_results_cell{counter, 1} = rmse_water;
        output_results_cell{counter, 2} = tp;
        output_results_cell{counter, 3} = fp;
        output_results_cell{counter, 4} = fn;
        counter = counter + 1;
        
    end
    close(f);
    
end