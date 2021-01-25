function [sCoreParams, variantConfig, sInputData, sInputTrigger, sMultiTimeInputData, sMultiTimeInputTrigger, sRandomStimulation] = initializationScript(whatToDo, sCoreParams, freqBandName, featureName, stimulationType, detectorType, triggerType, experimentType, stateOutput, contactNumbers1, contactNumbers2, triggerChannel, whatTypeSimulation, realDataFileName, variantConfig, neuralModelParams)
%Function to iniliatize simulink parameters and variants
% Inputs:
%   
% 1.   whatToDo: whether to simulate, compile or prepare model to run in real time
%       Options: 'SIMULATION' / 'COMPILE' / 'REAL-TIME' / 'NHP'
%           if whatToDo = Simulation also create data for simulation
%
% 2. freqBandName: Name of frequency band of interest
%       Options: THETA / ALPHA / BETA / LOWGAMMA / HIGHGAMMA / HIGHGAMMARIPPLE /RIPPLE /LP7HIGHGAMMA
%
% 3. featureName: Name of Feature to compute and detect - assumes same one is used for signal and baseline - except for IED)
%       Options: BANDPOWER / SMOOTHBANDPOWER / VARIANCEOFPOWER / COHERENCE / IED (to use Anish code)
%
% 4. stimulationType: Whether stimulation hapens inmediately (REALTIME) or at the time of a trigger (NEXTTRIAL)
%       Options: REALTIME / NEXTTRIAL / AMS3800 (for NHP)
%
% 4. detectorType: A specific detector could be specified (to detect only during trial or all the time)- but be careful, there are different detectors for POWER and COHERENCE features
%       Options: CONTINUOUS / TRIGGER / MULTISITE / IED
%
% 5. triggerType: A specific trigger type could be specified to compute baseline based on EEG trigger (image onset), periodically, or after N stimulations
%       Options: EEGDATA / FIXEDPERIOD / FOLLOWINGSTIM
%
% 6. experimentType: A specific EXPERIMENT could be specified which results in a specific MODEL
%       Options: MSIT/ECR -> NEURALMODEL / CLEAR -> CLEARMDOEL
%
% 7. stateOutput: which state model output to use in detection (mean or bound)
%       Options: MEAN / BOUNDLOWER / BOUNDUPPER
%
% 6. contactNumbers1 / contactNumbers2: Numbers of contacts in referential montage. 
%       Combining both vectors gives bipolar channels: e.g. Ch1=contactNumbers1(1)-contactNumbers2(1)
%
% 7. detectChannelInds: Index (out of bipolar channels) to consider for detection (default: all bipolar channels)
%       - use vector of bipolar channels for power feature
%       - use square 0-1 matrix for coherence pairs (e.g. [0 1 1; 0 0 1; 0 0 0] for 1-3, 2-3 and 2-3 pairs)
%
% 8. triggerChannel: specify NSP contact number where trigger (image onset) is coming (default: 129)
%
% 9. whatTypeSimulation: simulation data type
%       Options are 'SINE' or 'REAL' or 'NEV' 
%
% 10. realDataFileName= which file to use for real data (for simulation OR random stimulation)
%
% NOTE: not all options are implemented here - only common ones!

%% Check Inputs
if ~exist('whatToDo','var')
   whatToDo = [];
end
if ~exist('sCoreParams','var')
   sCoreParams = [];
end
if ~exist('freqBandName','var')
   freqBandName = 'THETAALPHAGAMMA';
end
if ~exist('featureName','var')
   featureName = 'LOGBANDPOWER';
end
if ~exist('stimulationType','var')
   stimulationType = '';
end
if ~exist('detectorType','var')
   detectorType = '';
end
if ~exist('triggerType','var')
   triggerType = '';
end
if ~exist('stateModel','var')
   stateModel = '';
end
if ~exist('stateOutput','var')
   stateOutput = '';
end
if ~exist('contactNumbers1','var')
   contactNumbers1 = [];
end
if ~exist('contactNumbers2','var')
   contactNumbers2 = [];
end
if ~exist('triggerChannel','var')
   triggerChannel = [];
end
if ~exist('whatTypeSimulation','var') || isempty(whatTypeSimulation)
    whatTypeSimulation = 'SINE'; %'NEV'; %'REAL';  % options are 'SINE' or 'REAL' or 'NEV'
end
if ~exist('realDataFileName','var') || isempty(realDataFileName)
    realDataFileName = 'C:\DARPA\DATA\Simulations\SimData_WithTriggers_MG106.mat'; %'C:\DARPA\DATA\Simulations\SimData_CoherencePairs_MG88.mat';  %
end

if ~exist('variantConfig','var')
   variantConfig = [];
end
if ~exist('neuralModelParams','var')
    neuralModelParams.nEpochs = 1;
end

%% Initialize parameters and variants
% Initialize parameters if NOT provided
if isempty(sCoreParams) %only run initCore if sCoreParams does not exist
    sCoreParams=InitCoreParams;
end
% Initialize variantConfig if NOT provided
if isempty(variantConfig)
    [variantParams, variantConfig] = InitVariants();
else
    [variantParams] = InitVariants(); % if variantConfig is provided we only need the variant names (variantParams)
end

