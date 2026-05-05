function [nodes_roi, edges_roi] = filter_valais_grid(nodesFile, edgesFile, nodesOutputFile, edgesOutputFile)

    % Lire les fichiers CSV
    nodes = readtable(nodesFile);
    edges = readtable(edgesFile);

    % Rectangle de la zone à garder
    % À modifier selon ta zone
    lonMin = 7.8;
    lonMax = 8.1;

    latMin = 46.2;
    latMax = 46.40;

    % ============================
    % 1. Filtrer les nodes
    % ============================

    nodes_lon = zeros(height(nodes), 1);
    nodes_lat = zeros(height(nodes), 1);

    for i = 1:height(nodes)
        [lon, lat] = extract_point_coordinates(nodes.geometry(i));
        nodes_lon(i) = lon;
        nodes_lat(i) = lat;
    end

    inside_nodes = nodes_lon >= lonMin & ...
                   nodes_lon <= lonMax & ...
                   nodes_lat >= latMin & ...
                   nodes_lat <= latMax;

    nodes_roi = nodes(inside_nodes, :);

    % ============================
    % 2. Filtrer les edges
    % ============================

    inside_edges = false(height(edges), 1);

    for i = 1:height(edges)

        [lon_list, lat_list] = extract_linestring_coordinates(edges.geometry(i));

        point_inside = lon_list >= lonMin & ...
                       lon_list <= lonMax & ...
                       lat_list >= latMin & ...
                       lat_list <= latMax;

        % On garde l'edge si au moins un point de la ligne est dans la zone
        inside_edges(i) = any(point_inside);

    end

    edges_roi = edges(inside_edges, :);

    % ============================
    % 3. Sauvegarder les résultats
    % ============================

    writetable(nodes_roi, nodesOutputFile);
    writetable(edges_roi, edgesOutputFile);

    fprintf("Nombre total de nodes : %d\n", height(nodes));
    fprintf("Nombre de nodes gardés : %d\n", height(nodes_roi));
    fprintf("Nombre total de edges : %d\n", height(edges));
    fprintf("Nombre de edges gardés : %d\n", height(edges_roi));

    return
end


function [lon, lat] = extract_point_coordinates(geometryText)

    geometryText = string(geometryText);

    numbers = regexp(geometryText, '[-+]?\d*\.?\d+(?:[eE][-+]?\d+)?', 'match');
    numbers = str2double(numbers);

    lon = numbers(1);
    lat = numbers(2);

    return
end


function [lon_list, lat_list] = extract_linestring_coordinates(geometryText)

    geometryText = string(geometryText);

    numbers = regexp(geometryText, '[-+]?\d*\.?\d+(?:[eE][-+]?\d+)?', 'match');
    numbers = str2double(numbers);

    lon_list = numbers(1:2:end);
    lat_list = numbers(2:2:end);

    return
end