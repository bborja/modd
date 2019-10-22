function objects = Object(num)
%#codegen

object = struct(...
    'bounding_box',[0 0 0 0],...
    'area', 0, ...
    'parts', ObjectPart(0));

objects = repmat(object, num, 1);

coder.cstructname(objects, 'Object');
coder.varsize('objects', 'objects(:).parts');

end