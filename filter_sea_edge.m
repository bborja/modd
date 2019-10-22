function sea_edge_line = filter_sea_edge(sea_edge_line, img_size)
    % Ignore coordinates with inf or nan values...
    sea_edge_line(sea_edge_line(:,1) == Inf | sea_edge_line(:,1) == -Inf | isnan(sea_edge_line(:,1)), :) = [];
    sea_edge_line(sea_edge_line(:,2) == Inf | sea_edge_line(:,2) == -Inf | isnan(sea_edge_line(:,2)), :) = [];
    % update 'out-of-screen' values
    for i = 1 : size(sea_edge_line, 1)
       if(sea_edge_line(i,1) < 1)
           sea_edge_line(i,1) = 1;
       end
       if(sea_edge_line(i,1) > img_size(2))
           sea_edge_line(i,1) = img_size(2);
       end

       if(sea_edge_line(i,2) > img_size(1))
           sea_edge_line(i,2) = img_size(1);
       end
    end
end