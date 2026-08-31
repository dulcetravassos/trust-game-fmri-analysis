%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%                                                                        %
%   Design Matrix (Specify 1st-level + Explicit Masking)  (BIDS ready)   %
%                                                                        %
%   This script performs two main steps for the first-level analysis:    %
%   first, creates a subject-specific explicit brain mask using SPM's    %
%   ImCalc, by summing normalized tissue probability maps (wc1*, wc2*,   %
%   wc3*) thresholded at >0.2 to exclude ghost voxels and out-of-brain   %
%   artifacts, plus generating a corresponding JSON sidecar; and second, %
%   builds the Design Matrix for each task, handling multiple            %
%   sessions/runs, variable volumes, BIDS-compliant event files (.mat),  %
%   and motion regressors.                                               %
%                                                                        %
%   Author: Dulce Travassos                                              %
%   Created: 09/03/2026                                                  %
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
deriv_dir = fullfile(base_dir,'derivatives','spm-preprocessing');
protocols_dir = fullfile(base_dir,'derivatives','spm-events');

% List of Subjects
subjects = {
    'sub-819', 'sub-908', 'sub-147', 'sub-915', 'sub-641', 'sub-119', ...
    'sub-295', 'sub-557', 'sub-958', 'sub-965', 'sub-177', 'sub-971', ...
    'sub-664', 'sub-497', 'sub-805', 'sub-162', 'sub-435', 'sub-917', ...
    'sub-797', 'sub-960'
};

% Tasks
tasks = {'task-main', 'task-localizer'};

% Volumes - Localizer Task
vol_localizer = 190;

% Volumes - Main Task
volumes_main = [
    206, 250, 246, 206, 224, 223, 222, 223; % sub-819
    226, 223, 222, 223, 223, 223, 223, 223; % sub-908
    223, 223, 223, 223, 223, 223, 223, 223; % sub-147
    223, 223, 223, 223, 223, 223, 223, 223; % sub-915
    223, 223, 223, 223, 223, 223, 223, 223; % sub-641
    223, 223, 223, 223, 223, 223, 223, 223; % sub-119
    223, 223, 223, 223, 223, 223, 223, 223; % sub-295
    223, 223, 223, 223, 223, 223, 223, 223; % sub-557
    223, 223, 223, 223, 223, 223, 223, 223; % sub-958
    223, 223, 223, 223, 223, 223, 223, 223; % sub-965
    223, 223, 223, 223, 223, 223, 223, 223; % sub-177
    223, 223, 223, 223, 223, 223, 223, 223; % sub-971
    223, 223, 223, 223, 223, 223, 223, 223; % sub-664
    223, 223, 223, 223, 223, 223, 223, 223; % sub-497
    223, 223, 223, 223, 223, 223, 223, 223; % sub-805
    223, 223, 223, 223, 223, 223, 223, 223; % sub-162
    223, 223, 223, 223, 223, 223, 223, 223; % sub-435
    223, 223, 223, 223, 223, 223, 223, 223; % sub-917
    223, 223, 223, 223, 223, 223, 223, 223; % sub-797
    223, 223, 223, 223, 223, 223, 223, 223; % sub-960
];

% Acquisition Parameters
TR = 2; % secs

%% Specify 1st-Level

% Initialize SPM
if isempty(which('spm')); addpath(spm_path); end
spm('defaults', 'FMRI');
spm_jobman('initcfg');

