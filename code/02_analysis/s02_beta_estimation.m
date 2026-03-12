%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%                                                                        %
%   Estimate 1st-Level Model (Beta Estimation)  (BIDS ready)             %
%                                                                        %
%   This script reads the Design Matrix (SPM.mat) for each subject and   %
%   task, and runs the estimation algorithm (Classical - Restricted      %
%   Maximum Likelihood). The outputs include images of the estimated     %
%   regression coefficients, an image of the variance of the error       %
%   (ResMS), an image indicating the voxels that were included in the    %
%   analysis (mask) and an image with the estimated resels per voxel     %
%   (RPV). The residuals are not saved, but written in the header.       %
%                                                                        %
%   Author: Dulce Travassos                                              %
%   Created: 12/03/2026                                                  %
%   Last update: 12/03/2026                                              %
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
protocols_dir = fullfile(base_dir,'derivatives','spm-events');

% List of Subjects
subjects = {
    'sub-002', 'sub-003', 'sub-004', 'sub-006', 'sub-007', 'sub-008', ...
    'sub-009', 'sub-011', 'sub-012', 'sub-013', 'sub-014', 'sub-015', ...
    'sub-016', 'sub-017', 'sub-018', 'sub-019', 'sub-020', 'sub-021', ...
    'sub-022', 'sub-023'
};

% Tasks
tasks = {'task-main','task-localizer'};

%%

% Initialize SPM
if isempty(which('spm')); addpath(spm_path); end
spm('defaults', 'FMRI');
spm_jobman('initcfg');

for s = 1:length(subjects)
    subj = subjects{s};
    fprintf('\n==================================================\n');
    fprintf('Beta estimation for: %s\n', subj);

    stats_dir = fullfile(deriv_dir,subj,'stats');
    
    for t=1:length(tasks)
        current_task = tasks{t};

        % Get Design Matrix (SPM.mat)
        design_matrix = fullfile(stats_dir,current_task,'SPM.mat');
        if ~exist(design_matrix,'file')
            fprintf('[WARNING] No SPM.mat found for %s (%s). Skipping.\n',subj,current_task);
            continue;
        end

        % ####################### SPM Batch #######################     
        clear matlabbatch;
        matlabbatch{1}.spm.stats.fmri_est.spmmat = {design_matrix};
        matlabbatch{1}.spm.stats.fmri_est.write_residuals = 0;
        matlabbatch{1}.spm.stats.fmri_est.method.Classical = 1;
        
        try
            spm_jobman('run', matlabbatch);
            fprintf('>>> Beta estimation successful for %s (%s)\n',subj,current_task);
        catch ME
            fprintf('[CRITICAL ERROR] SPM failed for %s (%s): %s\n',subj,current_task,ME.message);
            continue;
        end
    end
end

fprintf('\nFinished!\n')