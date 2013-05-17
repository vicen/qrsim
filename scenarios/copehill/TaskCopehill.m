classdef TaskCopehill<Task
    % Simple task in which a quadrotor flies a few waypoint over the
    % CopeHill down map
    %
    % KeepSpot methods:
    %   init()   - loads and returns all the parameters for the various simulator objects
    %   reward() - returns the instantateous reward for this task
    %
    %
    % GENERAL NOTES:
    % - if the on flag is zero, the NOISELESS version of the object is loaded instead
    % - the step dt MUST be always specified eve if on=0
    %
    properties (Constant)
        PENALTY = 1000; % penalty in case of collision or out of bounds
    end
    
    methods (Sealed,Access=public)
        
        function obj = TaskCopehill(state)
            % constructor
            obj = obj@Task(state);
        end
        
        function taskparams=init(obj) %#ok<MANU>
            % loads and returns all the parameters for the various simulator objects
            %
            % Example:
            %   params = obj.init();
            %          params - all the task parameters
            %
            
            taskparams.dt = 0.02; % task timestep i.e. rate at which controls
            % are supplied and measurements are received
            
            taskparams.seed = 0; %set to zero to have a seed that depends on the system time
            
            %%%%% visualization %%%%%
            % 3D display parameters
            taskparams.display3d.on = 1;
            taskparams.display3d.width = 1000;
            taskparams.display3d.height = 600;
            
            %%%%% environment %%%%%
            % these need to follow the conventions of axis(), they are in m, Z down
            % note that the lowest Z limit is the refence for the computation of wind shear and turbulence effects
            taskparams.environment.area.limits = [ -120 120 -150 200 -60 0];
            taskparams.environment.area.type = 'BoxWithHousesAndPersonsArea';
            
            % originutmcoords is the location of the RVC (our usual flying site)
            % generally when this is changed gpsspacesegment.orbitfile and
            % gpsspacesegment.svs need to be changed
            [E N zone h] = llaToUtm([51.71190;-0.21052;0]);
            taskparams.environment.area.originutmcoords.E = E;
            taskparams.environment.area.originutmcoords.N = N;
            taskparams.environment.area.originutmcoords.h = h;
            taskparams.environment.area.originutmcoords.zone = zone;
            taskparams.environment.area.numpersonsrange = [5,10];         % number of person selected at random between these limits
            taskparams.environment.area.personfounddistancethreshold = 5; % distance within which a person is deemed as found [m]
            taskparams.environment.area.personfoundspeedthreshold = 0.1;  % speed lower than which the uav has to travel when close to a person to deem it found [m/s]
            taskparams.environment.area.personsize = 0.5;                 % size of the edge of the square patch representing a person [m]
            taskparams.environment.area.graphics.type = 'SearchAreaWithHousesGraphics';
            taskparams.environment.area.terrain.type = 'PourTerrain';   
            taskparams.environment.area.terrain.classpercentages = [0.2,0.05];  % 20% clutter, 5% occlusion => 75% no clutter & no occlusions 
            taskparams.environment.area.personinclassprob = [0.0,0.0];  % prob 0 of person being in terrain of class clutter
                                                                        % prob 0 of person being in terrain of class occlusion
                                                                        % prob 1 of person being in terrain of class no clutter & no occlusions            
            taskparams.environment.area.graphics.backgroundimage = 'chd.tif';
            taskparams.environment.area.boxes = [  -63   -36   -22   -41   -50   -59    -71     -83  -106   -92   -82   -72   -65   -30   -18;   % X
                                                  -133  -152  -132   -98   -56   -75    -95    -120   -91   -63   -46   -30   -13   -18    -5;   % Y
                                                  -2.1  -2.1  -2.1  -2.1  -2.1  -2.1   -2.1    -2.1  -2.1  -2.1  -2.1  -2.1  -2.1  -2.1  -2.1;   % Z
                                                   8.5    10     6     6   5.5     5      5       5     7   5.5   5.5   5.5   6.5     5     5;   % width
                                                    14     6     6     5     6   6.5    6.5     6.5    15   6.5   6.5   6.5   8.5     6     6;   % depth
                                                     7     5     4     3     4     3      4       3     5     3     4     3     4     3     3;   % height
                                               -pi/4.9 pi/30 pi/30 -pi/5 -pi/5 -pi/5  -pi/5 -pi/5.5 -pi/6 -pi/6 -pi/6 -pi/6 -pi/6 -pi/8 -pi/8;]; % rotation                                                 
            
            % GPS
            % The space segment of the gps system
            taskparams.environment.gpsspacesegment.on = 0; % if off the gps returns the noiseless position
            taskparams.environment.gpsspacesegment.dt = 0.2;
            % real satellite orbits from NASA JPL
            taskparams.environment.gpsspacesegment.orbitfile = 'ngs15992_16to17.sp3';
            % simulation start in GPS time, this needs to agree with the sp3 file above,
            % alternatively it can be set to 0 to have a random initialization
            %taskparams.environment.gpsspacesegment.tStart = Orbits.parseTime(2010,8,31,16,0,0);
            taskparams.environment.gpsspacesegment.tStart = 0;
            % id number of visible satellites, the one below are from a typical flight day at RVC
            % these need to match the contents of gpsspacesegment.orbitfile
            taskparams.environment.gpsspacesegment.svs = [3,5,6,7,13,16,18,19,20,22,24,29,31];
            % the following model is from [2]
            %taskparams.environment.gpsspacesegment.type = 'GPSSpaceSegmentGM';
            %taskparams.environment.gpsspacesegment.PR_BETA = 2000;     % process time constant
            %taskparams.environment.gpsspacesegment.PR_SIGMA = 0.1746;  % process standard deviation
            % the following model was instead designed to match measurements of real
            % data, it appears more relistic than the above
            taskparams.environment.gpsspacesegment.type = 'GPSSpaceSegmentGM2';
            taskparams.environment.gpsspacesegment.PR_BETA2 = 4;       % process time constant
            taskparams.environment.gpsspacesegment.PR_BETA1 =  1.005;  % process time constant
            taskparams.environment.gpsspacesegment.PR_SIGMA = 0.003;   % process standard deviation
            
            % Wind
            % i.e. a steady omogeneous wind with a direction and magnitude
            % this is common to all helicopters
            taskparams.environment.wind.on = 0;
            taskparams.environment.wind.type = 'WindConstMean';
            taskparams.environment.wind.direction = degsToRads(45); %mean wind direction, rad clockwise from north set to [] to initialise it randomly
            taskparams.environment.wind.W6 = 0.5;  % velocity at 6m from ground in m/s
            
            
            
            %%%%% platforms %%%%%
            % Configuration and initial state for each of the platforms
            taskparams.platforms(1).configfile = 'noiseless_config';
        end
        
        function reset(obj)
            % initial state
            obj.simState.platforms{1}.setX([6;-8;-20;0;0;0]);
        end
        
        function r=updateReward(~,~)
            % no istantaneous reward defined
            r = 0;
        end
        
        function r=reward(~)
            % no final reward defined
            r = 0;
        end
    end
    
end



% [1] J. Rankin, "An error model for sensor simulation GPS and differential GPS," IEEE
%     Position Location and Navigation Symposium, 1994, pp.260-266.
% [2] Carlson, Justin, "Mapping Large, Urban Environments with GPS-Aided SLAM" (2010).
%     Dissertations. Paper 44.
