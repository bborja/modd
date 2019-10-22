function objs_out = suppressDetections(objs)
%#codegen

objs_out = Object(0);

switch numel(objs),
    case 0,
        return,
    case 1,
        selected = struct('idx', 1);
        objs_out = pruneobjs( objs(1).bounding_box, objs, selected) ;
        return ;
    otherwise
        bbs = zeros(numel(objs),4);
        for i = 1:numel(objs),
            assert(isequal(size(objs(i).bounding_box),[1 4]))
            bbs(i,:) = objs(i).bounding_box ;
        end
        [bbs_out, selected] = mergeByProximity( bbs) ;

        objs_out = pruneobjs( bbs_out, objs, selected ) ;
        %objs_out = objs;
        
end
end


%--------------------------------------------------------------------------

function [bbs_out, selected_out] = mergeByProximity(bbs)
%#codegen

s = bbs(:,3).*bbs(:,4) ;

numbbs=size(bbs,1);

[~, ordr] = sort(s, 'descend') ;
bbs = bbs( ordr, : ) ;
Mu = bbs(:, 1:2)+ (bbs(:, 3:4) / 2);

box_sizes = sum(bbs(:,3:4),2)/2 ;

Covs = (bbs(:,3:4)*1+5).^2 ;

selected_out = repmat(struct('idx', []), numbbs, 1);
coder.cstructname(selected_out, 'SelectedIndices');
coder.varsize('selected_out(:).idx');

bbs_out = zeros(numbbs,4);
mindist = 1; %1.5; %1 ;
counter=1;

while true
    
    ratios = zeros(1, size(bbs,1)) ;
    C1 = Covs(1,:) ;
    for i = 1 : length(ratios)
        C2 = Covs(i,:) ;
        C = C1+C2 ;
        ratios(i) = sqrt(sum(((Mu(1,:)-Mu(i,:)).^2)./C)) ;
    end
    
    id_remove = (ratios <= mindist) ;
    
    bbs_out(counter,:) = suppress_detections( bbs, Mu, id_remove)   ;
    
    selected_out(counter).idx =  ordr(id_remove)  ;
    
    bbs(id_remove, :) = [] ;
    Mu(id_remove, :) = [];
    ordr(id_remove) = [];
    Covs (id_remove, :) = [];
    box_sizes(id_remove) = []  ;
    
    if isempty(Mu)
        break ;
    end
    
    counter=counter+1;
end

selected_out=selected_out(1:counter);
bbs_out=bbs_out(1:counter,:);
end


%--------------------------------------------------------------------------

function objs_out = pruneobjs( bbs, parts, selected )
%#codegen

objs_out = Object(numel(selected));

for i = 1 : length(selected)
    objs_out(i).bounding_box =  bbs(i,:) ;
    objs_out(i).area = prod(bbs(i,[3,4])) ;
    objs_out(i).parts = parts(selected(i).idx(:)) ;
end
end


%--------------------------------------------------------------------------

function bbs_out = suppress_detections( bbs, Mu, selected)
%#codegen


bbs = bbs(selected,:) ;
Mu = Mu(selected,:) ;

minx = Mu(:,1)-bbs(:,3)/2 ; maxx = Mu(:,1)+bbs(:,3)/2 ;
miny = Mu(:,2)-bbs(:,4)/2 ; maxy = Mu(:,2)+bbs(:,4)/2 ;
minx = min(minx) ; miny = min(miny) ;
maxx = max(maxx) ; maxy = max(maxy) ;

xy = [ minx, miny ] ;
wh = [ maxx - minx , maxy - miny ] ;

bbs_out = [ xy , wh ] ;

end
