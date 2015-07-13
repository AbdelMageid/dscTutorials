function animate(t,x,P)
%animate(t,x,P)
%
%FUNCTION:
%   Animate is used to animate a system with state x at the times in t.
%
%INPUTS:
%   t = [1xM] vector of times, Must be monotonic: t(k) < t(k+1)
%   x = [NxM] matrix of states, corresponding to times in t
%   P = animation parameter struct, with fields:
%     .plotFunc = @(t,x) = function handle to create a plot
%       	t = a scalar time
%       	x = [Nx1] state vector
%     .speed = scalar multiple of time, for playback speed
%     .figNum = (optional) figure number for plotting. Default = 1000.
%     .verbose = set to zero to prevent printing details.
%
%OUTPUTS:
%   Animation based on data in t and x.
%

if ~isfield(P,'figNum')
    P.figNum=1000;  %Default to figure 1000
end
if ~isfield(P,'verbose')
    P.verbose = 1;
end

% Common variables:
IS_PAUSED = false;
VERBOSE = P.verbose;
SPEED = P.speed;
QUIT = false;
SIM_TIME = 0;

% Set up the figure, and attach mouse events.
fig = figure(P.figNum);
set(fig,'KeyPressFcn',@keyDownListener)

%%%% Set up timing:
frameRate = 30;  %(frames per second)
minPause = 0.001;
maxPause = 1/frameRate;
timeBuffer = zeros(1,3);
dtReal = 1/frameRate;

tEnd = t(end);

tic;    %Start a timer
timeBuffer(1:3) = toc;
while SIM_TIME < tEnd;
    
    %Interpolate to get the new point:
    xNow = interp1(t',x',SIM_TIME,'linear','extrap')';
    
    %Call the plot command
    feval(P.plotFunc,SIM_TIME,xNow);
    drawnow;
    
    %Set up targets for timing
    if IS_PAUSED
        dtSim = 0;
    else
        dtSim = SPEED*dtReal;
    end
    SIM_TIME = SIM_TIME + dtSim;
    
    %Control the frame rate
    timeBuffer(3) = timeBuffer(2);
    timeBuffer(2) = timeBuffer(1);
    timeBuffer(1) = toc;
    pauseTime = 2*dtSim - (timeBuffer(1) - timeBuffer(3));
    pauseTime = min(max(minPause, pauseTime),maxPause);
    pause(pauseTime);
    
    % Check exit conditions:
    if QUIT
        break
    end
    
end

%~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~%
%                   Graphics call-back functions                          %
%~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~%


    function keyDownListener(src,event)
        switch event.Key
            case 'space'
                IS_PAUSED = ~IS_PAUSED;
                if VERBOSE
                    if IS_PAUSED
                        fprintf('--> animation paused...');
                    else
                        fprintf(' resumed! \n');
                    end
                end
            case 'uparrow'
                SPEED = 2*SPEED;
                if VERBOSE
                    fprintf('--> speed set to %3.3f x real time\n',SPEED);
                end
            case 'downarrow'
                SPEED = SPEED/2;
                if VERBOSE
                    fprintf('--> speed set to %3.3f x real time\n',SPEED);
                end
            case 'rightarrow'
                timeSkip = 5*SPEED*dtReal;
                SIM_TIME = SIM_TIME + timeSkip;
                if VERBOSE
                    fprintf('--> skipping forward by %3.3f seconds\n',timeSkip);
                end
            case 'leftarrow'
                timeSkip = 5*SPEED*dtReal;
                SIM_TIME = SIM_TIME - timeSkip;
                if VERBOSE
                    fprintf('--> skipping backward by %3.3f seconds\n',timeSkip);
                end
            case 'escape'
                QUIT = true;
                if VERBOSE
                    disp('--> animation aborted');
                end
            otherwise
        end
    end


end %animate.m
