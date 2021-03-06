% MTSPVOFS_GA Fixed Start Open Variable Multiple Traveling Salesmen Problem (M-TSP) Genetic Algorithm (GA)
%   Finds a (near) optimal solution to a variation of the "open" M-TSP (that has a
%   variable number of salesmen) by setting up a GA to search for the
%   shortest route (least distance needed for each salesman to travel from
%   the start location to unique individual cities without returning to the
%   starting location)
%
% Summary:
%     1. Each salesman starts at the first point, but travels to a unique
%        set of cities after that (and none of them close their loops by
%        returning to their starting points)
%     2. Except for the first, each city is visited by exactly one salesman
%
% Note: The Fixed Start is taken to be the first XY point
%
% Input:
%     USERCONFIG (structure) with zero or more of the following fields:
%     - XY (float) is an Nx2 matrix of city locations, where N is the number of cities
%     - DMAT (float) is an NxN matrix of city-to-city distances or costs
%     - MINTOUR (scalar integer) is the minimum tour length for any of the
%         salesmen, NOT including the start point
%     - POPSIZE (scalar integer) is the size of the population (should be divisible by 8)
%     - NUMITER (scalar integer) is the number of desired iterations for the algorithm to run
%     - SHOWPROG (scalar logical) shows the GA progress if true
%     - SHOWRESULT (scalar logical) shows the GA results if true
%     - SHOWWAITBAR (scalar logical) shows a waitbar if true
%
% Input Notes:
%     1. Rather than passing in a structure containing these fields, any/all of
%        these inputs can be passed in as parameter/value pairs in any order instead.
%     2. Field/parameter names are case insensitive but must match exactly otherwise.
%
% Output:
%     RESULTSTRUCT (structure) with the following fields:
%         (in addition to a record of the algorithm configuration)
%     - OPTROUTE (integer array) is the best route found by the algorithm
%     - OPTBREAK (integer array) is the list of route break points (these specify the indices
%         into the route used to obtain the individual salesman routes)
%     - MINDIST (scalar float) is the total distance traveled by the salesmen
%
% Route/Breakpoint Details:
%     If there are 10 cities and 3 salesmen, a possible route/break
%     combination might be: rte = [5 6 9 4 2 8 10 3 7], brks = [3 7]
%     Taken together, these represent the solution [1 5 6 9][1 4 2 8 10][1 3 7],
%     which designates the routes for the 3 salesmen as follows:
%         . Salesman 1 travels from city 1 to 5 to 6 to 9
%         . Salesman 2 travels from city 1 to 4 to 2 to 8 to 10
%         . Salesman 3 travels from city 1 to 3 to 7
%
% Usage:
%     mtspvofs_ga
%       -or-
%     mtspvofs_ga(userConfig)
%       -or-
%     resultStruct = mtspvofs_ga;
%       -or-
%     resultStruct = mtspvofs_ga(userConfig);
%       -or-
%     [...] = mtspvofs_ga('Param1',Value1,'Param2',Value2, ...);
%
% Example:
%     % Let the function create an example problem to solve
%     mtspvofs_ga;
%
% Example:
%     % Request the output structure from the solver
%     resultStruct = mtspvofs_ga;
%
% Example:
%     % Pass a random set of user-defined XY points to the solver
%     userConfig = struct('xy',10*rand(35,2));
%     resultStruct = mtspvofs_ga(userConfig);
%
% Example:
%     % Pass a more interesting set of XY points to the solver
%     n = 50;
%     phi = (sqrt(5)-1)/2;
%     theta = 2*pi*phi*(0:n-1);
%     rho = (1:n).^phi;
%     [x,y] = pol2cart(theta(:),rho(:));
%     xy = 10*([x y]-min([x;y]))/(max([x;y])-min([x;y]));
%     userConfig = struct('xy',xy);
%     resultStruct = mtspvofs_ga(userConfig);
%
% Example:
%     % Pass a random set of 3D (XYZ) points to the solver
%     xyz = 10*rand(35,3);
%     userConfig = struct('xy',xyz);
%     resultStruct = mtspvofs_ga(userConfig);
%
% Example:
%     % Change the defaults for GA population size and number of iterations
%     userConfig = struct('popSize',200,'numIter',1e4);
%     resultStruct = mtspvofs_ga(userConfig);
%
% Example:
%     % Turn off the plots but show a waitbar
%     userConfig = struct('showProg',false,'showResult',false,'showWaitbar',true);
%     resultStruct = mtspvofs_ga(userConfig);
%
% See also: tsp_ga, mtsp_ga, mtspofs_ga
%
% Author: Joseph Kirk
% Email: jdkirk630@gmail.com
%
function varargout = mtspvofs_ga(varargin)
    
    
    %
    % Initialize default configuration
    %
    defaultConfig.xy          = 10*rand(40,2);
    defaultConfig.dmat        = [];
    defaultConfig.minTour     = 3;
    defaultConfig.popSize     = 80;
    defaultConfig.numIter     = 5e3;
    defaultConfig.showProg    = true;
    defaultConfig.showStatus  = true;
    defaultConfig.showResult  = true;
    defaultConfig.showWaitbar = false;
    
    
    %
    % Interpret user configuration inputs
    %
    if ~nargin
        userConfig = struct();
    elseif isstruct(varargin{1})
        userConfig = varargin{1};
    else
        try
            userConfig = struct(varargin{:});
        catch
            error('??? Expected inputs are either a structure or parameter/value pairs');
        end
    end
    
    
    %
    % Override default configuration with user inputs
    %
    configStruct = get_config(defaultConfig,userConfig);
    
    
    %
    % Extract configuration
    %
    xy          = configStruct.xy;
    dmat        = configStruct.dmat;
    minTour     = configStruct.minTour;
    popSize     = configStruct.popSize;
    numIter     = configStruct.numIter;
    showProg    = configStruct.showProg;
    showStatus  = configStruct.showStatus;
    showResult  = configStruct.showResult;
    showWaitbar = configStruct.showWaitbar;
    if isempty(dmat)
        nPoints = size(xy,1);
        a = meshgrid(1:nPoints);
        dmat = reshape(sqrt(sum((xy(a,:)-xy(a',:)).^2,2)),nPoints,nPoints);
    end
    
    
    %
    % Verify inputs
    %
    [N,dims] = size(xy);
    [nr,nc] = size(dmat);
    if (N ~= nr) || (N ~= nc)
        error('??? Invalid XY or DMAT inputs')
    end
    n = N - 1; % Separate start city
    
    
    %
    % Sanity checks
    %
    minTour     = max(1,min(n,round(real(minTour(1)))));
    popSize     = max(8,8*ceil(popSize(1)/8));
    numIter     = max(1,round(real(numIter(1))));
    showProg    = logical(showProg(1));
    showStatus  = logical(showStatus(1));
    showResult  = logical(showResult(1));
    showWaitbar = logical(showWaitbar(1));
    
    
    %
    % Initialize the populations
    %
    maxSalesmen = floor(n / minTour);
    popRoute = zeros(popSize,n);	% population of routes
    popBreak = cell(popSize,1);     % population of breaks
    popRoute(1,:) = (1:n) + 1;
    popBreak{1} = rand_breaks();
    for k = 2:popSize
        popRoute(k,:) = randperm(n) + 1;
        popBreak{k} = rand_breaks();
    end
    
    
    %
    % Seed the algorithm with a previous result if available
    %
    if all(isfield(userConfig,{'optRoute','optBreak'}))
        optRoute = userConfig.optRoute;
        optBreak = userConfig.optBreak;
        isValidRoute = isequal(popRoute(1,:),sort(optRoute));
        isValidBreak = ~any(mod(optBreak,1)) && ...
            all(optBreak > 0) && all(optBreak <= n);
        if isValidRoute && isValidBreak
            popRoute(1,:) = optRoute;
            popBreak{1} = optBreak;
        end
    end
    
    
    %
    % Select the colors for the plotted routes
    %
    pclr = ~get(0,'DefaultAxesColor');
    clr = hsv(floor(n/minTour));
    
    
    %
    % Run the GA
    %
    globalMin = Inf;
    totalDist = zeros(1,popSize);
    distHistory = NaN(1,numIter);
    tmpPopRoute = zeros(8,n);
    tmpPopBreak = cell(8,1);
    newPopRoute = zeros(popSize,n);
    newPopBreak = cell(popSize,1);
    [isClosed,isStopped,isCancelled] = deal(false);
    if showProg
        hFig = figure('Name','MTSPVOFS_GA | Current Best Solution', ...
            'Numbertitle','off','CloseRequestFcn',@close_request);
        hAx = gca;
        if showStatus
            [hStatus,isCancelled] = figstatus(0,numIter,[],hFig);
        end
    end
    if showWaitbar
        hWait = waitbar(0,'Searching for near-optimal solution ...', ...
            'CreateCancelBtn',@cancel_search);
    end
    isRunning = true;
    for iter = 1:numIter
        
        %
        % Evaluate each population member (calculate total distance)
        %
        for p = 1:popSize
            d = 0;
            pRoute = popRoute(p,:);
            pBreak = popBreak{p};
            nSalesmen = length(pBreak)+1;
            rng = [[1 pBreak+1];[pBreak n]]';
            for s = 1:nSalesmen
                d = d + dmat(1,pRoute(rng(s,1))); % Add start distance
                for k = rng(s,1):rng(s,2)-1
                    d = d + dmat(pRoute(k),pRoute(k+1));
                end
            end
            totalDist(p) = d;
        end
        
        
        %
        % SELECT THE BEST
        %   This section of code finds the best solution in the current
        %   population and stores it if it is better than the previous best.
        %
        [minDist,index] = min(totalDist);
        distHistory(iter) = minDist;
        if (minDist < globalMin)
            globalMin = minDist;
            optRoute = popRoute(index,:);
            optBreak = popBreak{index};
            nSalesmen = length(optBreak)+1;
            rng = [[1 optBreak+1];[optBreak n]]';
            if showProg
                
                %
                % Plot the best route
                %
                for s = 1:nSalesmen
                    rte = [1 optRoute(rng(s,1):rng(s,2))];
                    if (dims > 2), plot3(hAx,xy(rte,1),xy(rte,2),xy(rte,3),'.-','Color',clr(s,:));
                    else, plot(hAx,xy(rte,1),xy(rte,2),'.-','Color',clr(s,:)); end
                    hold(hAx,'on');
                end
                if (dims > 2), plot3(hAx,xy(1,1),xy(1,2),xy(1,3),'o','Color',pclr);
                else, plot(hAx,xy(1,1),xy(1,2),'o','Color',pclr); end
                title(hAx,sprintf(['Total Distance = %1.4f, Salesmen = %d, ' ...
                    'Iteration = %d'],minDist,nSalesmen,iter));
                hold(hAx,'off');
                drawnow;
            end
        end
        
        
        %
        % Update the status bar and check cancellation status
        %
        if showProg && showStatus && ~mod(iter,ceil(numIter/100))
            [hStatus,isCancelled] = figstatus(iter,numIter,hStatus,hFig);
        end
        if (isStopped || isCancelled)
            break
        end
        
        
        %
        % MODIFY THE POPULATION
        %   This section of code invokes the genetic algorithm operators.
        %   In this implementation, solutions are randomly assigned to groups
        %   of eight and the best solution is kept (tournament selection).
        %   The best-of-eight solution is then mutated 3 different ways
        %   (flip, swap, and slide) and the four resulting solutions are
        %   then copied but assigned different break points to complete the
        %   group of eight. There is no crossover operator because it tends
        %   to be highly destructive and rarely improves a decent solution.
        %
        randomOrder = randperm(popSize);
        for p = 8:8:popSize
            rtes = popRoute(randomOrder(p-7:p),:);
            brks = popBreak(randomOrder(p-7:p));
            dists = totalDist(randomOrder(p-7:p));
            [ignore,idx] = min(dists); %#ok
            bestOf8Route = rtes(idx,:);
            bestOf8Break = brks{idx};
            routeInsertionPoints = sort(randperm(n,2));
            I = routeInsertionPoints(1);
            J = routeInsertionPoints(2);
            for k = 1:8 % Generate new solutions
                tmpPopRoute(k,:) = bestOf8Route;
                tmpPopBreak{k} = bestOf8Break;
                switch k
                    case 2 % Flip
                        tmpPopRoute(k,I:J) = tmpPopRoute(k,J:-1:I);
                    case 3 % Swap
                        tmpPopRoute(k,[I J]) = tmpPopRoute(k,[J I]);
                    case 4 % Slide
                        tmpPopRoute(k,I:J) = tmpPopRoute(k,[I+1:J I]);
                    case 5 % Change breaks
                        tmpPopBreak{k} = rand_breaks();
                    case 6 % Flip, change breaks
                        tmpPopRoute(k,I:J) = tmpPopRoute(k,J:-1:I);
                        tmpPopBreak{k} = rand_breaks();
                    case 7 % Swap, change breaks
                        tmpPopRoute(k,[I J]) = tmpPopRoute(k,[J I]);
                        tmpPopBreak{k} = rand_breaks();
                    case 8 % Slide, change breaks
                        tmpPopRoute(k,I:J) = tmpPopRoute(k,[I+1:J I]);
                        tmpPopBreak{k} = rand_breaks();
                    otherwise % Do nothing
                end
            end
            newPopRoute(p-7:p,:) = tmpPopRoute;
            newPopBreak(p-7:p) = tmpPopBreak;
        end
        popRoute = newPopRoute;
        popBreak = newPopBreak;
        
        
        %
        % Update the waitbar
        %
        if showWaitbar && ~mod(iter,ceil(numIter/325))
            waitbar(iter/numIter,hWait);
        end
        
    end
    if showProg && showStatus
        figstatus(numIter,numIter,hStatus,hFig);
    end
    if showWaitbar
        delete(hWait);
    end
    isRunning = false;
    if isClosed
        delete(hFig);
    end
    
    
    %
    % Append prior distance history if present
    %
    if isfield(userConfig,'distHistory')
        priorHistory = userConfig.distHistory;
        isNan = isnan(priorHistory);
        distHistory = [priorHistory(~isNan) distHistory];
    end
    
    
    %
    % Format the optimal solution
    %
    nSalesmen = length(optBreak)+1;
    optSolution = cell(nSalesmen,1);
    rng = [[1 optBreak+1];[optBreak n]]';
    for s = 1:nSalesmen
        optSolution{s} = [1 optRoute(rng(s,1):rng(s,2))];
    end
    
    
    %
    % Show the final results
    %
    if showResult
        
        %
        % Plot the GA results
        %
        figure('Name','MTSPVOFS_GA | Results','Numbertitle','off');
        subplot(2,2,1);
        if (dims > 2), plot3(xy(:,1),xy(:,2),xy(:,3),'.','Color',pclr);
        else, plot(xy(:,1),xy(:,2),'.','Color',pclr); end
        title('City Locations');
        subplot(2,2,2);
        imagesc(dmat([1 optRoute],[1 optRoute]));
        title('Distance Matrix');
        subplot(2,2,3);
        for s = 1:nSalesmen
            rte = optSolution{s};
            if (dims > 2), plot3(xy(rte,1),xy(rte,2),xy(rte,3),'.-','Color',clr(s,:));
            else, plot(xy(rte,1),xy(rte,2),'.-','Color',clr(s,:)); end
            title(sprintf('Total Distance = %1.4f',minDist));
            hold on;
        end
        if (dims > 2), plot3(xy(1,1),xy(1,2),xy(1,3),'o','Color',pclr);
        else, plot(xy(1,1),xy(1,2),'o','Color',pclr); end
        subplot(2,2,4);
        plot(distHistory,'b','LineWidth',2)
        title('Best Solution History');
        set(gca,'XLim',[1 length(distHistory)],'YLim',[0 1.1*max([1 distHistory])]);
    end
    
    
    %
    % Return output
    %
    if nargout
        
        %
        % Create anonymous functions for plot generation
        %
        plotPoints  = @(s)plot(s.xy(:,1),s.xy(:,2),'.','Color',~get(gca,'Color'));
        plotResult  = @(s)cellfun(@(s,i)plot(s.xy(i,1),s.xy(i,2),'.-', ...
            'Color',rand(1,3)),repmat({s},size(s.optSolution)),s.optSolution);
        plotHistory = @(s)plot(s.distHistory,'b-','LineWidth',2);
        plotMatrix  = @(s)imagesc(s.dmat(cat(2,s.optSolution{:}),cat(2,s.optSolution{:})));
        
        
        %
        % Save results in output structure
        %
        resultStruct = struct( ...
            'xy',          xy, ...
            'dmat',        dmat, ...
            'minTour',     minTour, ...
            'popSize',     popSize, ...
            'numIter',     numIter, ...
            'showProg',    showProg, ...
            'showResult',  showResult, ...
            'showWaitbar', showWaitbar, ...
            'optRoute',    optRoute, ...
            'optBreak',    optBreak, ...
            'optSalesmen', 1+length(optBreak), ...
            'optSolution', {optSolution}, ...
            'plotPoints',  plotPoints, ...
            'plotResult',  plotResult, ...
            'plotHistory', plotHistory, ...
            'plotMatrix',  plotMatrix, ...
            'distHistory', distHistory, ...
            'minDist',     minDist);
        
        varargout = {resultStruct};
        
    end
    
    
    %
    % Generate random set of breaks
    %
    function breaks = rand_breaks()
        nSalesmen = randi(maxSalesmen);
        nBreaks = nSalesmen - 1;
        breaks = [];
        if nBreaks
            if (minTour == 1) % No constraints on breaks
                breaks = sort(randperm(n-1,nBreaks));
            else % Force breaks to be at least the minimum tour length
                dof = n - minTour*nSalesmen;    % degrees of freedom
                addto = ones(1,dof+1);
                for kk = 2:nBreaks
                    addto = cumsum(addto);
                end
                cumProb = cumsum(addto)/sum(addto);
                nAdjust = find(rand < cumProb,1)-1;
                spaces = randi(nBreaks,1,nAdjust);
                adjust = zeros(1,nBreaks);
                for kk = 1:nBreaks
                    adjust(kk) = sum(spaces == kk);
                end
                breaks = minTour*(1:nBreaks) + cumsum(adjust);
            end
        end
    end
    
    
    %
    % Nested function to cancel search
    %
    function cancel_search(varargin)
        isStopped = true;
    end
    
    
    %
    % Nested function to close the figure window
    %
    function close_request(varargin)
        if isRunning
            [isClosed,isStopped] = deal(true);
            isRunning = false;
        else
            delete(hFig);
        end
    end
    
end

