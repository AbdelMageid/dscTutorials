function X = Initial_State(P)

if ~P.MS.Initialize_from_File

    X.duration = mean(P.Bnd.duration);

    Ns = P.MS.nGrid - 2;   %We already know the initial and final states!

    %Linear interpolation for the state initialization. This will not end
    %up looking like a line because of the spacing of the chebyshev grid,
    %but it shouldn't matter if everything else is set up well.
    X.state = zeros(4,Ns);
    for i=1:4
       tmp = linspace(P.MS.Start(i),P.MS.Finish(i),Ns+2);
       X.state(i,:) = tmp(2:(end-1));
    end

    %Vector for the actuator force at each grid point
    X.force = zeros(1,P.MS.nGrid);
    
    
else  %Then we are going to initialize from a file:
    
    uiopen('*.mat');  
    %We will assume that the data file has the variable Results with a
    %field Xsoln, that contains the previous solution.
    
    N = length(Results.Xsoln.force);
    if N == P.MS.nGrid   %Then same grid spacing
        X = Results.Xsoln;
    else
        X.duration = Results.Xsoln.duration;
        
        domain = [0,Results.Xsoln.duration];
        newGrid = chebyshevPoints(P.MS.nGrid,domain);
        
        statesOld = [Results.P.MS.Start, Results.Xsoln.state, Results.P.MS.Finish];
        statesNew = chebyshevInterpolate(statesOld,newGrid,domain);
        X.state = statesNew(:,2:(end-1));
        
        X.force = chebyshevInterpolate(Results.Xsoln.force,newGrid,domain);
    end
    
end