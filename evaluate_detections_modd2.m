function [rmse_water, tp, fp, fn, tp_list, fp_list, fn_list] = evaluate_detections_modd2(water_mask, det_obs, gt, eval_params)
            sim = eval_params.img_size;
                   
            %% Initialization of results...
            tp = 0;
            fp = 0;
            fn = 0;
            
            fp_list = [];
            fn_list = [];

            minoverlap_removal = eval_params.minoverlap;
            area_threshold = eval_params.area_threshold;
            
            % set freezonepix based on image height
            freezonepix = round(eval_params.freezone*sim(1));
                        
            
            %% Get detected objects
            objs = [];
            if ~isempty(det_obs),
                for n1= 1 : length(det_obs)
                    rect1 = det_obs(n1).bounding_box;
                    rect2 = [rect1(1), rect1(2), rect1(1)+rect1(3), rect1(2)+rect1(4)];
                    objs = [objs, rect2(:)];
                end;
            end;
            
            %% rescale segmentation mask
            %segmentation of left camera image
            SegmentationMask = imresize(water_mask, [sim(1), sim(2)] ,'bilinear') >= 0.5;            
                                

            %get large objects (objects that are not all in the water)
            lobj = gt.largeobjects';

            %get small objects (objects that are completly surrounded in water)
            sobj = gt.smallobjects';
            
            %glitter masks (empty, because we dont have them anotated)
            mobj = [];
            

            %% Create ground truth segmentation mask. We start with horizon...
            gtSegmentationMask = build_gt_segmentation_mask (sim, gt.sea_edge);                       
            
            
            %% Build freezone map - this is gt map + freezone parameter.
            %This is done before we take into the account large objects, which 
            %dent the gt horizon

            gttrans = diff(gtSegmentationMask);
            gthorpoints = find_in_columns(gttrans);
            freezonemask = zeros(size(gtSegmentationMask));
            for n1=1:size(freezonemask,2),
                lowpoint = gthorpoints(n1)+freezonepix;
                freezonemask(1:lowpoint,n1)=1;
            end;

            %% ... And take into the account large objects
            % (by definition, those straddle the horizon!
            % Round and clip object boundaries, only way we use them is on the
            % image, so we need valid pixel coordinates;
            try
            [gtSegmentationMask, ~, ~] = gtObjectsSegm(sim, gtSegmentationMask, lobj, 1, 0);
            catch err
                errMsgTxt = getReport(err);
                fprintf('%s\n', errMsgTxt);
            end

            %% Render and select small objects - ground truth      
            try
                [gtSegmentationMask, removed_gt_objects, filtered_gt_objects] = gtObjectsSegm(sim, gtSegmentationMask, sobj, 0, area_threshold, freezonemask);
            catch err
                errMsgTxt = getReport(err);
                fprintf('%s\n', errMsgTxt);
            end 



            %% Render and select objects - detected
            try
                [SegmentationMask, filtered_det_objects] = detObjectsSegm(sim, SegmentationMask, objs, area_threshold, removed_gt_objects, freezonemask, minoverlap_removal);
            catch err
                errMsgTxt = getReport(err);
                fprintf('%s\n', errMsgTxt);
            end


            %% METRICES CALCULATION
            % Evaluate horizont RMS error
            % Find the vertical point of transition between 0 and 1 for both masks
            trans = diff(SegmentationMask);

            horpoints = find_in_columns(trans);

            gttrans = diff(gtSegmentationMask);

            gthorpoints = find_in_columns(gttrans);

            % Scale points to [0,1] to remove the effect of resolution
            vscale = 1 / sim(1);
            horpoints = horpoints * vscale;
            gthorpoints = gthorpoints * vscale;

            % Calculate horizont error
            num_el = length(horpoints);
            rmse_water = sqrt(sum((horpoints-gthorpoints).^2)/num_el);

            % Evaluate object detections. We have two sets of bounding boxes,
            % that is filtered_det_objects and filtered_gt_objects.

            % Init 'assigned' flags to properly account for multiple detections
            numgt = size(filtered_gt_objects,2);
            numdet = size(filtered_det_objects,2);
            assigned_gt = zeros(numgt,1);
            assigned_det = zeros(numdet,1);

            % Do the statistics only if there are any ground truth objects OR any
            % detected objects

            %left camera
            try
                [assigned_gt, assigned_det, tp, fp, tp_list] = genDetectionMetrices(assigned_gt, assigned_det, filtered_det_objects, filtered_gt_objects, minoverlap_removal, SegmentationMask, lobj, gtSegmentationMask);
            catch err
                errMsgTxt = getReport(err);
                fprintf('%s\n', errMsgTxt);
            end
            
            % Count all ground truth objects which don't have corresponding
            % detections - those are fn!
            fn = sum(assigned_gt==0);
            
            for fn_loop = 1 : length(assigned_gt)
                if(assigned_gt(fn_loop) < 1)
                    fn_list = [fn_list, filtered_gt_objects(:, fn_loop)];
                end
            end

            % Add all detections, that don't have corresponding ground truth
            % to false positives
            fp = fp + sum(assigned_det==0);
            
            for fp_loop = 1 : length(assigned_det)
                if(assigned_det(fp_loop) < 1)
                    fp_list = [fp_list, filtered_det_objects(:, fp_loop)];
                end
            end
            
            gt_mask = gtSegmentationMask;
            det_mask = SegmentationMask;
end

% Find first nonzero element from the top in each column. Matlab's find
% operates on matrices, but in a way I am not entirely comfortable with
function rpoints = find_in_columns(A)
    s = size(A);
    rpoints = zeros(s(2),1);
    for n1=1:s(2),
        col = A(:,n1);
        row = find (col,1,'first');
        if isnan(row),
            error ('Horizont evaluation - column nonzero element missing!');
        end;
        % If we don't find any, assume that the edge of the sea is at the top
        % of the image (effectively algorithm was unable to segment sea from
        % the sky.
        if ~isempty(row),
            rpoints(n1) = row;
        else
            rpoints(n1) = 1;
        end;
    end;
end

%% Generate detection metrices
% get assigned detection and assigned ground truth obstacles, 
% a number of true positives and a number false positives
function [assigned_gt, assigned_det, tp, fp, tp_list] = genDetectionMetrices(assigned_gt, assigned_det, filtered_det_objects, filtered_gt_objects, minoverlap, SegmentationMask, lobj, gtSegmentationMask)
    % get the number of filtered small object detections
    numdet = size(filtered_det_objects, 2);
    % get the number of filtered gt objects
    numgt = size(filtered_gt_objects, 2);
    % get the number of all large objects
    numgt_large = size(lobj, 2);
    
    % initialize detections
    tp = 0;
    fp = 0;
    
    tp_list = []; 
    
    %% If there are GT obstacles or detections for the current frame
    if (numgt>0)||(numdet>0)
        % Acros all detections
        for d=1:numdet,
            bb = filtered_det_objects(:,d);
            % Acros all ground truth objects
            for j=1:numgt,
                bbgt = filtered_gt_objects(:,j);
                bi=[max(bb(1),bbgt(1)) ; max(bb(2),bbgt(2)) ; min(bb(3),bbgt(3)) ; min(bb(4),bbgt(4))];
                iw=bi(3)-bi(1)+1;
                ih=bi(4)-bi(2)+1;
                if (iw>0) && (ih>0),
                    % compute overlap as area of intersection / area of union
                    ua=(bb(3)-bb(1)+1)*(bb(4)-bb(2)+1)+(bbgt(3)-bbgt(1)+1)*(bbgt(4)-bbgt(2)+1)-iw*ih;
                    ov=iw*ih/ua;
                    if ov>=minoverlap,
                        % Detection!
                        if assigned_gt(j)>0,
                            % Second or third (multiple) detection
                            % count as fp!
                            %fp = fp + 1; % MODIFICATION 27.2.2019 - Dont
                            %count this as FP. It is okay because it is so
                            %close to the actual obstacle and you should
                            %avoid it anyway
                            assigned_det(d) = 1;
                        else
                            % First detection, true positive
                            tp = tp + 1;
                            assigned_gt(j) = 1;
                            assigned_det(d) = 1;
                            %tp_list(:, tp) = filtered_det_objects(:, d);
                            tp_list = [tp_list, filtered_det_objects(:, d)];
                        end;
                    end
                end;
            end;
        end;

        %check for indirect detection (when obstacle is above detected
        %water edge)       
        % Fill all holes in detection Segmentation mask under the sea edge
        SegmentationMaskIndirect = SegmentationMask;
        bw_c = padarray(SegmentationMaskIndirect,[1 1],1,'post');
        bw_c_filled = imfill(bw_c,'holes');
        bw_c_filled = bw_c_filled(1:end-1,1:end-1);
        %Fill against the bottom and left border
        bw_d = padarray(padarray(SegmentationMaskIndirect, [1 0], 1, 'post'), [0 1], 1, 'pre');
        bw_d_filled = imfill(bw_d,'holes');
        bw_d_filled = bw_d_filled(1:end-1,2:end);
        %Combine fills
        SegmentationMaskIndirect = bw_c_filled | bw_d_filled;
    
        for id_obj = 1 : numgt
            if(assigned_gt(id_obj) == 0)
                bbgt = filtered_gt_objects(:,id_obj);
                %get content of ground truth obstacle's bounding box
                obj_box = SegmentationMaskIndirect(bbgt(2):bbgt(4), bbgt(1):bbgt(3));
                %get the area of gt obj's boundind box
                obj_box_size = size(obj_box, 1) * size(obj_box, 2);
                %number of pixeles covered by water
                obj_water_coverage = sum(sum(obj_box>0)); %length(find(obj_box>0));
                if(obj_water_coverage < (1 - minoverlap) * obj_box_size)
                    tp = tp + 1; %indirect detection!
                    assigned_gt(id_obj) = 1; %assign gt index to avoid multiple detections
                    %tp_list(:, tp) = filtered_gt_objects(:, id_obj);
                    tp_list = [tp_list, filtered_gt_objects(:, id_obj)];
                end
            end
        end                
    end;
    
    if ( (numdet > 0) || (numgt_large > 0))
        %check if there is a detection overlapping large obstacle
        %if such case exists, then ignore it - only assign detected obs
        %it should be tp, but since we remove from gt such large obstacles
        %we just ignore such detections
        
        % Compute intersection between removed ground truth and
        % detection. If area of intersection is bigger than 70% of
        % detection, than ignore such detection...
        for id_det = 1 : numdet
            if(assigned_det(id_det) == 0)
                bb = filtered_det_objects(:,id_det);
                
                bb_size = (bb(3) - bb(1) + 1) * (bb(4) - bb(2) + 1);
                
                for gt_large = 1 : numgt_large; 
                    bb_large_obj = lobj(:,gt_large);
                    bi = [max(bb(1), bb_large_obj(1)) ; max(bb(2), bb_large_obj(2)) ; min(bb(3), bb_large_obj(3)) ; min(bb(4), bb_large_obj(4))];
                    iw = bi(3) - bi(1) + 1;
                    ih = bi(4) - bi(2) + 1;
                    if ( iw > 0 && ih > 0 )
                        %ua = (bb(3) - bb(1) + 1) * (bb(4) - bb(2) + 1) + (bb_large_obj(3) - bb_large_obj(1) + 1) * (bb_large_obj(4) - bb_large_obj(2) + 1) - (iw * ih);
                        %ov = (iw * ih) / ua;
                        %if (ov >= minoverlap) %v1
                        %if ( ov >= 0.15 ) %v2
                        
                        % x If area of intersection is bigger than 70% of
                        % area of detection, than ignore such detection...
                        % ------------------------------------------------
                        % !Fix: only 15% overlap is enough....
                        %if( (iw * ih) >= ((1 - minoverlap) * bb_size) ) %v3
                        if( (iw * ih) >= minoverlap * bb_size ) %v4
                            assigned_det(id_det) = 1;
                            tp_list = [tp_list, filtered_det_objects(:, id_det)];
                            % obstacles has been detected, however, don't 
                            % affect the count of tp, fp or fn. Just ignore it
                        end
                    end
                end
            end
        end
    end
   
            
    %check if detected obstacle is above the annotated ground truth water
    %edge. If such detection exists, then ignore it...
    for id_det = 1 : numdet
       if( assigned_det(id_det) == 0)
           bb_det = round(filtered_det_objects(:,id_det));
           num_all_pixels = (bb_det(4)-bb_det(2)+1) * (bb_det(3)-bb_det(1)+1);
           try
               det_box = gtSegmentationMask(bb_det(2):bb_det(4), bb_det(1):bb_det(3));
               num_water_pixels = sum(det_box(:));
               %num_nonwater_elements = length(find(det_box == 0));
               if( num_water_pixels < (1 - minoverlap) * num_all_pixels )
                   % If at least 85% of detected obstacle is loacted above the
                   % annotated ground truth water edge, then assign such
                   % detection but ignore it regarding tp/fp score
                   assigned_det(id_det) = 1;
                   %tp_list = [tp_list, filtered_det_objects(:, id_det)];
               end
           catch err
               fprintf('Detection indices problem when checking detection above sea level\n');
           end
       end        
    end
end

%generate segmentation mask of detected objects and filter them
function [SegmentationMask, filtered_det_objects] = detObjectsSegm(sim, SegmentationMask, objs, area_threshold, removed_gt_objects, freezonemask, minoverlap_removal, varargin)
        filtered_det_objects = [];
        num_argin = numel(varargin);
        check_size_meters = 0;
        if(num_argin > 0)
           check_size_meters = 1; 
           disparity_map = varargin{1};
           size_threshold = varargin{2};
           S = varargin{3};
        end
        
        if ~isempty(objs)
            objsr = round(objs);
            
            % Clip values outside image
            mask = objsr(1,:)<1; objsr(1,mask) = 1;
            mask = objsr(1,:)>sim(2); objsr(1,mask) = sim(2);
            mask = objsr(2,:)<1; objsr(2,mask) = 1;
            mask = objsr(2,:)>sim(1); objsr(2,mask) = sim(1);
            mask = objsr(3,:)<1; objsr(3,mask) = 1;
            mask = objsr(3,:)>sim(2); objsr(3,mask) = sim(2);
            mask = objsr(4,:)<1; objsr(4,mask) = 1;
            mask = objsr(4,:)>sim(1); objsr(4,mask) = sim(1);
            
            for n1=1:size(objsr,2),
                isinfreezone = 0;
                istoosmall = 0;
                isoverlappingwithremovedgt = 0;
                % Check object size
                xobjsize = abs(objs(3,n1)-objs(1,n1));
                yobjsize = abs(objs(4,n1)-objs(2,n1));
                objsize = xobjsize*yobjsize;
                if objsize<area_threshold,
                    istoosmall = 1;
                end;

                % Check if corners are outside of the free zone
                if freezonemask(objsr(2,n1),objsr(1,n1))==1,
                    isinfreezone = 1;
                end;
                if freezonemask(objsr(4,n1),objsr(3,n1))==1,
                    isinfreezone = 1;
                end;
                if freezonemask(objsr(4,n1),objsr(1,n1))==1,
                    isinfreezone = 1;
                end;
                if freezonemask(objsr(2,n1),objsr(3,n1))==1,
                    isinfreezone = 1;
                end;

                % Check whether the object overlaps with removed ground truth
                bb = objs (:,n1);
                for ngr=1:size(removed_gt_objects,2),
                    bbgt = removed_gt_objects(:,ngr);
                    bi=[max(bb(1),bbgt(1)) ; max(bb(2),bbgt(2)) ; min(bb(3),bbgt(3)) ; min(bb(4),bbgt(4))];
                    iw=bi(3)-bi(1)+1;
                    ih=bi(4)-bi(2)+1;
                    if (iw>0) && (ih>0),
                        % compute overlap as area of intersection / area of union
                        ua=(bb(3)-bb(1)+1)*(bb(4)-bb(2)+1)+...
                            (bbgt(3)-bbgt(1)+1)*(bbgt(4)-bbgt(2)+1)-...
                            iw*ih;
                        ov=iw*ih/ua;
                        if ov>minoverlap_removal,
                            isoverlappingwithremovedgt = 1;
                        end;
                    end;
                end;

                if (istoosmall == 0 && check_size_meters)
                   istoosmall = checkSizeMeters(objsr(:,n1), disparity_map, S, size_threshold); 
                end
                % Check if corners
                if (isinfreezone==1)||(istoosmall==1)||(isoverlappingwithremovedgt==1),
                    %SegmentationMask = mark_empty_rectangle (SegmentationMask, objsr(:,n1));
                else
                    SegmentationMask = mark_full_rectangle (SegmentationMask, objsr(:,n1));
                    filtered_det_objects = [filtered_det_objects, objs(:,n1)];
                end;
            end;
        end;
end

%generate segmentation mask of ground truth objects (small and large)
%filter ground truth objects and remove too-small objects and large objects
function [newSegmentationMask, removed_gt_objects, filtered_gt_objects] = gtObjectsSegm(sim, segmMask, Obj, largeObjectsBool, area_threshold, freezonemask, varargin)
    removed_gt_objects = [];
    filtered_gt_objects = [];
    check_size_meters = 0;
    num_argin = numel(varargin);
    if(num_argin > 0)
        check_size_meters = 1;
        disparity_map = varargin{1};
        size_threshold = varargin{2};
        S = varargin{3};
    end
    
    if ~isempty(Obj),
        rObj = round(Obj);
        % Clip values outside image
        mask = rObj(1,:)<1; rObj(1,mask) = 1;
        mask = rObj(1,:)>sim(2); rObj(1,mask) = sim(2);
        mask = rObj(2,:)<1; rObj(2,mask) = 1;
        mask = rObj(2,:)>sim(1); rObj(2,mask) = sim(1);
        mask = rObj(3,:)<1; rObj(3,mask) = 1;
        mask = rObj(3,:)>sim(2); rObj(3,mask) = sim(2);
        mask = rObj(4,:)<1; rObj(4,mask) = 1;
        mask = rObj(4,:)>sim(1); rObj(4,mask) = sim(1);
        for n1=1:size(Obj,2),
            if( largeObjectsBool )
                s1 = size(segmMask);
                segmMask (rObj(2,n1):rObj(4,n1),rObj(1,n1):rObj(3,n1)) = 0;
                s2 = size(segmMask);
                if ~isequal(s1,s2),
                    error ('someone has been writing outside boundaries!');
                end;
            else
                isinfreezone = 0;
                istoosmall = 0;
                
                % Check object size
                xobjsize = abs(rObj(3,n1)-rObj(1,n1));
                yobjsize = abs(rObj(4,n1)-rObj(2,n1));
                objsize = xobjsize*yobjsize;
                if objsize<area_threshold,
                    istoosmall = 1;
                end;
                % Check if corners are outside of the free zone
                if freezonemask(rObj(2,n1),rObj(1,n1))==1,
                    isinfreezone = 1;
                end;
                if freezonemask(rObj(4,n1),rObj(3,n1))==1,
                    isinfreezone = 1;
                end;
                if freezonemask(rObj(4,n1),rObj(1,n1))==1,
                    isinfreezone = 1;
                end;
                if freezonemask(rObj(2,n1),rObj(3,n1))==1,
                    isinfreezone = 1;
                end;
                
                if(istoosmall == 0 && check_size_meters)
                    istoosmall = checkSizeMeters(rObj(:,n1), disparity_map, S, size_threshold);
                end

                if (isinfreezone==1) || (istoosmall==1),
                    %segmMask = mark_empty_rectangle (segmMask, rObj(:,n1));
                    removed_gt_objects = [removed_gt_objects, Obj(:,n1)];
                else
                    segmMask = mark_full_rectangle (segmMask, rObj(:,n1));
                    filtered_gt_objects = [filtered_gt_objects, Obj(:,n1)];
                end;
            end
        end;
    end;
    newSegmentationMask = segmMask;
end


function mask = mark_full_rectangle (mask, rect)
    mask (rect(2):rect(4),rect(1):rect(3)) = 0;
end

function smask = build_gt_segmentation_mask (s, hor)
    %s = size (im);

    % Add bottom right and bottom left image corners to the horizont to obtain
    % a polygon, which will be filled by poly2mask. Poly2mask closes the
    % polygon if not already closed. Note that leftmost and rightmost point in
    % the horizont are already included in hor, but to make sure that the
    % polygon covers the whole are we move them 0.5 pix to coordinates outside the
    % image.
    [badrows1,~] = find(hor<0);
    hor = hor(setdiff(1:size(hor,1),badrows1),:);
    [badrows2,~] = find(hor>s(2));
    hor = hor(setdiff(1:size(hor,1),badrows2),:);
    
    [badrows1,~] = find(isnan(hor));
    hor = hor(setdiff(1:size(hor,1),badrows1),:);
    
    hor (1,1) = 0.5;
    hor (end,1) = s(2)+0.5;
    
    % Points in hor are ordered from left to the right of the image
    hor = [hor; s(2)+0.5,s(1); 0.5, s(1)];

    smask = poly2mask (hor(:,1), hor (:,2), s(1), s(2));

    % If it generates image that is too large, we crop it (is it a bug in poly2mask?)
    smask = smask(1:s(1),1:s(2));
end