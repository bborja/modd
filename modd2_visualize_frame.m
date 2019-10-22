function [vis_img, tp, fp, fn] = modd2_visualize_frame(dataset_path, segmentation_output_path, method_name, author_name, sequence_number, frame_number, rectified, for_video_bool, segmentation_colors, tp_in, fp_in, fn_in)
    if(nargin < 7)
        error('Not enough input parameters');
       
    elseif(nargin < 8)
        for_video_bool = 0;
        
        tp_in = 0;
        fp_in = 0;
        fn_in = 0;
        
        segmentation_colors = [0, 255, 0; ...
                               0,   0, 0; ...
                               255, 0, 0];
                           
    elseif(nargin < 9)
        segmentation_colors = [0, 255, 0; ...
                               0,   0, 0; ...
                               255, 0, 0];
                           
        tp_in = 0;
        fp_in = 0;
        fn_in = 0;
        
    end
    
    %% Get evaluation parameters
    eval_params = get_eval_params(segmentation_colors, rectified);
    
    % Add sequence ID
    seq.id = sequence_number;
    seq.mask_num = frame_number;

    % Get sequence details (name, start frame, end frame)
    [seq.name, seq.start_frame, seq.end_frame] = get_seq_details(sequence_number);
    
    %% Get paths
    paths = get_paths(dataset_path, segmentation_output_path, method_name, seq, eval_params);

    [vis_img, tp, fp, fn] = perform_visualization(paths, seq, eval_params, method_name, author_name, for_video_bool, tp_in, fp_in, fn_in);

end

