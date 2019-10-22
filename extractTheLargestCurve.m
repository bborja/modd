function [ points, pixel_idx ] = extractTheLargestCurve (T)
%#codegen

pixel_idx = [];
points = [];

% Find connected components
CC = replacement_bwconncomp(T, 8);

% Find the largest component
%[ ~, max_idx ] = max([ CC.area ]);
max_idx = -1; max_val = -inf;
for i = 1:numel(CC),
    if CC(i).area > max_val,
        max_val = CC(i).area;
        max_idx = i;
    end
end

if max_idx == -1,
    return
end

% Pixel indices of the largest curve (largest component's perimeter)
pixel_idx = CC(max_idx).pixel_idx;

% Actual points
[ y, x ] = ind2sub(size(T), pixel_idx);
points = [ x-1, y ];
end
