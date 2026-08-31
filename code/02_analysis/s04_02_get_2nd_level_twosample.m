%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%                                                                        %
%   2nd-Level Design Matrix (Two-Sample)                                 %
%                                                                        %
%   This script automates the creation of 2nd-level two-sample t-test    %
%   group models to compare 'Learners' vs 'Non-Learners'.                %
%                                                                        %
%   Author: Dulce Travassos                                              %
%   Created: 27/08/2026                                                  %
%   Last update: 01/09/2026                                              %
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

% List of subjects divided by groups
learners = {
    'sub-819', 'sub-147', 'sub-915', 'sub-641', 'sub-119', 'sub-958', 'sub-965', 'sub-971', 'sub-664', 'sub-162', 'sub-960'
    };

non_learners = {
    'sub-908', 'sub-557', 'sub-177', 'sub-497', 'sub-805', 'sub-435', 'sub-917', 'sub-797'
    };

%% Specify 2nd-Level

% Initialize SPM
if isempty(which('spm')); addpath(spm_path); end
spm('defaults', 'FMRI');
spm_jobman('initcfg');

% List of contrasts that will have two-sample analysis
all_cons = {'con_0005', 'con_0006', 'con_0007', 'con_0015', 'con_0016', 'con_0017', 'con_0018'};
all_cons_names = {'2a', '2b', '3', '6a', '6b', '6c', '7'};

% Create main output folder
second_level_dir = fullfile(deriv_dir,'spm-statistics','2nd-level_TwoSample');
if ~exist(second_level_dir,'dir'); mkdir(second_level_dir); end;

fprintf('\n==================================================\n');
fprintf('Starting 2nd-level Two-Sample model specification');
fprintf('\n==================================================\n');

for c = 1:length(all_cons)
    
    current_con_code = all_cons{c};
    current_con_name = all_cons_names{c};

    fprintf('\nProcessing Contrast: %s (%s)\n',current_con_name,current_con_code);

    % Create output folder for this contrast
    con_folder = fullfile(second_level_dir,current_con_name);
    if ~exist(con_folder,'dir'); mkdir(con_folder); end;

    scans_group1 = {}; % learners
    scans_group2 = {}; % non-learners

    % Get scans for Group 1
    for s = 1:length(learners)
        subj = learners{s};
        stats_dir = fullfile(deriv_dir,'spm-preprocessing',subj,'stats','task-main');

        % Get contrast file
        con_file = fullfile(stats_dir,sprintf('%s.nii',current_con_code));
        if exist(con_file,'file')
            scans_group1{end+1,1} = sprintf('%s,1',con_file);
        else
            % protection against subjects without the contrast
            fprintf('[WARNING] %s not found for %s (Learner). Subject skipped for this model...\n',current_con_code,subj);
        end
    end

    % Get scans for Group 2
    for s = 1:length(non_learners)
        subj = non_learners{s};
        stats_dir = fullfile(deriv_dir,'spm-preprocessing',subj,'stats','task-main');

        % Get contrast file
        con_file = fullfile(stats_dir,sprintf('%s.nii',current_con_code));
        if exist(con_file,'file')
            scans_group2{end+1,1} = sprintf('%s,1',con_file);
        else
            % protection against subjects without the contrast
            fprintf('[WARNING] %s not found for %s (Non-Learner). Subject skipped for this model...\n',current_con_code,subj);
        end
    end

    if isempty(scans_group1) || isempty(scans_group2)
        fprintf('[ERROR] Missing data in one of the groups for %s. Skipping...\n',current_con_name);
        continue;
    end
    
    % ####################### SPM Batch #######################          
    clear matlabbatch;
    matlabbatch{1}.spm.stats.factorial_design.dir = {con_folder};
    matlabbatch{1}.spm.stats.factorial_design.des.t2.scans1 = scans_group1;
    matlabbatch{1}.spm.stats.factorial_design.des.t2.scans2 = scans_group2;
    matlabbatch{1}.spm.stats.factorial_design.des.t2.dept = 0; % independent samples
    matlabbatch{1}.spm.stats.factorial_design.des.t2.variance = 1; % unequal variance
    matlabbatch{1}.spm.stats.factorial_design.des.t2.gmsca = 0; % not for fMRI
    matlabbatch{1}.spm.stats.factorial_design.des.t2.ancova = 0; % not for fMRI
    matlabbatch{1}.spm.stats.factorial_design.cov = struct('c', {}, 'cname', {}, 'iCFI', {}, 'iCC', {});
    matlabbatch{1}.spm.stats.factorial_design.multi_cov = struct('files', {}, 'iCFI', {}, 'iCC', {});
    matlabbatch{1}.spm.stats.factorial_design.masking.tm.tm_none = 1;
    matlabbatch{1}.spm.stats.factorial_design.masking.im = 1;
    matlabbatch{1}.spm.stats.factorial_design.masking.em = {''};
    matlabbatch{1}.spm.stats.factorial_design.globalc.g_omit = 1;
    matlabbatch{1}.spm.stats.factorial_design.globalm.gmsca.gmsca_no = 1;
    matlabbatch{1}.spm.stats.factorial_design.globalm.glonorm = 1;

    try
        spm_jobman('run', matlabbatch);
        fprintf('>>> 2nd-Level Design Matrix successfully created for %s (%d Learners vs %d Non-Learners)\n',current_con_name,length(scans_group1),length(scans_group2));
    catch ME
        fprintf('[CRITICAL ERROR] SPM failed for %s: %s\n',current_con_name,ME.message);
        continue;
    end
end

fprintf('\nFinished!\n')