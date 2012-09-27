% bare bones example of use of the QRSim() simulator
% with the plume scenario
%
% in this scenario one or more plumes (that might evolve over time) are present in the flight area
% an helicopter agent is equipped with a sensor that measures the concentration of smoke. 
% The plume follows a known model but with unknown parameter values. 
% The objective is to provide a smoke concentration estimate cT at some prespecified time T

clear all
close all

% include simulator
addpath(['..',filesep,'..',filesep,'sim']);
addpath(['..',filesep,'..',filesep,'controllers']);

% create simulator object
qrsim = QRSim();

% load task parameters and do housekeeping
state = qrsim.init('TaskPlumeSingleSourceGaussian');
%state = qrsim.init('TaskPlumeSingleSourceGaussianDispersion');
%state = qrsim.init('TaskPlumeMultiSourceGaussianDispersion');
%state = qrsim.init('TaskPlumeMultiHeliMultiSourceGaussianDispersion');
%state = qrsim.init('TaskPlumeSingleSourceGaussianPuffDispersion');
%state = qrsim.init('TaskPlumeMultiSourceGaussianPuffDispersion');
%state = qrsim.init('TaskPlumeMultiHeliMultiSourcePuffDispersion');


% create a 2 x helicopters matrix of control inputs
% column i will contain the 2D NED velocity [vx;vy] in m/s for helicopter i
U = zeros(2,qrsim.task.Nc);
tstart = tic;

% run the scenario and at every timestep generate a control
% input for each of the helicopters
for i=1:qrsim.task.durationInSteps,
    tloop=tic;
    
    % a basic policy in which the helicopter(s) moves around 
    % at the max velocity in rand directions 
    for j=1:qrsim.task.numUAVs,        
	
	% random velocity direction
	u = rand(2,1);        

        % scale by the max allowed velocity
        U(:,j) = qrsim.task.velPIDs{j}.maxv*(u/norm(u));
    end
    
    % step simulator
    qrsim.step(U);
    
    % wait so to run in real time
    % this can be commented out obviously
    wait = max(0,state.DT-toc(tloop));
    pause(wait);
end

% get final reward
% reminder: a large negative final reward (-1000) is returned in case of
% collisions or in case of any uav going outside the flight area
fprintf('final reward: %f\n',qrsim.reward());

elapsed = toc(tstart);

fprintf('running %d times real time\n',(qrsim.task.durationInSteps*state.DT)/elapsed);