for s = 1:length(subjects)
    subj = subjects{s};
    fprintf('\n==================================================\n');
    fprintf('Specify 1st-level for: %s\n', subj);

    func_dir = fullfile(deriv_dir,subj,'func');
    anat_dir = fullfile(deriv_dir,subj,'anat');

    % ---------------------- Create Explicit Brain Mask (ImCalc) ----------------------
    mask_name = sprintf('brainmask_%s.nii',subj);
    mask_path = fullfile(anat_dir,mask_name);
    
    wc1 = fullfile(anat_dir,sprintf('wc1%s_T1w.nii',subj));
    wc2 = fullfile(anat_dir,sprintf('wc2%s_T1w.nii',subj));
    wc3 = fullfile(anat_dir,sprintf('wc3%s_T1w.nii',subj));

    if exist(wc1,'file') && exist(wc2,'file') && exist(wc3,'file')
        % ####################### SPM Batch - ImCalc #######################         
        clear matlabbatch;
        matlabbatch{1}.spm.util.imcalc.input = {wc1; wc2; wc3};
        matlabbatch{1}.spm.util.imcalc.output = mask_name;
        matlabbatch{1}.spm.util.imcalc.outdir = {anat_dir};
        matlabbatch{1}.spm.util.imcalc.expression = '(i1+i2+i3)>0.2';
        matlabbatch{1}.spm.util.imcalc.var = struct('name', {}, 'value', {});
        matlabbatch{1}.spm.util.imcalc.options.dmtx = 0;
        matlabbatch{1}.spm.util.imcalc.options.mask = 0;
        matlabbatch{1}.spm.util.imcalc.options.interp = 1;
        matlabbatch{1}.spm.util.imcalc.options.dtype = 4;
    
        spm_jobman('run',matlabbatch);
        fprintf('>>> Brain mask created for %s\n',subj);

        % Generate JSON for the mask (BIDS compliance)
        mask_json_path = fullfile(anat_dir,replace(mask_name,'.nii','.json'));
        create_mask_json(mask_json_path);
    else
        fprintf('[WARNING] Tissue maps missing. Cannot create brain mask for %s.\n',subj);
    end

    % ---------------------- Specify 1st-Level (GLM) ----------------------
    for t=1:length(tasks)
        current_task = tasks{t};

        % Get functional files (swura* files)
        file_pattern = sprintf('swura*%s*_bold.nii',current_task);
        run_struct = dir(fullfile(func_dir,file_pattern));
        [~,idx] = sort({run_struct.name});
        run_files = run_struct(idx);
        if isempty(run_files)
            fprintf('[WARNING] No functional files found for %s (%s). Skipping.\n',subj,current_task);
            continue;
        end

        % Create output folder
        stats_dir = fullfile(deriv_dir,subj,'stats',current_task);
        if ~exist(stats_dir,'dir'); mkdir(stats_dir); end;

        % ####################### SPM Batch - Part 1 (Initiate Batch) #######################     
        clear matlabbatch;
        matlabbatch{1}.spm.stats.fmri_spec.dir = {stats_dir};
        matlabbatch{1}.spm.stats.fmri_spec.timing.units = 'secs';
        matlabbatch{1}.spm.stats.fmri_spec.timing.RT = TR;
        matlabbatch{1}.spm.stats.fmri_spec.timing.fmri_t = 16;
        matlabbatch{1}.spm.stats.fmri_spec.timing.fmri_t0 = 8;
        
        % Create sessions
        valid_runs=0;
        for r = 1:length(run_files)
            filename = run_files(r).name;
            
            if strcmp(current_task,'task-localizer')
                actual_run = 1; % force 1
                n_vols_target = vol_localizer;
            else
                tokens = regexp(filename,'run-(\d+)','tokens');
                if isempty(tokens)
                    fprintf('[WARNING] Cannot extract number of run from %s\n',filename);
                    continue;
                end
                actual_run = str2double(tokens{1}{1});
                n_vols_target = volumes_main(s,actual_run);
            end

            % For the current run, find the corresponding swura* volumes
            bold_frames = cellstr(spm_select('ExtFPList',func_dir,['^',filename,'$'],1:n_vols_target));
            if isempty(bold_frames); continue; end;

            % Find the corresponding .mat onsets file
            if strcmp(current_task,'task-main')  
                event_pattern = sprintf('*%s*run-%02d*_events.mat',current_task,actual_run); % sub-00x_ses-01_task-trustgame_run-0y_events.mat
            else
                event_pattern = sprintf('*%s*_events.mat',current_task); % sub-00x_task-localizer_run-01_events
            end  
            event_file = dir(fullfile(protocols_dir,subj,'func',event_pattern));
            if isempty(event_file)
                fprintf('[WARNING] Onsets .mat file not found for %s run-%02d. Skipping run...\n',subj,actual_run);
                continue;
            end
            multi_cond_path = fullfile(event_file(1).folder,event_file(1).name);

            % Find the corresponding rp_*.txt movement file
            if strcmp(current_task,'task-main')
                rp_pattern = sprintf('rp_*%s*run-%02d*.txt',current_task,actual_run);
            else
                rp_pattern = sprintf('rp_*%s*.txt',current_task);
            end
            rp_file = dir(fullfile(func_dir,rp_pattern));
            if isempty(rp_file)
                error('Movement file not found for %s run %d!',subj,actual_run);
            end
            motion_path = fullfile(rp_file(1).folder,rp_file(1).name);
            
            valid_runs = valid_runs+1;

            % ####################### SPM Batch - Part 2 (Run-specific parameters) #######################     
            matlabbatch{1}.spm.stats.fmri_spec.sess(valid_runs).scans = bold_frames;
            matlabbatch{1}.spm.stats.fmri_spec.sess(valid_runs).cond = struct('name', {}, 'onset', {}, 'duration', {}, 'tmod', {}, 'pmod', {}, 'orth', {});
            matlabbatch{1}.spm.stats.fmri_spec.sess(valid_runs).multi = {multi_cond_path}; % .mat file
            matlabbatch{1}.spm.stats.fmri_spec.sess(valid_runs).regress = struct('name', {}, 'val', {});
            matlabbatch{1}.spm.stats.fmri_spec.sess(valid_runs).multi_reg = {motion_path}; % movement parameters (rp*)
            matlabbatch{1}.spm.stats.fmri_spec.sess(valid_runs).hpf = 128;
        end

        if valid_runs==0
            fprintf('[ERROR] No valid runs for %s. Skipping...\n', current_task);
            continue;
        end
                
        % ####################### SPM Batch - Part 3 (Global parameters + Mask) #######################
        matlabbatch{1}.spm.stats.fmri_spec.fact = struct('name', {}, 'levels', {});
        matlabbatch{1}.spm.stats.fmri_spec.bases.hrf.derivs = [0 0];
        matlabbatch{1}.spm.stats.fmri_spec.volt = 1;
        matlabbatch{1}.spm.stats.fmri_spec.global = 'None';
        matlabbatch{1}.spm.stats.fmri_spec.mthresh = 0.8; % implicit masking
        if exist(mask_path,'file') % explicit masking - GM + WM + CSF
            matlabbatch{1}.spm.stats.fmri_spec.mask = {mask_path};
        else
            fprintf('[WARNING] Anatomical T1w mask not found for %s. Using implicit masking only...\n',subj);
            matlabbatch{1}.spm.stats.fmri_spec.mask = {''};
        end
        matlabbatch{1}.spm.stats.fmri_spec.cvi = 'AR(1)';
        
        try
            spm_jobman('run', matlabbatch);
            fprintf('>>> Design Matrix successfully created for %s (%s)\n',subj,current_task);
        catch ME
            fprintf('[CRITICAL ERROR] SPM failed for %s (%s): %s\n',subj,current_task,ME.message);
            continue;
        end
    end
end

fprintf('\nFinished!\n')

%% Helper Functions

function create_mask_json(target_json_path)

json_data = struct();
json_data.SpatialMask = true;
json_data.Description = 'Binary brain mask created by summing GM, WM, and CSF probability maps (thresholded at >0.2)';
json_data.Software = 'SPM12';

% Save .json file
fid = fopen(target_json_path,'w');
if fid==-1; warning('Could not save JSON file.'); return; end
fprintf(fid,'%s',jsonencode(json_data,'PrettyPrint',true));
fclose(fid);
end