function [vis_img, tp, fp, fn] = perform_visualization(paths, seq, eval_params, method_name, author_name, for_video_bool, tp_in, fp_in, fn_in)
    % false from boat detections - discard this....
    %fp_mask = imread('rectf_mask_fp.png');
    %fp_mask = imdilate(imbinarize(imresize(fp_mask, [384, 512], 'nearest')), strel('disk', 4, 4));

    % Load chosen raw image from left camera
    raw_img = imread(fullfile(paths.frames, sprintf('%08dL.jpg', seq.start_frame + seq.mask_num)));
    
    % Load segmentation output for the chosen frame
    cnn_seg_msk = imread(fullfile(paths.segmentation_output, sprintf('%08dL_pred.png', seq.start_frame + seq.mask_num)));
    % Mask parts of the USV, rectify the segmentation mask if needed and
    % mask the black/nan areas caused by the rectification...
    cnn_seg_msk = mask_parts_of_usv(cnn_seg_msk, paths, seq, eval_params);
    
    % Postprocess output segmentation images and output extracted sea
    % mask and detected objects...
    [det_objs, sea_mask] = postprocess_output_image(cnn_seg_msk, eval_params);
    
    % Prettyfy segmentation mask
    cnn_seg_msk = change_colors_img(cnn_seg_msk, eval_params);
    
    % Overlay segmentation mask over image
    segmented_image = image_overlay_segmentation_mask(raw_img, cnn_seg_msk, sea_mask);
    
    % QR code to modd2 project page (do not remove!)
    qr_code = imread('viz_images/qr-code_2_bw.png');
    qr_size_y = 180;
    qr_size_x = 180;
    qr_code = imresize(qr_code, [qr_size_y, qr_size_x]);
    qr_code = imbinarize(qr_code);
    
    % Load ground truth file
    gtl = load(fullfile(paths.ground_truth, sprintf('%08dL.mat', seq.start_frame + seq.mask_num)));
    gtl = gtl.annotations;
    
    %filter gt sea edge
    %sea_edge_line = gtl.sea_edge( logical((gtl.sea_edge(:,1) > 0) .* (gtl.sea_edge(:,1) <= eval_params.img_size(2))), : );
    % Ignore coordinates with inf or nan values...
    sea_edge_line = filter_sea_edge(gtl.sea_edge, eval_params.img_size);

     % create inverse sea mask
    tmp_inv_sea_mask = poly2mask([1; sea_edge_line(:,1); eval_params.img_size(2)], [1; sea_edge_line(:,2); 1], eval_params.img_size(1), eval_params.img_size(2));

    % Filter obstacles
    gtl = filter_obstacles(gtl, eval_params.img_size, tmp_inv_sea_mask);
    
    % scaled raw image
    scaled_image = imresize(raw_img, [320, 426]);
    % scaled segmentation mask
    scaled_seg_mask = imresize(cnn_seg_msk, [320, 426]);

    % Create image
    final_img = zeros(eval_params.img_size(1), eval_params.img_size(2), 3);
    offset_top = size(final_img, 1) - eval_params.img_size(1) + 1;
    final_img(offset_top : end, :, :) = segmented_image;
    if for_video_bool
        % Raw input image subframe...
        final_img(1:320, 1:426, :) = scaled_image; % scaled raw image top left
        final_img = insertText(final_img, [213 1], 'Input image', 'FontSize', 25, 'TextColor', [255, 255, 255], 'BoxOpacity', 0.15, 'AnchorPoint', 'CenterTop'); 
        
        % Postprocessed segmentation mask subframe...
        final_img(1:320, 427:852, :) = scaled_seg_mask; % scaled raw segmentation mask top middle
        final_img = insertText(final_img, [639 1], 'Segmentation mask', 'FontSize', 25, 'TextColor', [255, 255, 255], 'BoxOpacity', 0.15, 'AnchorPoint', 'CenterTop');   
        
        % QR code..
        for i = 1 : 3
            final_img(1:320, 853:end, i) = final_img(1:320, 853:end, i) * 0.7 + 0.3 * zeros(320, 426, 1);
            tmp_qr_background = final_img(320 - qr_size_y + 1 : 320, size(final_img, 2) - qr_size_x + 1 : end, i);
            tmp_qr_background(qr_code > 0) = qr_code(qr_code > 0) * 255;
            final_img(320 - qr_size_y + 1 : 320, size(final_img, 2) - qr_size_x + 1 : end, i) = tmp_qr_background;
        end
        final_img(321, :, :) = 0; 
        final_img = insertText(final_img, [size(final_img, 2) - qr_size_x + 1, 320 - qr_size_y + 10], 'MODD2 dataset:', 'FontSize', 19, 'TextColor', [255, 255, 255], 'BoxOpacity', 0, 'AnchorPoint', 'LeftBottom'); 
        
        % Authors and Method name
        final_img = insertText(final_img, [853,  1], sprintf('Method: %*.*s', 0, 30, method_name), 'FontSize', 22, 'TextColor', [255, 255, 255], 'BoxOpacity', 0, 'AnchorPoint', 'LeftTop');
        final_img = insertText(final_img, [853, 40], sprintf('Authors: %*.*s', 0, 29, author_name), 'FontSize', 22, 'TextColor', [255, 255, 255], 'BoxOpacity', 0, 'AnchorPoint', 'LeftTop');  
    end
    
    % Footer method name
    final_img = insertText(final_img, [1, 938], method_name, 'FontSize', 12, 'TextColor', [255, 255, 255], 'BoxOpacity', 0, 'AnchorPoint', 'LeftTop');  
    
    % Evaluate
    % Segmentation metrics
    paths.gt_water_masks = 'ground_truth_water_map';
    paths.dt_water_masks = fullfile('results', method_name, 'postprocessing');

    
    % Obstacle detection metrics
    [rmse_water, tp, fp, fn, tp_list, fp_list, fn_list] = evaluate_detections_modd2(sea_mask, det_objs, gtl, eval_params);
    
    if for_video_bool
        final_img = insertText(final_img, [853, 140], sprintf('W. Edge: %02.01fpx [%.01f%%]', (rmse_water * size(final_img, 2)), (rmse_water * 100)), 'FontSize', 22, 'TextColor', [255, 255, 255], 'BoxOpacity', 0, 'AnchorPoint', 'LeftTop');
        final_img = insertText(final_img, [853, 175], sprintf('Total TP: %d', tp + tp_in), 'FontSize', 22, 'TextColor', [255, 255, 255], 'BoxOpacity', 0, 'AnchorPoint', 'LeftTop');
        final_img = insertText(final_img, [853, 210], sprintf('Total FP: %d', fp + fp_in), 'FontSize', 22, 'TextColor', [255, 255, 255], 'BoxOpacity', 0, 'AnchorPoint', 'LeftTop');
        final_img = insertText(final_img, [853, 245], sprintf('Total FN: %d', fn + fn_in), 'FontSize', 22, 'TextColor', [255, 255, 255], 'BoxOpacity', 0, 'AnchorPoint', 'LeftTop');
        final_img = insertText(final_img, [853, 280], sprintf('Total F1: %.01f%%', ( (2*(tp+tp_in)) / (2*(tp+tp_in)+(fp+fp_in)+(fn+fn_in)) ) * 100), 'FontSize', 22, 'TextColor', [255, 255, 255], 'BoxOpacity', 0, 'AnchorPoint', 'LeftTop');
    end
    
    
    final_img = uint8(final_img);
    
    figure(1);
    clf; imagesc(final_img); axis equal; axis tight; hold on;
    %plot(sea_edge_line(:,1), offset_top + sea_edge_line(:,2), 'LineWidth', 3, 'color', [0,0,0]); hold on;
    %plot(sea_edge_line(:,1), offset_top + sea_edge_line(:,2), 'LineWidth', 2, 'color', [1,0,1]); hold on;
    draw_all_obstacles(gtl, tp_list, fp_list, fn_list, eval_params.area_threshold);
    

    
    set(gca,'xtick',[]);
    set(gca,'ytick',[]);
    set(gca,'xticklabel',[]);
    set(gca,'yticklabel',[]);
    %set(gca,'LooseInset',get(gca,'TightInset'));
    %set(gca, 'FontSmoothing', 'on')
    set(gcf,'Position',[0 0 1278 958])
    
    vis_img = getframe(gcf);%final_img;
