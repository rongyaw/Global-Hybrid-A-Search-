%%  Implementation of hybrid a star for demo purpose
%{
-Author: Rongyao Wang 
-Institution: Clemson University
-Reference: Dmitiri Dolgov, Sebastian Thrun, Micheal Montemerlo and James
Diebel. Path Planning for Autonomous Vehicles in Unknown Semi-structured
Environments

This work is the demonstration of hybrid A* search based on standford AI &
Robotic Group's work in DARPA Grand Challenges
%}
clear all
clc
close all
dbstop if error
warning('off');
set(gca,'visible','off')
%%  Create the obstacles and start/goal location
obstacle = [1,2,2,10;
            4,5,0,4;
            -4,-3,-10,-2;
            7,8,2,8;
            -1,0,-5,1;
            -4,-3,0,8;
            -2,-1,0,1;
            3,6,4,5;
            1,3,-1,0;
            1,2,-7,-3;
            4,5,7,10];% Format -> [min_x, max_x, min_y, max_y]
obstacles = [];
% Plot the obstacles in map
for j = 0:15:45
    for i = 1:1:length(obstacle(:,1))
        min_x = obstacle(i,1) + j;
        max_x = obstacle(i,2) + j;
        min_y = obstacle(i,3);
        max_y = obstacle(i,4);
        obstacles = [obstacles; [min_x, max_x, min_y, max_y]];
        obs_x = [min_x, max_x, max_x, min_x, min_x];
        obs_y = [min_y, min_y, max_y, max_y, min_y];
        fill(obs_x, obs_y,'k'); hold on
        clear min_x;
        clear max_x;
        clear min_y;
        clear max_y;
    end
end
% Setup the start and goal location for nvaigation and plot them
start_x = -5;
start_y = -8;
start_yaw = 0;%random('Uniform',0,3.14);
goal_x = 30;
goal_y = 4;
plot(start_x, start_y, 'or', 'MarkerSize', 20, 'MarkerFaceColor', 'r');hold on
plot(goal_x, goal_y, 'or', 'MarkerSize', 20, 'MarkerFaceColor', 'r');hold on
xlim([start_x-2, goal_x+4])
set(gca,'xtick',[])
set(gca,'ytick',[])

%%  Create the steering angle and arc length for sampling
steering = linspace(-0.41,0.41,6);
arc_length = 0.75;
arc_record = [];
counter_max = 3;
goal_reach = false;
direction = 1;
distance = 0;
nodes = 0;
tic
while goal_reach == false
    global id
    id = 1;
    mother_id = 0;
    w_gn = 0.1;
    open = []; % Store the information of vertex
    open_f = []; % Store the corresponding key values: f(n)
    open_g = []; % Store the corresponding key values: g(n)
    open_c = []; % Combine the previous two as cost value
    close = []; % Create closed list for finding optimal path
    open = [start_x, start_y, start_yaw, 0, mother_id, id, 0];
    vertex_sum = [start_x, start_y];
    open_f = [open_f, pdist([open(1:2);[goal_x, goal_y]])]; % eucliden heuristic function
    open_c = open_f + open(end);
    counter = 0;
    goal_reach = false;

    % Start the timer
    while length(open_c) ~= 0 && counter < counter_max
        % Pop the minimum cost value
        [min_cost,source_ind] = min(open_c); % Pop up the smallest key value from open list
        source = open(source_ind,:); % Pop up the smallest key value from open list
        close = [close; [source, min_cost]];
        if pdist([source(1:2);[goal_x, goal_y]]) < 0.5
            break
        end
        open(source_ind,:) = []; % Delete the pop-up key from open list
        open_f(source_ind) = []; % Same as above
        open_c(source_ind) = []; % Same as above
        sample = ackermann_sampler(direction, source, steering, arc_length, @collision_check, obstacles, vertex_sum, id); % Search from the pop-up point    
        if ~isempty(sample)
            f = sample(:,1:2) - [goal_x, goal_y];
            f = (f(:,1).^2 + f(:,2).^2).^0.5;
            open = [open; sample];
            open_f = [open_f, f.'];
            open_c = open_f + w_gn * open(:,4).';
            counter = counter + 1;
            if counter_max > 20
                counter_max = counter_max - 2;
            end
            arc_length = max(0.75, arc_length * 0.95);
            arc_record = [arc_record, arc_length];
            drawnow
            % In this case, the weight of distance travelled is set to be lower than distance to the goal
        else
            if isempty(open_c)
                direction = direction*(-1);
                counter_max = min(30, counter_max + 2);
                arc_length = min(arc_length*2.5, 5);
                arc_record = [arc_record, arc_length];
                disp(['Counter max now is ', num2str(counter_max), ' with sample length of ',num2str(arc_length), ' m.']);
            end
        end
    end
    %%  Search through the closed list to find the path.
    % Start from the last point and draw the path between them
    [~,min_id] =  max(close(:, 4));
    search_id = close(min_id, 5);
    plot(close(min_id,1), close(min_id,2),'rs','MarkerSize',6,'MarkerFaceColor','r');
    hold on
    path_point = [close(min_id,1), close(min_id,2), close(min_id,3)]; % Store the path from closed list
    distance = distance + close(min_id, 7);
    while search_id ~= 0
        point_id = find(close(:,6)== search_id);
        path_point = [path_point;[close(point_id,1), close(point_id,2), close(point_id,3)]];
        distance = distance + close(point_id, 7);
        %plot(close(point_id,1), close(point_id,2),'rs','MarkerSize',6,'MarkerFaceColor','r');
        draw_car(close(point_id,1), close(point_id,2), close(point_id,3));
        hold on
        search_id = close(point_id,5);
    end
    
    nodes = nodes + (length(path_point(:,1)) - 1);
    
    % Reset the start point to start a new search
    start_x = path_point(1,1);
    start_y = path_point(1,2);
    start_yaw = path_point(1,3);
    
    % Use different plotting line to show the car's orientation
    if direction == 1
        plot(path_point(:,1), path_point(:,2), 'b-','Linewidth',3);hold on
    else
        plot(path_point(:,1), path_point(:,2), 'r-','Linewidth',3);hold on
    end
    
    % Check if the final destination is reached
    if pdist([path_point(1,1:2);[goal_x, goal_y]]) < 0.5 
        goal_reach = true;
        disp(['Goal Reach']);
        t = toc;
    end
end
disp(['The total distance travelled is ', num2str(distance),' m.']);
disp(['The average sampling distance is ', num2str(distance/nodes), ' m.']);
disp(['The total task time is ',num2str(distance/2.5 + t),' seconds.'])