%% First run InitializeSimulation to initialize sCoreParams and Variants
sInputData=[];sMultiTimeInputData=[];
sInputTrigger=[];sMultiTimeInputTrigger=[];
sRandomStimulation=[];
switch upper(whatToDo)
    case 'SIMULATION'
        [sCoreParams, variantParams, variantConfig, variantConfigFlatNames, sInputData, sInputTrigger, sMultiTimeInputData, sMultiTimeInputTrigger] = InitializeSimulation(whatTypeSimulation, sCoreParams, variantConfig, realDataFileName);
    case 'NHP'
        [sCoreParams, variantParams, variantConfig, variantConfigFlatNames] = InitializeNHPPlexon(sCoreParams, variantConfig);

    case {'RANDOMSTIM','RANDOMSTIMULATION'}
        % Create train of stimulation from previous data
        sRandomStimulation = CreateStimulationTrainFromPreviousSession(realDataFileName);
        
    case {'REALTIME','REAL-TIME'}
        %Only initialize the variables and variants if in real time - no need to call InitializeSimulation
        disp('REAL-TIME Closed Loop experiment - initialized');

    otherwise
        disp('WARNING::: whatToDo option ',whatToDo,' unknown! Using defaults');
end
[variantParamsFlatNames, variantConfigFlatNames] = NameTunableVariants();
    
%% Select Frequency Band
[variantConfig, sCoreParams] = selectFrequencyBandConfig(freqBandName, variantConfig, sCoreParams);
disp(['Selected frequency: ', freqBandName,' corresponds to variantConfig_FREQ_LOW = ', num2str(variantConfig.FREQ_LOW)])

%% Assign Channels 
if ~isempty(contactNumbers1) && ~isempty(contactNumbers2)
    sCoreParams.decoders.txDetector.channel1 = contactNumbers1; % e.g. [1 3 5];
    sCoreParams.decoders.txDetector.channel2 = contactNumbers2; % e.g. [2 4 6];
    sCoreParams.decoders.txDetector.nChannels = length(contactNumbers1); % Assumes same length
    sCoreParams.decoders.txDetector.nPairs = sCoreParams.decoders.txDetector.nChannels * (sCoreParams.decoders.txDetector.nChannels-1) /2;
end

if ~isempty(triggerChannel)
    sCoreParams.decoders.txDetector.triggerChannel = triggerChannel; % Channel were digital input corresponding to image onset is (usually: 129 - for simulation: 201)  
end

%% Select Feature
[variantConfig, sCoreParams] = selectFeatureConfig(featureName, variantConfig, sCoreParams, neuralModelParams.nEpochs);
disp(['Selected Feature: ', featureName,' corresponds to Feat=', num2str(variantConfig.WHICH_FEATURE), ' - BaselineFeat=',num2str(variantConfig.WHICH_FEATURE_BASELINE), ' - Detector=',num2str(variantConfig.WHICH_DETECTOR),...
    ' - nFreqs=',num2str(sCoreParams.decoders.txDetector.nFreqs),' - nEpochs=', num2str(neuralModelParams.nEpochs) ]);

%% Select Detector Type
[variantConfig] = selectDetectorNeuralModelConfig(detectorType, variantConfig, featureName);
disp(['Selected Detector: ', detectorType, ' corresponds to Det=', num2str(variantConfig.WHICH_DETECTOR), '- Feature: ', featureName,' corresponds to Feat=', num2str(variantConfig.WHICH_FEATURE), ' - BaselineFeat=',num2str(variantConfig.WHICH_FEATURE_BASELINE) ]);

%% Select Timing of stimulation
[variantConfig] = selectWhenToStimulate(stimulationType, variantConfig, detectorType);
disp(['Selected STIMULATION_TYPE: ', stimulationType,' corresponds to variantConfig_STIMULATION_TYPE = ', num2str(variantConfig.STIMULATION_TYPE)])

%% SelectType of Trigger (to compute threshold from baseline)
variantConfig = selectTriggerTypeConfig(triggerType, variantConfig);
disp(['Selected TRIGGER_TYPE: ', triggerType,' corresponds to variantConfig_TRIGGER_TYPE = ', num2str(variantConfig.TRIGGER_TYPE)])

%% Select state estimate MODEL (NeuralStateEstimate or CLEAR)
variantConfig = selectStateModelConfig(experimentType, variantConfig, featureName);
disp(['Selected Experiment: ', experimentType,' corresponds to variantConfig_STATEMODEL = ', num2str(variantConfig.STATEMODEL)])

%% Select state estimate output
variantConfig = selectStateEstimateOutput(stateOutput, variantConfig);
disp(['Selected STATEOUTPUT: ', stateOutput,' corresponds to variantConfig_STATEOUTPUT = ', num2str(variantConfig.STATEOUTPUT)])

%% Update sCoreParams in Worksapce
sCoreParams = InitCoreParams_Dependent(sCoreParams); % reassign dependable
assignin('base','sCoreParams',sCoreParams);

%% Update Variables and Variant Config  in Worksapce
FlattenAndTuneVariants(variantParams,'variantParams',variantParamsFlatNames);
FlattenAndTune(variantConfig,'variantConfig',variantConfigFlatNames);
FlattenAndTune(sCoreParams, 'sCoreParams',NameTunableParams);

%% Load simulation data in Worksapce
if strcmpi(whatToDo, 'SIMULATION')
    assignin('base','sInputData',sInputData);
    assignin('base','sInputTrigger',sInputTrigger);
    assignin('base','sMultiTimeInputData',sMultiTimeInputData);
    assignin('base','sMultiTimeInputTrigger',sMultiTimeInputTrigger);
end
if strncmpi(whatToDo, 'RANDOMSTIM',length('RANDOMSTIM'))
    assignin('base','sRandomStimulation',sRandomStimulation);
end