end

function new_im = change_colors_img(old_im, eval_params)
    [size_y, size_x, size_c] = size(old_im);
    new_im = zeros(size_y, size_x, size_c);
    
    %sky 
    new_im(:,:,1) = new_im(:,:,1) + (old_im(:,:,1) == eval_params.labels(1,1) & old_im(:,:,2) == eval_params.labels(1,2) & old_im(:,:,3) == eval_params.labels(1,3)) * 69;
    new_im(:,:,2) = new_im(:,:,2) + (old_im(:,:,1) == eval_params.labels(1,1) & old_im(:,:,2) == eval_params.labels(1,2) & old_im(:,:,3) == eval_params.labels(1,3)) * 78;
    new_im(:,:,3) = new_im(:,:,3) + (old_im(:,:,1) == eval_params.labels(1,1) & old_im(:,:,2) == eval_params.labels(1,2) & old_im(:,:,3) == eval_params.labels(1,3)) * 161;
    
    %ground
    new_im(:,:,1) = new_im(:,:,1) + (old_im(:,:,1) == eval_params.labels(2,1) & old_im(:,:,2) == eval_params.labels(2,2) & old_im(:,:,3) == eval_params.labels(2,3)) * 246;
    new_im(:,:,2) = new_im(:,:,2) + (old_im(:,:,1) == eval_params.labels(2,1) & old_im(:,:,2) == eval_params.labels(2,2) & old_im(:,:,3) == eval_params.labels(2,3)) * 193;
    new_im(:,:,3) = new_im(:,:,3) + (old_im(:,:,1) == eval_params.labels(2,1) & old_im(:,:,2) == eval_params.labels(2,2) & old_im(:,:,3) == eval_params.labels(2,3)) * 59;

    %water
    new_im(:,:,1) = new_im(:,:,1) + (old_im(:,:,1) == eval_params.labels(3,1) & old_im(:,:,2) == eval_params.labels(3,2) & old_im(:,:,3) == eval_params.labels(3,3)) * 51;
    new_im(:,:,2) = new_im(:,:,2) + (old_im(:,:,1) == eval_params.labels(3,1) & old_im(:,:,2) == eval_params.labels(3,2) & old_im(:,:,3) == eval_params.labels(3,3)) * 168;
    new_im(:,:,3) = new_im(:,:,3) + (old_im(:,:,1) == eval_params.labels(3,1) & old_im(:,:,2) == eval_params.labels(3,2) & old_im(:,:,3) == eval_params.labels(3,3)) * 222;
    
    new_im = uint8(new_im);
end

