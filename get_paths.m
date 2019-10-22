function paths = get_paths(dataset_path, segmentation_output_path, method_name, seq, eval_params)
    %% Set paths accordingly...
    paths.dataset_path = fullfile(dataset_path);
    % Path to frames of the current sequence
    if(eval_params.rectified == 1)
        paths.frames = fullfile(dataset_path, 'video_data', seq.name, 'framesRectified');
    else
        paths.frames = fullfile(dataset_path, 'video_data', seq.name, 'frames');
    end
    % Path to ground-truth of the current sequence
    if(eval_params.rectified == 1)
        paths.ground_truth = fullfile(dataset_path, 'annotationsV2_rectified', seq.name, 'ground_truth');
    else
        paths.ground_truth = fullfile(dataset_path, 'annotationsV2', seq.name, 'ground_truth');
    end
    % Path to segmentation results of the current sequence
    paths.segmentation_output = fullfile(segmentation_output_path, sprintf('seq%02d', seq.id), method_name);
    % Path to USV masks
    paths.USV_parts_masks = fullfile(dataset_path, 'USV_parts_masks');

end