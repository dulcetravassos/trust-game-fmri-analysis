%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%                                                                        %
%   Estimate 2nd-Level Models (Group Beta Estimation)                    %
%                                                                        %
%   This script automates the estimation of group-level one-sample t-    %
%   -test models across all functional contrasts. It reads the group     %
%   Design Matrix (SPM.mat) generated in the previous step and runs the  %
%   estimation algorithm using Restricted Maximum Likelihood).           %
%                                                                        %
%   The outputs include images of the estimated group regression         %
%   coefficients (con_*.nii), the estimated variance of the error        %
%   (ResMS.nii), the analysis mask (mask.nii), and the estimated resels  %
%   per voxel (RPV.nii). Individual volume residuals are not saved to    %
%   conserve disk space.                                                 %
%                                                                        %
%   Author: Dulce Travassos                                              %
%   Created: 15/07/2026                                                  %
%   Last update: 18/08/2026                                              %
%                                                                        %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

clear all; clc;

%% Initial Configurations
% Change according to your preferences
% Note that some parameters must be changed inside the main loop

% Main folder
main_dir = 'C:\Users\User\Desktop\Tese';

spm_path = fullfile(main_dir,'spm12');

% Input and output directories
base_dir = fullfile(main_dir,'data','spm-data');
deriv_dir = fullfile(base_dir,'derivatives');

%% Beta Estimation

% Initialize SPM
if isempty(which('spm')); addpath(spm_path); end
spm('defaults', 'FMRI');
spm_jobman('initcfg');

all_cons = {'sc_1', 'sc_2', '1a', '1b', '2a', '2b', '3', '4a', '4b', ...
    '4c', '4d', '5a', '5b', '5c', '6a', '6b', '6c', '7', '8a', '8b', ...
    '9a', '9b', '9c', '9d'};

for c = 1:length(all_cons)
    con = all_cons{c};
    fprintf('\n==================================================\n');
    fprintf('Beta estimation for contrast: %s\n', con);

    stats_dir = fullfile(deriv_dir,'spm-statistics','2nd-level',con);

    % Get Design Matrix (SPM.mat)
    design_matrix = fullfile(stats_dir,'SPM.mat');
    if ~exist(design_matrix,'file')
        fprintf('[WARNING] No SPM.mat found for contrast %s. Skipping...\n',con);
        continue;
    end

    % ####################### SPM Batch #######################     
    clear matlabbatch;
    matlabbatch{1}.spm.stats.fmri_est.spmmat = {design_matrix};
    matlabbatch{1}.spm.stats.fmri_est.write_residuals = 0;
    matlabbatch{1}.spm.stats.fmri_est.method.Classical = 1;
    
    try
        spm_jobman('run', matlabbatch);
        fprintf('>>> Beta estimation successful for contrast %s\n',con);
    catch ME
        fprintf('[CRITICAL ERROR] SPM failed for contrast %s: %s\n',con,ME.message);
        continue;
    end
end

fprintf('\nFinished!\n')