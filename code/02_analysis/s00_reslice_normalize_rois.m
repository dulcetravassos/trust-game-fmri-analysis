%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%                                                                        %
%   Reslice & Normalize ROIs to T1w space and dimensions                 %
%                                                                        %
%   Reslice FreeSurfer anatomical ROIs to T1w original space and         %
%   dimensions, and then normalize them to MNI space, using the Forward  %
%   Deformation Fields (y*).                                             %
%                                                                        %
%   Author: Dulce Travassos                                              %
%   Created: 16/06/2026                                                  %
%   Last update: 17/06/2026                                              %
%                                                                        %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

clear all; clc;

% Credits to Ricardo Martins, PhD, for guiding the development of this script (https://ricardomar.github.io/).

%% Initial Configurations
% Change according to your preferences
% Note that some parameters may have to be changed inside the main loop

% Main folder
main_dir = 'C:\Users\User\Desktop\Tese';

spm_path = fullfile(main_dir,'spm12');

% Input and output directories
base_dir = fullfile(main_dir,'data','spm-data');
deriv_dir = fullfile(base_dir,'derivatives','spm-preprocessing');
rois_dir = fullfile(base_dir,'derivatives','spm-rois');
fs_rois_dir = fullfile(rois_dir,'anatomical-rois_FreeSurfer');

% List of Subjects
subjects = {
    'sub-002', 'sub-003', 'sub-004', 'sub-006', 'sub-007', 'sub-008', ...
    'sub-009', 'sub-011', 'sub-012', 'sub-013', 'sub-014', 'sub-015', ...
    'sub-016', 'sub-017', 'sub-018', 'sub-019', 'sub-020', 'sub-021', ...
    'sub-022', 'sub-023'
};

% Anatomical Image Voxel Size for Normalization
mni_voxel_size = [1 1 1];

%% Reslicing & Normalization

% Initialize SPM
if isempty(which('spm')); addpath(spm_path); end
spm('defaults', 'FMRI');
spm_jobman('initcfg');

for s = 1:length(subjects)
    subj = subjects{s};
    fprintf('\n==================================================\n');
    fprintf('Processing ROIs for: %s\n', subj);

    anat_dir = fullfile(deriv_dir,subj,'anat');
    subj_out_dir = fullfile(rois_dir,subj);
    if ~exist(subj_out_dir,'dir'); mkdir(subj_out_dir); end;

    % Find reference (T1w) and Deformation Field (y*)
    ref_pattern = sprintf('%s_T1w.nii',subj); 
    ref_struct = dir(fullfile(anat_dir,ref_pattern));
    def_pattern = sprintf('y_%s_T1w.nii',subj); 
    def_struct = dir(fullfile(anat_dir,def_pattern));
    if isempty(ref_struct) || isempty (def_struct)
        fprintf('[WARNING] Missing T1w or y_* field for %s. Skipping...\n', subj);
        continue;
    end
    ref_img = fullfile(anat_dir,ref_struct(1).name);
    def_fields = fullfile(anat_dir,def_struct(1).name);

    % Find subject's ROIs ('sub-00x_*.nii' format-like)
    roi_pattern = sprintf('%s_*.nii',subj); 
    roi_files = dir(fullfile(fs_rois_dir,roi_pattern));
    if isempty(roi_files)
        fprintf('[WARNING] No ROIs found for %s. Skipping.\n',subj);
        continue;
    elseif length(roi_files) < 6
        fprintf('[WARNING] Only %d ROIs found for %s!\n',length(roi_files),subj);
    end

    source_rois = {};
    resliced_rois = {};

    for i=1:length(roi_files)
        if startsWith(roi_files(i).name,'r') || startsWith(roi_files(i).name,'w'); continue; end; % skip already resliced or normalized files
    
        % Save the paths of the initial ROIs and the post-reslicing ROIs
        source_rois{end+1,1} = fullfile(fs_rois_dir,roi_files(i).name);
        resliced_rois{end+1,1} = fullfile(fs_rois_dir,['r',roi_files(i).name]);
    end

    if isempty(resliced_rois); continue; end;

    % --------------------------- Reslicing ---------------------------
    
    % ####################### SPM Batch #######################
    clear matlabbatch;
    matlabbatch{1}.spm.spatial.coreg.write.ref = {ref_img};
    matlabbatch{1}.spm.spatial.coreg.write.source = source_rois;
    matlabbatch{1}.spm.spatial.coreg.write.roptions.interp = 0; % Nearest Neighbour
    matlabbatch{1}.spm.spatial.coreg.write.roptions.wrap = [0 0 0]; % no wrapping
    matlabbatch{1}.spm.spatial.coreg.write.roptions.mask = 0; % don't mask the output
    matlabbatch{1}.spm.spatial.coreg.write.roptions.prefix = 'r'; % default prefix
    
    try
        spm_jobman('run', matlabbatch);
    catch ME
        fprintf('[CRITICAL ERROR] SPM failed for %s: %s\n',subj,ME.message);
        continue;
    end      

    % --------------------------- Normalization ---------------------------
    fprintf('>>> Normalizing Resliced ROIs to MNI space...\n');

    % ####################### SPM Batch #######################
    clear matlabbatch;
    matlabbatch{1}.spm.spatial.normalise.write.subj.def = {def_fields};
    matlabbatch{1}.spm.spatial.normalise.write.subj.resample = resliced_rois;
    matlabbatch{1}.spm.spatial.normalise.write.woptions.bb = [-78 -112 -70
                                                              78 76 85];
    matlabbatch{1}.spm.spatial.normalise.write.woptions.vox = mni_voxel_size;
    matlabbatch{1}.spm.spatial.normalise.write.woptions.interp = 0; %kNN
    matlabbatch{1}.spm.spatial.normalise.write.woptions.prefix = 'w';
    
    try
        spm_jobman('run', matlabbatch);
    catch ME
        fprintf('[CRITICAL ERROR] SPM failed for %s: %s\n',subj,ME.message);
        continue;
    end

    % Move final outputs to the subject's ROI folder
    for i=1:length(resliced_rois)
        [~,name,ext] = fileparts(resliced_rois{i});

        final_roi_path = fullfile(fs_rois_dir,['w',name,ext]);

        if exist(final_roi_path,'file')
            clean_name = name(2:end); % removes the prefixes
            destination = fullfile(subj_out_dir,[clean_name,ext]);
            movefile(final_roi_path,destination);
            delete(resliced_rois{i}); % delete the intermediate 'r' file
        end
    end

    fprintf('>>> Successfully processed and saved ROIs for %s!\n',subj);
end

fprintf('\nFinished!\n')