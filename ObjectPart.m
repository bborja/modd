function parts = ObjectPart(num)
%#codegen

part = struct(...
    'bounding_box', [ 0 0 0 0 ], ...
    'area', 0, ...
    'features', [ 0 0 0 0 0 0 ]', ...
    'uncertainty_score', [ 0 0 ]);

parts = repmat(part, num, 1);

coder.cstructname(parts, 'ObjectPart');

end
