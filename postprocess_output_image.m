%% Postprocess segmentation mask
% Function postprocesses the segmentation mask and extracts the water
% component along with all obstacle detections enclosed in the water
% component
%
% Input parameters:
%   cnn_mask - segmentation mask outputed by the CNN
%   eval_param - structure of evaluation parameters
function [objs_out, masked_sea] = postprocess_output_image(cnn_mask, eval_params)
    %% Build binary mask of water component...
    % Get the size of the segmentation mask
    [size_y, size_x, ~] = size(cnn_mask);
    % Initialize water mask
    water_mask = zeros(size_y, size_x);
    % Extract the water component from the segmentation mask
    water_mask(cnn_mask(:, :, 1) == eval_params.labels(3, 1) & ...
               cnn_mask(:, :, 2) == eval_params.labels(3, 2) & ...
               cnn_mask(:, :, 3) == eval_params.labels(3, 3)) = 1;
      
    % Extract the sky component from the segmentation mask
    masked_sky = cnn_mask(:, :, 1) == eval_params.labels(1, 1) & ...
                 cnn_mask(:, :, 2) == eval_params.labels(1, 2) & ...
                 cnn_mask(:, :, 3) == eval_params.labels(1, 3);
             
    %tmp_se = strel('disk', 5);
    %masked_sky = imdilate(masked_sky, tmp_se);
    
    % Create a copy of the water mask and fill all the holes inside of it
    masked_sea = water_mask;
    
    masked_sea_a = padarray(masked_sea,[1 1],1,'pre');
    masked_sea_a = imfill(masked_sea_a,'holes');
    masked_sea_a = masked_sea_a(2:end,2:end);
    
    masked_sea_b = padarray(padarray(masked_sea,[1 0],1,'pre'),[0 1],1,'post');
    masked_sea_b = imfill(masked_sea_b,'holes');
    masked_sea_b = masked_sea_b(2:end,1:end-1);
    
    masked_sea_c = padarray(masked_sea,[1 1],1,'post');
    masked_sea_c = imfill(masked_sea_c,'holes');
    masked_sea_c = masked_sea_c(1:end-1,1:end-1);
    
    masked_sea_d = padarray(padarray(masked_sea,[1 0],1,'post'),[0 1],1,'pre');
    masked_sea_d = imfill(masked_sea_d,'holes');
    masked_sea_d = masked_sea_d(1:end-1,2:end);
    
    masked_sea_filled = masked_sea_a | masked_sea_b | masked_sea_c | masked_sea_d;

    % Parts of sky detected inside the water component should be ignored,
    % as those pixels do not belong to the obstacles component and
    % therefore do not present a danger to the usv
    masked_sea = masked_sea_filled .* masked_sky + masked_sea;
    
    water_mask = masked_sea';
    
    size_edge = eval_params.img_size ;
    size_obj = size(water_mask(:,:,1)) ;
    size_obj = size_obj([2,1]) ;
    scl = size_edge./size_obj ;
    Tt = diag(scl([2,1])) ;

    %% Sea edge and its uncertainty score
    % Extract the largest connected component from the water mask
    T = bwmorph(water_mask, 'diag') ;
    T = extractTheLargestRegion(T) ;
    T = ~bwmorph(~T,'clean') ;
    masked_sea = T' ;
    
    dT = [ zeros(size(T,1),1), diff(T')' ] ~=0 ;
    dT2 = [ zeros(1,size(T,2)); diff(T) ] ~=0 ;
    dT = dT | dT2 ;

    % try
    if (sum(T(:)) ~= numel(T)) && (sum(dT(:)) ~= 0),
        [ largest_curve, ~ ] = extractTheLargestCurve(dT') ;
        data = bsxfun(@minus, Tt*largest_curve', diag(Tt/2)) ;
    else
        objs_out = Object(0);
        return;
    end


    % Edge of sea
    xy_subset = data ;
   
    I = ~T' ;
    
    %% *** Detected objects ***
    CC = replacement_bwconncomp(I, 8);

    % These are in fact "sub-boxes" which we merge into acutal object
    % detections
    objs = ObjectPart(numel(CC));
    
    counter = 0;
    for k = 1:numel(CC),
        pixels = CC(k).pixel_idx;

        obj = ObjectPart(1);

        %% Bounding box
        [ y, x ] = ind2sub(size_obj, pixels);
        xmin = min(x(:));
        ymin = min(y(:));
        xmax = max(x(:));
        ymax = max(y(:));

        if(xmin == 1)
            xmin_orig = xmin;
        else
            xmin_orig = xmin - 1;
        end
        
        if(ymin == 1)
            ymin_orig = ymin;
        else
            ymin_orig = ymin - 1;
        end
        
        width_orig = xmax-xmin_orig;
        height_orig = ymax-ymin_orig;

        % Rescale bounding box
        xmin = xmin_orig*Tt(1);
        ymin = ymin_orig*Tt(4);
        width = width_orig*Tt(1);
        height = height_orig*Tt(4);

        obj.bounding_box = [xmin, ymin, width, height];

        % AreaT
        obj.area = width*height;

        % Boundary
        [ymin,loc]=min(y(:));
        xmin = x(loc)*Tt(1);
        ymin = Tt(4)*ymin;

        [~,loc] = min(abs(xy_subset(1,:)-xmin)) ;
        boundary = xy_subset(:,loc) ;

        if boundary(2) > ymin
            continue;
        end

        % Add to the list
        objs(counter+1) = obj;
        counter = counter + 1;
    end

    objs(counter+1:end) = []; 

    objs_out = suppressDetections(objs);
end