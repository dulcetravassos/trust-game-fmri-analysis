%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%                                                                        %
%   Normalization - Anatomical images (BIDS ready)                       %
%                                                                        %
%   Applies the Forward Deformation Field (y_*) generated during the     %
%   anatomical segmentation step to both the bias-corrected anatomical   %
%   image (m*) and the Tissue Probability Maps (c1, c2, c3), warping it  %
%   into standard MNI space. Outputs are saved with a 'w' prefix (wm*,   %
%   wc1*, wc2*, wc3*) and JSON sidecars are created accordingly.         %
%                                                                        %
%   Author: Dulce Travassos                                              %
%   Created: 02/03/2026                                                  %
%   Last update: 09/03/2026                                              %
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

% Anatomical Image Voxel Size
mni_voxel_size = [1 1 1];

%% Normalization - Anatomical images

% Initialize SPM
if isempty(which('spm')); addpath(spm_path); end
spm('defaults', 'FMRI');
spm_jobman('initcfg');

for s = 1:length(subjects)
    subj = subjects{s};
    fprintf('\n==================================================\n');
    fprintf('Normalization for: %s\n', subj);

    anat_dir = fullfile(deriv_dir,subj,'anat');

    % Find the Deformation Field (y_*)
    def_pattern = sprintf('y_%s_desc-defaced_T1w.nii',subj);
    def_struct = dir(fullfile(anat_dir,def_pattern));
    if isempty(def_struct)
        fprintf('[ERROR] Missing Deformation Field for %s. Skipping.\n',subj);
        continue;
    end
    def_file = fullfile(anat_dir,def_struct(1).name);
       
    % List of files to resample (m*, c1, c2, c3)
    resample_files = {};

    % Get bias-corrected anatomical file (m*)
    anat_pattern = sprintf('m*%s_desc-defaced_T1w.nii',subj);
    anat_struct = dir(fullfile(anat_dir,anat_pattern));
    if isempty(anat_struct)
        fprintf('[WARNING] No anatomical file found for %s. Skipping.\n',subj);
        continue;
    end
    anat_file = fullfile(anat_dir,anat_struct(1).name);
    resample_files{end+1,1} = anat_file;

    % Get Tissue Probability Maps (c1, c2, c3)
    prefixes = {'c1','c2','c3'};
    for p = 1:length(prefixes)
        c_pattern = sprintf('%s%s_desc-defaced_T1w.nii',prefixes{p},subj);
        c_struct = dir(fullfile(anat_dir,c_pattern));
        if ~isempty(c_struct)
            resample_files{end+1,1} = fullfile(anat_dir,c_struct(1).name);
        else
            fprintf('[WARNING] Tissue map %s not found for %s.\n',prefixes{p},subj);
        end
    end

    if isempty(resample_files)
        fprintf('[ERROR] No images to resample for %s. Skipping...\n',subj);
        continue;
    end


    % ####################### SPM Batch #######################
    clear matlabbatch;
    matlabbatch{1}.spm.spatial.normalise.write.subj.def = {def_file};
    matlabbatch{1}.spm.spatial.normalise.write.subj.resample = resample_files;
    matlabbatch{1}.spm.spatial.normalise.write.woptions.bb = [-78 -112 -70
                                                              78 76 85];
    matlabbatch{1}.spm.spatial.normalise.write.woptions.vox = mni_voxel_size;
    matlabbatch{1}.spm.spatial.normalise.write.woptions.interp = 4;
    matlabbatch{1}.spm.spatial.normalise.write.woptions.prefix = 'w';
    
    try
        spm_jobman('run', matlabbatch);
        fprintf('>>> Normalization completed for %s\n', subj);
        
        % Create JSONs for the new files
        for i = 1:length(resample_files)
            [~,fname,ext] = fileparts(resample_files{i});
            orig_name = [fname ext];
            new_name = ['w' orig_name];
            source_json = fullfile(anat_dir,replace(orig_name,'.nii','.json'));
            target_json = fullfile(anat_dir,replace(new_name,'.nii','.json'));
            create_norm_json(source_json,target_json);
        end
    catch ME
        fprintf('[CRITICAL ERROR] SPM failed for %s: %s\n',subj,ME.message);
        continue;
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