function im_out = image_overlay_segmentation_mask(img, processed_segm, sea_mask)
    [size_y, size_x, ~] = size(img);
    processed_segm_r = processed_segm(:,:,1);
    processed_segm_g = processed_segm(:,:,2);
    processed_segm_b = processed_segm(:,:,3);
    
    sea_mask = logical(sea_mask);
    processed_segm_r(sea_mask) = 0;
    processed_segm_r = double(processed_segm_r) + sea_mask * 51;
    processed_segm_g(sea_mask) = 0;
    processed_segm_g = double(processed_segm_g) + sea_mask * 168;
    processed_segm_b(sea_mask) = 0;
    processed_segm_b = double(processed_segm_b) + sea_mask * 222;
    
    processed_segm(:,:,1) = processed_segm_r;
    processed_segm(:,:,2) = processed_segm_g;
    processed_segm(:,:,3) = processed_segm_b;
    
    processed_segm = double(imresize(uint8(processed_segm), [size_y, size_x], 'method', 'nearest'));
    
    img_bw = rgb2gray(img);
    
    im_out = zeros(size_y, size_x, 3);
    
    w = [0.4, 0.4, 0.4];
    for j = 1 : 3
        tmp_img_bw = double(img_bw);
        im_out(:,:,j) = tmp_img_bw * w(j) + (1 - w(j)) * processed_segm(:,:,j);    
    end
    
    im_out = uint8(im_out);
end

function draw_all_obstacles(gt_obs, tp_list, fp_list, fn_list, area_threshold)
    % Show large ground truth obstacles
    plot(gt_obs.sea_edge(:,1), gt_obs.sea_edge(:,2), ':m', 'LineWidth', 2); hold on;
    for i = 1 : size(gt_obs.largeobjects, 1)
       tmp_rectangle = gt_obs.largeobjects(i, :);
       tmp_rectangle(3) = tmp_rectangle(3) - tmp_rectangle(1);
       tmp_rectangle(4) = tmp_rectangle(4) - tmp_rectangle(2);
       
       rectangle('Position', tmp_rectangle, 'LineStyle', ':', 'LineWidth', 1, 'EdgeColor', 'k'); hold on;
    end
    
    % Show small ground truth obstacles
    for i = 1 : size(gt_obs.smallobjects, 1)
       tmp_rectangle = gt_obs.smallobjects(i, :);
       tmp_rectangle(3) = tmp_rectangle(3) - tmp_rectangle(1);
       tmp_rectangle(4) = tmp_rectangle(4) - tmp_rectangle(2);
       
       % Plot small obstacle if it is large enough to be a threat
       if(tmp_rectangle(4) * tmp_rectangle(3) <= area_threshold)
           rectangle('Position', tmp_rectangle, 'LineStyle', ':', 'LineWidth', 1, 'EdgeColor', [1, 1, 1]); hold on;
       end
    end
    
    % Show detected obstacles
    for i = 1 : size(tp_list, 2)
        rectangle('Position', [tp_list(1,i), tp_list(2,i), tp_list(3,i) - tp_list(1,i), tp_list(4,i) - tp_list(2,i)], 'LineWidth', 3, 'EdgeColor', 'k'); hold on;
        rectangle('Position', [tp_list(1,i), tp_list(2,i), tp_list(3,i) - tp_list(1,i), tp_list(4,i) - tp_list(2,i)], 'LineWidth', 2, 'EdgeColor', 'g', 'FaceColor', [0, 1, 0, 0.25]); hold on;
    end
    
    for i = 1 : size(fp_list, 2)
        rectangle('Position', [fp_list(1,i), fp_list(2,i), fp_list(3,i) - fp_list(1,i), fp_list(4,i) - fp_list(2,i)], 'LineWidth', 3, 'EdgeColor', 'k'); hold on;
        rectangle('Position', [fp_list(1,i), fp_list(2,i), fp_list(3,i) - fp_list(1,i), fp_list(4,i) - fp_list(2,i)], 'LineWidth', 2, 'EdgeColor', [1, 0.65, 0]); hold on;
    end
    
    for i = 1 : size(fn_list, 2)
        rectangle('Position', [fn_list(1,i), fn_list(2,i), fn_list(3,i) - fn_list(1,i), fn_list(4,i) - fn_list(2,i)], 'LineWidth', 3, 'EdgeColor', 'k'); hold on;
        rectangle('Position', [fn_list(1,i), fn_list(2,i), fn_list(3,i) - fn_list(1,i), fn_list(4,i) - fn_list(2,i)], 'LineWidth', 2, 'EdgeColor', 'r', 'FaceColor', [1, 0, 0, 0.25]); hold on;
    end
end