%% MODD2 EVALUATION SCRIPT 
%
% This function evaluates segmentation outputs of the given method on raw 
% sequences from the Multi-modal Marine Obstacle Detection Dataset 2 (MODD2)
% 
% Input parameters:
%   dataset_path - a path to the MODD2 dataset root folder
%   output_path - a path to the output root folder
%   method_name - name of the given method
%   segmentation_colors (optional) - a 3x3 matrix of colors used to
%                                    represent labels in the output mask.
%                                    In first row should be the RGB
%                                    representation of the sky component,
%                                    second row corresponds to the RGB
%                                    representation of the
%                                    obstacles/environment component, while
%                                    the last row corresponds to the RGB
%                                    representation of the water component.
%
function modd2_evaluate_all_sequences_raw(dataset_path, output_path, method_name, segmentation_colors)
    if(nargin < 3)
        error('Not enough input parameters');
    end
    
    %% Evaluation parameters
    % Rectified dataset?
    eval_params.rectified = 0; % false
    % Minimum overlap between two obstacles
    eval_params.minoverlap = 0.15; % (default: 0.02)
    % Freezone area below the water-edge where obstacles are removed
    eval_params.freezone = 0; % (default: 0.01)
    % Minimum surface area of obstacles to be considered as a threat
    eval_params.area_threshold = 5*5; % (default: 15x15)
    % Original image size (height x width)
    eval_params.img_size = [958, 1278];
    % RGB encoding of the labels
    if(nargin == 3)
        eval_params.labels = [  0, 255, 0; ... % Sky represented with green
                                0,   0, 0; ... % obstacles with black
                              255,   0, 0];    % and water with red color.
    else
        eval_params.labels = segmentation_colors;
    end
    
    %% Extreme conditions information
    % Sequence IDs where sudden movement occurres
    extreme.sequences_sudden_movement = [1, 11];
    % Sequence IDs where sun glitter occurres
    extreme.sequences_sun_glitter = [11, 12, 13, 14, 20, 21, 22, 23, 24, 25, 26, 28];
    % Sequence IDs where environmental reflections occurr
    extreme.sequences_env_reflections = [1, 2, 3, 4, 5, 6, 7, 8, 9, 14, 15, 16, 18, 23, 27, 28];
    
    %% Makedir for storing interim results and posprocessed segmentation masks
    if(~exist(fullfile('results', method_name, 'postprocessing'), 'dir'))
        mkdir(fullfile('results', method_name, 'postprocessing'));
    end
    if(~exist(fullfile('results', method_name, 'eval_results'), 'dir'))
        mkdir(fullfile('results', method_name, 'eval_results'), 'dir');
    end
    
    %% Initializations
    % Evaluation results cell. Each cell represents each own sequence
    eval_results = cell(28,2);
    % For storing special sequence tag
    seq.special = [];
    % Evaluation measures
    total_rmse = [];
    total_tp = 0;
    total_fp = 0;
    total_fn = 0;
    
    % are segmentation masks rectified?
    seq.is_rectified = 0;
    
    %% Loop through all sequences...
    for seq_num_id = 1 : 28
        seq.id = seq_num_id;
        %% Fill in sequence information/details
        % Add special sequences tag if necessary
        if(ismember(seq.id, extreme.sequences_sudden_movement))
            seq.special = [seq.special, 1];
        end
        if(ismember(seq.id, extreme.sequences_sun_glitter))
            seq.special = [seq.special, 2];
        end
        if(ismember(seq.id, extreme.sequences_env_reflections))
            seq.special = [seq.special, 3];
        end
        
        % Get sequence details (name, start frame, end frame)
        [seq.name, seq.start_frame, seq.end_frame] = get_seq_details(seq.id);
        
        %% Set paths accordingly...
        paths.dataset_path = fullfile(dataset_path);
        % Path to frames of the current sequence
        paths.frames = fullfile(dataset_path, 'video_data', seq.name, 'frames');
        % Path to ground-truth of the current sequence
        paths.ground_truth = fullfile(dataset_path, 'annotationsV2', seq.name, 'ground_truth');
        % Path to segmentation results of the current sequence
        paths.output = fullfile(output_path, sprintf('seq%02d', seq.id), method_name);
        % Path to USV masks
        paths.USV_parts_masks = fullfile(dataset_path, 'USV_parts_masks');
               
        %% Perform evaluation on sequence seq_num_id
        % Results for each frame are written in format:
        %   1    2  3  4  5
        %   RMSE TP FP FN Special sequence tag
        fprintf('Evaluation on sequence %02d started...\n', seq.id);
        [output_results, output_detections] = perform_evaluation_on_sequence(paths, seq, eval_params);
        
        %% Save interim results
        % Save detections information for the processed sequence...
        save(fullfile('results', method_name, 'postprocessing', sprintf('seq%02d_%s.mat', seq.id, method_name)), 'output_detections');
        % Save output results of the processed sequence...
        eval_results{seq.id, 1} = output_results;
        eval_results{seq.id, 2} = seq.special;
        
        save(fullfile('results', method_name, 'eval_results', sprintf('seq%02d_%s.mat', seq.id, method_name)), 'eval_results');
        
        %% Print interim results
        fprintf('Seq %02d done\n', seq.id);
        tmp_rmse = mean(cell2mat(output_results(:,1)));
        tmp_tp = sum(cell2mat(output_results(:,2)));
        tmp_fp = sum(cell2mat(output_results(:,3)));
        tmp_fn = sum(cell2mat(output_results(:,4)));
        fprintf('RMSE: %f\nTotal TP: %d\nTotal FP: %d\nTotal FN: %d\n', tmp_rmse, tmp_tp, tmp_fp, tmp_fn);
        
        %% Update total results
        total_rmse = [total_rmse; cell2mat(output_results(:,1))];
        total_tp = total_tp + tmp_tp;
        total_fp = total_fp + tmp_fp;
        total_fn = total_fn + tmp_fn;
        
    end
    
    fprintf('--- all done ---\n');
    fprintf('**********************************\n');
    fprintf('* Evaluation on    RAW    images *\n');
    fprintf('* Method: %*.*s *\n', 22, 22, method_name);
    fprintf('**********************************\n');
    fprintf('* Total RMSE:            %04.01f px *\n', mean(total_rmse(:)) * 958);
    fprintf('* Total STD:             %04.01f px *\n', std(total_rmse(:)) * 958);
    fprintf('* Total STE:             %04.01f px *\n', std(total_rmse(:)) / sqrt(length(total_rmse(:))) * 958);
    fprintf('* Total TP:                 %04d *\n', total_tp);
    fprintf('* Total FP:                %05d *\n', total_fp);
    fprintf('* Total FN:                 %04d *\n', total_fn);
    fprintf('* F-measure:              %04.01f %% *\n', ((2 * total_tp) / (2 * total_tp + total_fp + total_fn) * 100));
    fprintf('**********************************\n');
end