%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%                                                                        %
%   Motion Correction - Realignment (Est & Res)(BIDS ready)              %
%                                                                        %
%   Corrects for head movement. Inputs are 'a...' files (Slice Timed).   %
%   Outputs are 'ra...' files, plus 'mean...' and 'rp_... .txt'. Also    %
%   saves an updated JSON file for all NIfTI outputs and creates a JSON  % 
%   file for the 'rp_*.txt'. This script is adapted to deal with         %
%   variable volumes.                                                    %
%                                                                        %
%   Author: Dulce Travassos                                              %
%   Created: 13/02/2026                                                  %
%   Last update: 13/02/2026                                              %
%                                                                        %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

clear all; clc;

%% Initial Configurations
% Change according to your preferences
% Note that some parameters may have to be changed inside the main loop

spm_path = 'C:\Users\User\Desktop\Tese\spm12';

% Input and output directories
base_dir = 'C:\Users\User\Desktop\Tese\data\spm-data';
deriv_dir = fullfile(base_dir,'derivatives','spm-preprocessing');

% List of Subjects
subjects = {
    'sub-002', 
    % 'sub-003', 'sub-004', 'sub-006', 'sub-007', 'sub-008', ...
    % 'sub-009', 'sub-011', 'sub-012', 'sub-013', 'sub-014', 'sub-015', ...
    % 'sub-016', 'sub-017', 'sub-018', 'sub-019', 'sub-020', 'sub-021', ...
    % 'sub-022', 'sub-023'
};

% Volumes - Localizer Task
vol_localizer = 190;

% Volumes - Main Task
volumes_main = [
    206, 250, 246, 206, 224, 223, 222, 223; % sub-002
    % 226, 223, 222, 223, 223, 223, 223, 223; % sub-003
    % 223, 223, 223, 223, 223, 223, 223, 223; % sub-004
    % 223, 223, 223, 223, 223, 223, 223, 223; % sub-006
    % 223, 223, 223, 223, 223, 223, 223, 223; % sub-007
    % 223, 223, 223, 223, 223, 223, 223, 223; % sub-008
    % 223, 223, 223, 223, 223, 223, 223, 223; % sub-009
    % 223, 223, 223, 223, 223, 223, 223, 223; % sub-011
    % 223, 223, 223, 223, 223, 223, 223, 223; % sub-012
    % 223, 223, 223, 223, 223, 223, 223, 223; % sub-013
    % 223, 223, 223, 223, 223, 223, 223, 223; % sub-014
    % 223, 223, 223, 223, 223, 223, 223, 223; % sub-015
    % 223, 223, 223, 223, 223, 223, 223, 223; % sub-016
    % 223, 223, 223, 223, 223, 223, 223, 223; % sub-017
    % 223, 223, 223, 223, 223, 223, 223, 223; % sub-018
    % 223, 223, 223, 223, 223, 223, 223, 223; % sub-019
    % 223, 223, 223, 223, 223, 223, 223, 223; % sub-020
    % 223, 223, 223, 223, 223, 223, 223, 223; % sub-021
    % 223, 223, 223, 223, 223, 223, 223, 223; % sub-022
    % 223, 223, 223, 223, 223, 223, 223, 223; % sub-023
];

%% Realignment/Motion Correction

% Initialize SPM
if isempty(which('spm')); addpath(spm_path); end
spm('defaults', 'FMRI');
spm_jobman('initcfg');

if size(volumes_main,1) ~= length(subjects)
    error('ERROR: volumes_main has %d lines, but there are %d subjects!',size(volumes_main,1),length(subjects));
end

