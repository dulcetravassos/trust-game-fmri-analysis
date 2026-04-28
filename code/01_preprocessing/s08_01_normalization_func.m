%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%                                                                        %
%   Normalization - Functional images (BIDS ready)                       %
%                                                                        %
%   Applies the Forward Deformation Field (y_*) generated during the     %
%   anatomical segmentation step to the functional images (ura*),        %
%   warping the functional data into standard MNI space. Outputs are    %
%   saved with a 'w' prefix (wura*) and JSON sidecars are created        %
%   accordingly.                                                         %
%                                                                        %
%   Author: Dulce Travassos                                              %
%   Created: 02/03/2026                                                  %
%   Last update: 28/04/2026                                              %
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

% Volumes - Localizer Task
vol_localizer = 190;

% Volumes - Main Task
volumes_main = [
    206, 250, 246, 206, 224, 223, 222, 223; % sub-002
    226, 223, 222, 223, 223, 223, 223, 223; % sub-003
    223, 223, 223, 223, 223, 223, 223, 223; % sub-004
    223, 223, 223, 223, 223, 223, 223, 223; % sub-006
    223, 223, 223, 223, 223, 223, 223, 223; % sub-007
    223, 223, 223, 223, 223, 223, 223, 223; % sub-008
    223, 223, 223, 223, 223, 223, 223, 223; % sub-009
    223, 223, 223, 223, 223, 223, 223, 223; % sub-011
    223, 223, 223, 223, 223, 223, 223, 223; % sub-012
    223, 223, 223, 223, 223, 223, 223, 223; % sub-013
    223, 223, 223, 223, 223, 223, 223, 223; % sub-014
    223, 223, 223, 223, 223, 223, 223, 223; % sub-015
    223, 223, 223, 223, 223, 223, 223, 223; % sub-016
    223, 223, 223, 223, 223, 223, 223, 223; % sub-017
    223, 223, 223, 223, 223, 223, 223, 223; % sub-018
    223, 223, 223, 223, 223, 223, 223, 223; % sub-019
    223, 223, 223, 223, 223, 223, 223, 223; % sub-020
    223, 223, 223, 223, 223, 223, 223, 223; % sub-021
    223, 223, 223, 223, 223, 223, 223, 223; % sub-022
    223, 223, 223, 223, 223, 223, 223, 223; % sub-023
];

% Functional Image Voxel Size
mni_voxel_size = [2.5 2.5 3];

%% Normalization - Functional images

% Initialize SPM
if isempty(which('spm')); addpath(spm_path); end
spm('defaults', 'FMRI');
spm_jobman('initcfg');

for s = 1:length(subjects)
    subj = subjects{s};
    fprintf('\n==================================================\n');
    fprintf('Normalization for: %s\n', subj);

    anat_dir = fullfile(deriv_dir,subj,'anat');
    func_dir = fullfile(deriv_dir,subj,'func');

    % Find the Deformation Field (y_*)
    def_pattern = sprintf('y_%s_T1w.nii',subj);
    def_struct = dir(fullfile(anat_dir,def_pattern));
    if isempty(def_struct)
        fprintf('[ERROR] Missing Deformation Field for %s. Skipping.\n',subj);
        continue;
    end
    def_file = fullfile(anat_dir,def_struct(1).name);
       
    % Tasks
    tasks = {'task-main','task-localizer'};

    for t=1:length(tasks)
        current_task = tasks{t};

        % Get functional files (ura* files)
        file_pattern = sprintf('ura*%s*_bold.nii',current_task);
        run_struct = dir(fullfile(func_dir,file_pattern));
        [~,idx] = sort({run_struct.name});
        run_files = run_struct(idx);
        if isempty(run_files)
            fprintf('[WARNING] No functional files found for %s (%s). Skipping.\n',subj,current_task);
            continue;
        end
        
        % Volumes for SPM input
        func_vols = {};
        for r = 1:length(run_files)
            filename = run_files(r).name;
            
            if strcmp(current_task,'task-main')
                n_vols_target = volumes_main(s,r); % subject - line, run - column
            else
                n_vols_target = vol_localizer;
            end

            % Select volumes (from 1 to n_vols_target)
            bold_frames = spm_select('ExtFPList',func_dir,['^',filename,'$'],1:n_vols_target);
            if isempty(bold_frames)
                fprintf('[ERROR] Could not read frames for %s\n', filename);
                continue;
            end
            
            % Add frames to the final cell array ('cleaning' them)
            for v=1:size(bold_frames,1)
                func_vols{end+1,1} = strtrim(bold_frames(v,:)); % deletes extra blank spaces in the end of the cell
            end     
        end

        if isempty(func_vols) 
            fprintf('[ERROR] No valid volumes found for %s. Skipping.\n',current_task);
            continue; 
        end

        % ####################### SPM Batch #######################
        clear matlabbatch;
        matlabbatch{1}.spm.spatial.normalise.write.subj.def = {def_file};
        matlabbatch{1}.spm.spatial.normalise.write.subj.resample = func_vols;
        matlabbatch{1}.spm.spatial.normalise.write.woptions.bb = [-78 -112 -70
                                                                  78 76 85];
        matlabbatch{1}.spm.spatial.normalise.write.woptions.vox = mni_voxel_size;
        matlabbatch{1}.spm.spatial.normalise.write.woptions.interp = 4;
        matlabbatch{1}.spm.spatial.normalise.write.woptions.prefix = 'w';
        
        try
            spm_jobman('run', matlabbatch);
            fprintf('>>> Normalization completed for %s\n', subj);
            
            % Create JSONs for the new files
            for r=1:length(run_files)
                orig_func_name = run_files(r).name;
                new_func_name = ['w' orig_func_name];
                source_json = fullfile(func_dir,replace(orig_func_name,'.nii','.json'));
                target_json = fullfile(func_dir,replace(new_func_name,'.nii','.json'));
                create_norm_json(source_json,target_json);
            end

        catch ME
            fprintf('[CRITICAL ERROR] SPM failed for %s (%s): %s\n',subj,current_task,ME.message);
            continue;
        end
    end
end

fprintf('\nFinished!\n')

%% Helper Functions

function create_norm_json(source_json_path,target_json_path)

if exist(source_json_path,'file')
    content = fileread(source_json_path);
    json_data = jsondecode(content);
else
    json_data = struct(); % start new one
end

json_data.SpatialNormalization = true;
json_data.NormalizationTemplate = 'MNI 152';
json_data.NormalizationSoftware = 'SPM12';
json_data.Description = 'Warped to MNI space using Forward Deformation Field from the Segmentation';

% Save .json file
fid = fopen(target_json_path,'w');
if fid==-1; warning('Could not save JSON file.'); return; end
fprintf(fid,'%s',jsonencode(json_data,'PrettyPrint',true));
fclose(fid);
end