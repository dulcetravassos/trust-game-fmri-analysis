%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%                                                                        %
%   Define Contrasts (Within-Subject / 1st-Level)                        %
%                                                                        %
%   This script defines the statistical contrast vectors for the         %
%   1st-Level analysis. It dynamically adjusts the vectors for subjects  %
%   with missing runs and excludes nuisance conditions (e.g., "excluded" %
%   or "NO_RESPONSE") by assigning them a weight of 0.                   %
%                                                                        %
%   Author: Dulce Travassos                                              %
%   Created: 16/03/2026                                                  %
%   Last update: 16/03/2026                                              %
%                                                                        %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

clear all; clc;

%% Initial Configurations
% Change according to your preferences
% Note that some parameters must be changed inside the main loop

spm_path = 'C:\Users\User\Desktop\Tese\spm12';

% Input and output directories
base_dir = 'C:\Users\User\Desktop\Tese\data\spm-data';
deriv_dir = fullfile(base_dir,'derivatives','spm-preprocessing');

% List of Subjects
subjects = {
    'sub-002', 'sub-003', 'sub-004', 'sub-006', 'sub-007', 'sub-008', ...
    'sub-009', 'sub-011', 'sub-012', 'sub-013', 'sub-014', 'sub-015', ...
    'sub-016', 'sub-017', 'sub-018', 'sub-019', 'sub-020', 'sub-021', ...
    'sub-022', 'sub-023'
};

% Tasks
tasks = {'task-main','task-localizer'};

%% Initial Considerations

% Generally, runs 1-4 are Congruent (stable) and 5-8 are Incongruent (relearning). Run 5 is the 
% Transition/Expectation Violation run.

% However, there are some exceptions that have to be considered when constructing the contrast vectors:
% sub-009: runs 1-4 congruent, only run 8 incongruent (missing 5-7)
%          (in fact, runs 1-7 congruent and only run 8 incongruent; we discard runs 5-7, but the 
%          truth is that this subject had more than the regular 4 runs to learn the pattern before
%          relearning...)
% sub-013: runs 2-4 congruent, 5-8 incongruent (missing early congruent run)
% sub-017: runs 1-3 congruent, 4-8 incongruent (transition happens at run 4)
%          (this means this subject had one less run to learn the pattern compared to other subjects 
%          and had one extra incongruent run...)


% Additionally, to ensure robust statistical inference and homogeneity of variance, conditions with 
% unequal trial frequencies were balanced by randomly assigning excess trials (using a fixed random 
% seed). Excess trials were explicitly modeled in the Design Matrix as separate conditions (labeled 
% with '_excluded') to preserve the implicit baseline.
% In this script, all conditions containing the string "excluded" or "NO_RESPONSE" act as nuisance 
% conditions and are strictly assigned a contrast weight of 0. This way, we do not "pollute" the 
% baseline, but still maintain the desired balance.

%% Video Contrasts
 
% Contrast 1: Global Partner Profile – which regions encode the overall positive or negative 
% interaction context associated with a partner, independent of their immediate gaze cue:
% (1a) Trustworthy Partner (TP) > Untrustworthy Partner (UP) 
% (1b) UP > TP 

% Contrast 2: Expectation Violation (Social Conflict) - which regions detect conflict when a 
% trusted partner emits a disrupting signal:
% (2a) TP Averted Gaze > TP Directed Gaze (Run 5) 
% (2b) TP Averted Gaze > TP Directed Gaze (Runs 6-8) 

% Contrast 3: Immediate Relearning (Cue Updating) - which regions manage the uncertainty and 
% rule (cue value) updating during the video presentation:
% Run 5 > Run 4 

% Contrast 4: Stability Network – distinguishes regions that maintain consolidated rules from 
% those that manage uncertainty (Stable Runs (2-4, 6-8) > Transition Run (5)):
% (4a) Stable Runs (2-4) > Transition Run (5)  
% (4b) Stable Runs (6-8) > Transition Run (5) 
% (4c) Stable Runs (6-8) > Stable Runs (2-4) 
% (4d) Stable Runs (2-4) > Stable Runs (6-8) 

% Contrast 5: Adaptation Network – distinguishes regions that manage uncertainty from those that 
% maintain consolidated rules (Transition Run (5) > Stable Runs (2-4,6-8)):
% (5a) Transition Run (5) > Stable Runs (2-4) 
% (5b) Transition Run (5) > Stable Runs (6-8) 
% (5c) Transition Run (5) > Stable Runs (2-4,6-8) 

