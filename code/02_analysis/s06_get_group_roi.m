%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%                                                                        %
%   Group ROI Calculation & Hemispheric Separation                       %
%                                                                        %
%   This script processes subject-specific bilateral ROI masks (.nii)    %
%   (e.g., "*_caudateRL.nii") for group-level Small Volume Correction.   %
%   First, it splits the bilateral masks into Left (x<0) and Right (x>0) %
%   hemispheric masks for each subject, skipping predefined corrupted or %
%   missing data. Then, it computes a group ROI for each hemisphere and  %
%   region, by summing all valid masks and applying a proportional       %
%   overlap threshold (>= 50% of the actual valid N subjects must share  %
%   the voxel for it to be included in the group ROI).                   %
%                                                                        %
%   Author: Dulce Travassos                                              %
%   Created: 20/07/2026                                                  %
%   Last update: 24/07/2026                                              %
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
rois_dir = fullfile(deriv_dir,'spm-rois');

% List of Subjects
subjects = {
    'sub-002', 'sub-003', 'sub-004', 'sub-006', 'sub-007', 'sub-008', ...
    'sub-009', 'sub-011', 'sub-012', 'sub-013', 'sub-014', 'sub-015', ...
    'sub-016', 'sub-017', 'sub-018', 'sub-019', 'sub-020', 'sub-021', ...
    'sub-022', 'sub-023'
};

% List of bilateral anatomical ROIs
rois = {'amygdala', 'caudate', 'NAcc'%, 'OFC'
    };

% Threshold: proportion of subjects that must share a voxel
threshold = 0.5;

%% Calculate Average ROIs

% Initialize SPM
if isempty(which('spm')); addpath(spm_path); end
spm('defaults', 'FMRI');
spm_jobman('initcfg');

group_dir = fullfile(rois_dir,'group');
if ~exist(group_dir,'dir'); mkdir(group_dir); end;

