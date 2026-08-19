%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%                                                                        %
%   2nd-Level Design Matrix                                              %
%                                                                        %
%   This script automates the creation of 2nd-level one-sample t-test    %
%   group models across all functional contrasts generated in the first- %     
%   -level GLM. It creates distinct output directories for each          %
%   contrast, and gets the corresponding con_*.nii files from each       %
%   subject's first-level statistics folder. It includes defensive       %
%   file-checking to handle missing data (e.g., subjects with an         %
%   incomplete contrast set).                                            %
%                                                                        %
%   Author: Dulce Travassos                                              %
%   Created: 15/07/2026                                                  %
%   Last update: 19/08/2026                                              %
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

% List of Subjects
subjects = {
    'sub-002', 'sub-003', 'sub-004', 'sub-006', 'sub-007', 'sub-008', ...
    'sub-009', 'sub-011', 'sub-012', 'sub-013', 'sub-014', 'sub-015', ...
    'sub-016', 'sub-017', 'sub-018', 'sub-019', 'sub-020', 'sub-021', ...
    'sub-022', 'sub-023'
};

%% Specify 2nd-Level

% Initialize SPM
if isempty(which('spm')); addpath(spm_path); end
spm('defaults', 'FMRI');
spm_jobman('initcfg');

all_cons = {'con_0001', 'con_0002', 'con_0003', 'con_0004', 'con_0005', 'con_0006', 'con_0007', 'con_0008', ...
    'con_0009', 'con_0010', 'con_0011', 'con_0012', 'con_0013', 'con_0014', 'con_0015', 'con_0016', 'con_0017', ...
    'con_0018', 'con_0019', 'con_0020', 'con_0021', 'con_0022', 'con_0023', 'con_0024','con_0025', 'con_0026', 'con_0027'};

all_cons_names = {'sc_1', 'sc_2', '1a', '1b', '2a', '2b', '3', '4a', '4b', '4c', '4d', '5a',  ...
    '5b', '5c', '6a', '6b', '6c', '7', '8a', '8b', '9a', '9b', '9c', '9d', '10a', '10b', '10c'};

% Create main output folder
second_level_dir = fullfile(deriv_dir,'spm-statistics','2nd-level');
if ~exist(second_level_dir,'dir'); mkdir(second_level_dir); end;

fprintf('\n==================================================\n');
fprintf('Starting 2nd-level model specification');
fprintf('\n==================================================\n');

for c = 1:length(all_cons)
    
    current_con_code = all_cons{c};
    current_con_name = all_cons_names{c};

    fprintf('\nProcessing Contrast: %s (%s)\n',current_con_name,current_con_code);

    % Create output folder for this contrast
    con_folder = fullfile(second_level_dir,current_con_name);
    if ~exist(con_folder,'dir'); mkdir(con_folder); end;

    cons_list = {};

    for s = 1:length(subjects)
        subj = subjects{s};
        stats_dir = fullfile(deriv_dir,'spm-preprocessing',subj,'stats','task-main');

        % Get contrast file
        con_file = fullfile(stats_dir,sprintf('%s.nii',current_con_code));
        if exist(con_file,'file')
            cons_list{end+1,1} = sprintf('%s,1',con_file);
        else
            % protection against subjects without the contrast
            fprintf('[WARNING] %s not found for %s. Subject skipped for this model...\n',current_con_code,subj);
        end

    end

    if isempty(cons_list)
        fprintf('[ERROR] No valid subjects found for %s. Skipping...\n',current_con_name);
        continue;
    end
    
    % ####################### SPM Batch #######################     
    clear matlabbatch;
    matlabbatch{1}.spm.stats.factorial_design.dir = {con_folder};
    matlabbatch{1}.spm.stats.factorial_design.des.t1.scans = cons_list;
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
        fprintf('>>> 2nd-Level Design Matrix successfully created for %s (%d subjects included)\n',current_con_name,length(cons_list));
    catch ME
        fprintf('[CRITICAL ERROR] SPM failed for %s: %s\n',current_con_name,ME.message);
        continue;
    end
end

fprintf('\nFinished!\n')