for s = 1:length(subjects)
    subj = subjects{s};
    fprintf('\n==================================================\n');
    fprintf('Processing Motion Correction for: %s\n', subj);
    
    subj_func_dir = fullfile(deriv_dir,subj,'func');
    if ~exist(subj_func_dir,'dir') 
       fprintf('[WARNING] Folder not found: %s\n',subj_func_dir); 
       continue;
    end
    
    tasks = {'task-main','task-localizer'};

    for t=1:length(tasks)
        current_task = tasks{t};

        % Get functional files ('asub-002_task-main_run-01_bold.nii' format-like)
        file_pattern = sprintf('a%s_%s*_bold.nii',subj,current_task);
        run_struct = dir(fullfile(subj_func_dir,file_pattern));
        [~,idx] = sort({run_struct.name});
        run_files = run_struct(idx);
        if isempty(run_files)
            fprintf('[WARNING] No functional files found for %s. Skipping.\n', subj);
            continue;
        end
        
        fprintf('######## Analyzing %s (%d files)... ########\n',current_task,length(run_files));
    
        all_sessions = {};
        files_for_json = {};
    
        for r = 1:length(run_files)
            filename = run_files(r).name;
            
            if strcmp(current_task,'task-main')
                n_vols_target = volumes_main(s,r); % subject - line, run - column
            else
                n_vols_target = vol_localizer;
            end

            % Select volumes (from 1 to n_vols_target)
            bold_frames = spm_select('ExtFPList',subj_func_dir,['^',filename,'$'],1:n_vols_target);
            if isempty(bold_frames)
                fprintf('[ERROR] Could not read frames for %s\n', filename);
                continue;
            end

            all_sessions{end+1} = cellstr(bold_frames);
            files_for_json{end+1} = filename;      
        end

        if isempty(all_sessions); continue; end;
        
        % ####################### SPM Batch #######################
        clear matlabbatch;
        % --------------- List of open inputs ---------------
        % Data
        matlabbatch{1}.spm.spatial.realign.estwrite.data = all_sessions;
        % Estimated Options
        matlabbatch{1}.spm.spatial.realign.estwrite.eoptions.quality = 0.9;
        matlabbatch{1}.spm.spatial.realign.estwrite.eoptions.sep = 4;
        matlabbatch{1}.spm.spatial.realign.estwrite.eoptions.fwhm = 5;
        matlabbatch{1}.spm.spatial.realign.estwrite.eoptions.rtm = 0; % rtm=1 -> Register to mean; rtm=0 -> Register to first
        matlabbatch{1}.spm.spatial.realign.estwrite.eoptions.interp = 2;
        matlabbatch{1}.spm.spatial.realign.estwrite.eoptions.wrap = [0 0 0];
        matlabbatch{1}.spm.spatial.realign.estwrite.eoptions.weight = '';
        % Reslice Options
        matlabbatch{1}.spm.spatial.realign.estwrite.roptions.which = [2 1]; % All images + Mean image
        matlabbatch{1}.spm.spatial.realign.estwrite.roptions.interp = 4;
        matlabbatch{1}.spm.spatial.realign.estwrite.roptions.wrap = [0 0 0];
        matlabbatch{1}.spm.spatial.realign.estwrite.roptions.mask = 1;
        matlabbatch{1}.spm.spatial.realign.estwrite.roptions.prefix = 'r';
        
        try
            spm_jobman('run', matlabbatch);
            fprintf('>>> Realignment completed for %s\n', subj);
        catch ME
            fprintf('[CRITICAL ERROR] SPM failed for %s: %s\n', subj, ME.message);
            continue;
        end
        
        % To comply with BIDS, we need to create a JSON file for this operation
        for k = 1:length(files_for_json)
            orig_name = files_for_json{k};
            out_name = ['r' orig_name];
            src = fullfile(subj_func_dir,orig_name);
            dest = fullfile(subj_func_dir,out_name);
    
            if exist(dest,'file') 
                init_json_path = replace(src,'.nii','.json');
                out_json_path = replace(dest,'.nii','.json');  
                create_derivative_json(init_json_path, out_json_path);
            else
                fprintf('[WARNING] Could not find generated file: %s\n',out_name);
            end

        end

        % SPM creates a mean image, that also needs a JSON!
        if ~isempty(files_for_json)
            mean_name = ['mean' files_for_json{1}];
            mean_dest = fullfile(subj_func_dir,mean_name);
            if exist(mean_dest,'file')
                init_json_path = fullfile(subj_func_dir,replace(files_for_json{1},'.nii','.json')); % using the first func file JSON as template
                out_json_path = replace(mean_dest,'.nii','.json');
                create_derivative_json(init_json_path,out_json_path,'MeanImage');
            end
        end

        % SPM creates a file 'rp_*.txt', that also needs a JSON...
        for k = 1:length(files_for_json)
            rp_name = ['rp_' replace(files_for_json{k},'.nii','.txt')];
            rp_dest = fullfile(subj_func_dir,rp_name);
            if exist(rp_dest,'file')
                out_json_path = replace(rp_dest,'.txt','.json');
                create_rp_json(out_json_path);
            end
        end

        fprintf('  > Done for %s!\n', subj);
    end
end

fprintf('\nFinished!\n')

%% Helper Functions

function create_derivative_json(source_json_path,target_json_path,type)

if nargin<3; type = 'Functional'; end; % if missing type

if exist(source_json_path,'file')
    content = fileread(source_json_path);
    try
        json_data = jsondecode(content);
    catch
        json_data = struct();
    end
else
    json_data = struct(); % start new one
end

json_data.MotionCorrection = true;
json_data.MotionCorrectionSoftware = 'SPM12';
json_data.Sources = {source_json_path};

if strcmp(type,'MeanImage')
    json_data.Description = 'Mean EPI image generated by SPM Realignment';
end

% Save .json file
fid = fopen(target_json_path,'w');
if fid==-1; warning('Could not save JSON file.'); return; end
fprintf(fid,'%s',jsonencode(json_data,'PrettyPrint',true));
fclose(fid);
end


function create_rp_json(target_json_path)
json_data = struct();
json_data.Description = 'SPM Motion Estimation Parameters';
json_data.Columns = {'x','y','z','pitch','roll','yaw'};
json_data.Units = {'mm','mm','mm','rad','rad','rad'};
json_data.MotionCorrectionSoftware = 'SPM12';

% Save .json file
fid = fopen(target_json_path,'w');
if fid==-1; warning('Could not save RP JSON.'); return; end
fprintf(fid,'%s',jsonencode(json_data,'PrettyPrint',true));
fclose(fid);
end