% Contrast 6: Cue Value Remapping (Value Tracking) – verify if the neural representation of the 
% same physical stimulus (eye gaze) changes to track its current value:
% (6a) Averted + Directed Gaze (Congruent Phase) > Averted + Directed Gaze (Incongruent Phase) 
% (6b) Directed Gaze (Congruent Phase) > Directed Gaze (Incongruent Phase)  
% (6c) Averted Gaze (Congruent Phase) > Averted Gaze (Incongruent Phase) 

%% Feedback/Outcome Phase Contrasts 

% Contrast 7: Immediate Relearning (Prediction Error) – which regions respond to the sudden rule 
% change (violation of expected outcome) immediately after the reversal: 
% Run 5 > Run 4 

%% Investment Phase Contrasts 

% Contrast 8: Global Reversal Cost – which regions are recruited to manage the decision conflict 
% during action selection under the new rule:
% (8a) Run 5 > Run 4 (Immediate Conflict Cost) 
% (8b) Runs 5-6 > Runs 3-4 (Cost of Relearning/Sustained Conflict) 

% Contrast 9: Trust Magnitude (Parametric) - in which regions does the activity scale (linearly) 
% with the amount invested (tracking subjective confidence/risk): 
% Positive Effect of Investment Modulator 

%% Register Contrasts

% Initialize SPM
if isempty(which('spm')); addpath(spm_path); end
spm('defaults', 'FMRI');
spm_jobman('initcfg');

for s = 1:length(subjects)
    subj = subjects{s};
    fprintf('\n==================================================\n');
    fprintf('Defining Contrasts for: %s\n', subj);

    stats_dir = fullfile(deriv_dir,subj,'stats');
    
    for t=1:length(tasks)
        current_task = tasks{t};

        % Get Design Matrix (SPM.mat)
        design_matrix = fullfile(stats_dir,current_task,'SPM.mat');
        if ~exist(design_matrix,'file')
            fprintf('[WARNING] No SPM.mat found for %s (%s). Skipping.\n',subj,current_task);
            continue;
        end

        % Initialize columns
        load(design_matrix,'SPM');
        col_names = SPM.xX.name;
        num_cols = length(col_names);

        % ------------------- Subject Mapping -------------------  
        % Default
        run_trans = 5;
        runs_cong = [1, 2, 3, 4];
        runs_incong = [5, 6, 7, 8];

        % Exceptions
        if strcmp(subj,'sub-009')
            % Missing runs 5-7
            run_trans = 5;
            runs_cong = [1, 2, 3, 4];
            runs_incong = [5];
        elseif strcmp(subj,'sub-013')
            % Missing run 1
            run_trans = 4;
            runs_cong = [1, 2, 3];
            runs_incong = [4, 5, 6, 7];
        elseif strcmp(subj,'sub-017')
            % Transition happened at run 4
            run_trans = 4;
            runs_cong = [1, 2, 3];
            runs_incong = [4, 5, 6, 7, 8];
        end

        % ------------------- Build Contrast Vectors -------------------  
        con_1a = zeros(1,num_cols); % Contrast 1a
        con_1b = zeros(1,num_cols); % Contrast 1b

        for i = 1:num_cols
            name = col_names{i};  
            if contains(name,'excluded') || contains(name,'NO_RESPONSE')
                continue;
            end
            
            % ----- Video Phase Contrasts -----
            if contains(name,'VIDEO')

                % Contrast 1
                if contains(name,'TTrust')
                    con_1a(i) = 1;
                    con_1b(i) = -1;
                elseif contains(name,'TUntrust')
                    con_1a(i) = -1;
                    con_1b(i) = 1;
                end  

                % Contrast 2

                % Contrast 3

                % Contrast 4

                % Contrast 5

                % Contrast 6

            end

            % ----- Feedback/Outcome Phase Contrasts -----
            if contains(name,'FEEDBACK')
                % Contrast 7

            end

            % ----- Investment Phase Contrasts -----
                
                % Contrast 8
                
                % Contrast 9

        end


        % ####################### SPM Batch #######################     
        clear matlabbatch;
        % add matlabbatch...
         
        try
            spm_jobman('run', matlabbatch);
            fprintf('>>> Contrasts successfully created for %s (%s)\n',subj,current_task);
        catch ME
            fprintf('[CRITICAL ERROR] SPM failed for %s (%s): %s\n',subj,current_task,ME.message);
            continue;
        end
    end
end

fprintf('\nFinished!\n')