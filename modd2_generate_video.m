function modd2_generate_video(dataset_path, segmentation_output_path, method_name, author_name, sequence_number, is_rectified, segmentation_colors)
    if(nargin < 7)
        segmentation_colors = [  0, 255, 0; ...
                                 0,   0, 0; ...
                               255,   0, 0];
    end
    
    % initialization
    tp_total = 0;
    fp_total = 0;
    fn_total = 0;
    
    % create output_videos map if it does not exists yet...
    if(~exist(fullfile('output_videos'), 'dir'))
        mkdir(fullfile('output_videos'));
    end
    
    if(is_rectified == 1)
        type = 'rectified';
    else
        type = 'raw';
    end
    
    % create video writer...
    v = VideoWriter(fullfile('output_videos', sprintf('%s_seq%02d_%s_.mp4', type, sequence_number, method_name)), 'MPEG-4');
    v.Quality = 95;
    v.FrameRate = 15;
    
    open(v);
    
    % Get sequence details (name, start frame, end frame)
    [~, start_frame, end_frame] = get_seq_details(sequence_number);
    total_frames = end_frame - start_frame;
    
    for frame_number = 1 : total_frames
        [vis_img, tp, fp, fn] = modd2_visualize_frame(dataset_path, ...
                                                      segmentation_output_path, ...
                                                      method_name, author_name, ...
                                                      sequence_number, ...
                                                      frame_number, ...
                                                      is_rectified, 1, ...
                                                      segmentation_colors, ...
                                                      tp_total, ...
                                                      fp_total, ...
                                                      fn_total);
                                                  
        tp_total = tp_total + tp;
        fp_total = fp_total + fp;
        fn_total = fn_total + fn;
        
        
        writeVideo(v, vis_img.cdata);
    end
    
    close(v);
end