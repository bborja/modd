function eval_params = get_eval_params(segmentation_colors, rectified)
    % Rectified dataset?
    if(nargin == 2)
        eval_params.rectified = rectified;
    else
        eval_params.rectified = 0; % false
    end
    % Minimum overlap of two obstacles
    eval_params.minoverlap = 0.15; %0.2;
    % Freezone around sea-edge where obstacles are removed
    eval_params.freezone = 0; %0.01;
    % Minimum area of obstacles to be considered as a threat
    eval_params.area_threshold = 5*5; %15*15;
    % Are we working with rectified images?
    eval_params.rectified_bool = 0; %1;
    % Do we perform stereo verification of obstacles?
    eval_params.stereo_verification = 0;
    % Original image size
    eval_params.img_size = [958, 1278];
    % Labels of components
    eval_params.labels = segmentation_colors;

end