for r = 1:length(rois)
    
    current_roi = rois{r};
    fprintf('>>> Processing ROI: %s\n',upper(current_roi));

    % Arrays to store the images to average
    right_files = {}; left_files = {};

    for s = 1:length(subjects)
        subj = subjects{s};
        subj_roi_dir = fullfile(rois_dir,subj);

        % skip corrupted ROIs in specific subjects
        if strcmp(current_roi,'amygdala') && ismember(subj,{'sub-013','sub-018'})
            fprintf('[INFO] Skipping %s for %s (corrupted or missing data).\n',current_roi,subj);
            continue;
        end

        fprintf('>>> Splitting R/L masks for %s...\n',subj);

        bilateral_file = fullfile(subj_roi_dir,sprintf('%s_%sRL.nii',subj,current_roi));
        if ~exist(bilateral_file,'file')
            warning('%sRL.nii not found for %s. Skipping...\n',current_roi,subj);
            continue;
        end
        
        left_name = sprintf('%sL.nii',current_roi); right_name = sprintf('%sR.nii',current_roi);

        try 
            V = spm_vol(bilateral_file);
            Y = spm_read_vols(V); % check https://github.com/spm/spm/blob/main/spm_read_vols.m

            [X,Yv,Z] = ndgrid(1:V.dim(1),1:V.dim(2),1:V.dim(3)); % creates a 3D grid of matrix indices (voxel coordinates)
            
            % The function above generates a grid with the exact number of voxels across all dimensions of 
            % volume V, but all indices are positive numbers. If we relied solely on raw matrix indices, we 
            % could never isolate the left  hemisphere, because there are no x<0 values. We need to map this 
            % grid into real-world MNI space where x=0 is the midline!
            
            XYZ = V.mat*[X(:)';Yv(:)';Z(:)';ones(1,numel(X))]; % converts voxel indices into MNI space, using the affine matrix (V.mat)
            mniX = reshape(XYZ(1,:),V.dim); % reshapes the flat MNI coordinates back to the original 3D volume dimensions

            % Hemisphere separation
            left = Y; right = Y;
            left(mniX>=0) = 0; right(mniX<=0) = 0;

            V_left = V; V_right = V;
            V_left.fname = fullfile(subj_roi_dir,left_name);
            V_right.fname = fullfile(subj_roi_dir,right_name);
            spm_write_vol(V_left,left); left_files{end+1,1} = sprintf('%s,1',V_left.fname);
            spm_write_vol(V_right,right); right_files{end+1,1} = sprintf('%s,1',V_right.fname);

            fprintf('>>> Left/Right Hemisphere Separation successfully completed for %s.\n',subj);
        catch ME
            fprintf('[CRITICAL ERROR] Hemisphere separation failure for %s: %s\n',subj,ME.message);
        end
    end

    actual_N = length(left_files);
    if actual_N==0
        warning('No valid subjects to create consensus for %s!\n',current_roi);
        continue;
    end

    % Dynamic threshold (e.g., 50% of 18 valid subjects = 9)
    min_subjects = ceil(actual_N*threshold);

    fprintf('Calculating group consensus (threshold >= %d subjects)...\n',min_subjects);
    
    % Instead of using the average ('mean(X)'), we dynamically write the ImCalc 
    % expression to allow the threshold application ('(i1+i2+...) >= 10')
    expr = 'i1';
    for i=2:length(left_files)
        expr = sprintf('%s + i%d',expr,i);
    end
    final_expr = sprintf('(%s) >= %d',expr,min_subjects);

    % ####################### SPM Batch - Group Left ROI #######################
    clear matlabbatch;
    matlabbatch{1}.spm.util.imcalc.input = left_files;
    matlabbatch{1}.spm.util.imcalc.output = sprintf('%sL_avg.nii',current_roi);
    matlabbatch{1}.spm.util.imcalc.outdir = {group_dir};
    matlabbatch{1}.spm.util.imcalc.expression = final_expr;
    matlabbatch{1}.spm.util.imcalc.var = struct('name', {}, 'value', {});
    matlabbatch{1}.spm.util.imcalc.options.dmtx = 0;
    matlabbatch{1}.spm.util.imcalc.options.mask = 0;
    matlabbatch{1}.spm.util.imcalc.options.interp = 0;
    matlabbatch{1}.spm.util.imcalc.options.dtype = 4; 
    try
        spm_jobman('run', matlabbatch);
        fprintf('>>> Group ROI %s successfully generated. Saved in: %s\n',sprintf('%sL_avg',current_roi),group_dir);
    catch ME
        fprintf('[CRITICAL ERROR] SPM ImCalc failed: %s\n',ME.message);
    end

    % ####################### SPM Batch - Group Right ROI #######################
    clear matlabbatch;
    matlabbatch{1}.spm.util.imcalc.input = right_files;
    matlabbatch{1}.spm.util.imcalc.output = sprintf('%sR_avg.nii',current_roi);
    matlabbatch{1}.spm.util.imcalc.outdir = {group_dir};
    matlabbatch{1}.spm.util.imcalc.expression = final_expr;
    matlabbatch{1}.spm.util.imcalc.var = struct('name', {}, 'value', {});
    matlabbatch{1}.spm.util.imcalc.options.dmtx = 0;
    matlabbatch{1}.spm.util.imcalc.options.mask = 0;
    matlabbatch{1}.spm.util.imcalc.options.interp = 0;
    matlabbatch{1}.spm.util.imcalc.options.dtype = 4; 
    try
        spm_jobman('run', matlabbatch);
        fprintf('>>> Group ROI %s successfully generated. Saved in: %s\n',sprintf('%sR_avg',current_roi),group_dir);
    catch ME
        fprintf('[CRITICAL ERROR] SPM ImCalc failed: %s\n',ME.message);
    end
end

fprintf('\nFinished!\n')