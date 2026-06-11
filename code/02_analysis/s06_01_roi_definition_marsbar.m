%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%                                                                        %
%   ROI Definition (MarsBaR toolbox) & Group Average Anatomical Image    %
%                                                                        %
%   This script documents the manual steps taken to define spherical     %
%   ROIs centered on pre-selected peak voxel coordinates, using the      %
%   MarsBaR SPM toolbox. It also calculates a group average anatomical   %
%   image to guide the ROI definition.                                   %
%                                                                        %
%   Author: Dulce Travassos                                              %
%   Created: 30/05/2026                                                  %
%   Last update: 11/06/2026                                              %
%                                                                        %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Credits to Andy's Brain Book: https://andysbrainbook.readthedocs.io/en/latest/SPM/SPM_Short_Course/SPM_09_ROIAnalysis.html

%% ROI Definition

% Create the /derivatives/spm-rois/ folder with the sub-00x folders inside

% Create the sphere (.mat file)
% 1. Click on ROI definition -> Build...
% 2. Type of ROI -> Sphere
% 3. Enter the coordinates (in our case, pre-selected peak voxel coordinates manually chosen - check the next section)
% 4. Radius of 10 (default)
% 5. Choose a name for the ROI (e.g., 'r-pSTS_roi', 'rFFA_avg_roi', etc)
% 6. Save the .mat file on the corresponding folder (/derivatives/spm-rois/sub-00x/)

% Generate ROI as a NIfTI (.nii file)
% 1. Click on ROI definition -> Export...
% 2. Select 'image' and choose the .mat ROI to convert
% 3. Space for ROI image: Base space for ROIs (default)
% 4. Select the output folder (in our case, the same as the .mat)

%% Coordinates chosen for the ROI center

% To define the final ROIs, a standardized peak selection procedure was consistently applied across all subjects.
% When available, a subject-specific ROI was defined. For subjects lacking a functionally identifiable peak for a 
% given region, we used  the mean coordinates of that ROI across the participants showing activations.
% You can find more information on this process on this study's manuscript.

%% How to choose the appropriate radius for the spherical ROI?

% While standard literature usually recommends a sphere radius between 4-10mm, excessively large spheres risk 
% capturing signals from adjacent and functionally distinct areas, losing spatial specificity.
%
% To accurately determine the optimal radius and verify the anatomical boundaries of the desired region, it is a 
% good practice to overlay the spheres on a group average anatomical image rather than a single subject scan (which 
% introduces individual morphological bias and does not account for inter-subject variability).

% The following script computes and saves the group average T1w structural image to guide the final radius 
% selection:

%% Initial Configurations
% Change according to your preferences
% Note that some parameters may have to be changed inside the main loop

% Main folder
main_dir = 'C:\Users\User\Desktop\Tese';

spm_path = fullfile(main_dir,'spm12');

% Input and output directories
base_dir = fullfile(main_dir,'data','spm-data');
deriv_dir = fullfile(base_dir,'derivatives');
roi_dir = fullfile(deriv_dir,'spm-rois');

% List of Subjects
subjects = {
    'sub-002', 'sub-003', 'sub-004', 'sub-006', 'sub-007', 'sub-008', ...
    'sub-009', 'sub-011', 'sub-012', 'sub-013', 'sub-014', 'sub-015', ...
    'sub-016', 'sub-017', 'sub-018', 'sub-019', 'sub-020', 'sub-021', ...
    'sub-022', 'sub-023'
};

%% Average Anatomical Image Calculation

% Initialize SPM
if isempty(which('spm')); addpath(spm_path); end
spm('defaults', 'FMRI');
spm_jobman('initcfg');

group_dir = fullfile(roi_dir,'group');
if ~exist(group_dir,'dir'); mkdir(group_dir); end;

% List of anat images to average
average_files = {};

source_json = '';
for s = 1:length(subjects)
    subj = subjects{s};
    anat_dir = fullfile(deriv_dir,'spm-preprocessing',subj,'anat');
    
    % Get wm* anat image - normalized (w) & bias corrected (m) (and also coregistered, but with "estimate-only", therefore missing the 'r' prefix)
    anat_pattern = sprintf('wm*%s_T1w.nii',subj);
    anat_struct = dir(fullfile(anat_dir,anat_pattern));
    if isempty(anat_struct)
        fprintf('[WARNING] No anatomical file found for %s. Skipping.\n',subj);
        continue;
    end
    anat_file = fullfile(anat_dir,anat_struct(1).name);
    average_files{end+1,1} = anat_file;

    % Grab the JSON from the first available subject to use as template
    if isempty(source_json)
        expected_json = dir(fullfile(anat_dir,sprintf('wm*%s_T1w.json',subj)));
        if ~isempty(expected_json)
            source_json = fullfile(anat_dir,expected_json(1).name);
        end
    end
end

if isempty(average_files) || length(average_files)<length(subjects)
    fprintf('[WARNING] Number of anatomical images (%d) is less than number of subjects (%d)!\n',length(average_files),length(subjects));
end

fprintf('\n==================================================\n');
fprintf('Calculating group average Anatomical image...\n');

% ####################### SPM Batch #######################
clear matlabbatch;
matlabbatch{1}.spm.util.imcalc.input = average_files;
matlabbatch{1}.spm.util.imcalc.output = 'wmavg-group_T1w.nii';
matlabbatch{1}.spm.util.imcalc.outdir = {group_dir};
matlabbatch{1}.spm.util.imcalc.expression = 'mean(X)'; % calculates the mean/average
matlabbatch{1}.spm.util.imcalc.var = struct('name', {}, 'value', {});
matlabbatch{1}.spm.util.imcalc.options.dmtx = 1; % reads images into data matrix
matlabbatch{1}.spm.util.imcalc.options.mask = 0;
matlabbatch{1}.spm.util.imcalc.options.interp = 1;
matlabbatch{1}.spm.util.imcalc.options.dtype = 4;

try
    spm_jobman('run', matlabbatch);
    fprintf('>>> Averaging completed successfully. Saved in: %s\n',group_dir);
    
    % Create JSONs for the new file
    target_json = fullfile(group_dir,'wmavg-group_T1w.json');
    create_avg_json(source_json,target_json);
    fprintf('>>> Group JSON file generated.\n');
catch ME
    fprintf('[CRITICAL ERROR] SPM ImCalc failed: %s\n',ME.message);
end

fprintf('\nFinished!\n')

%% Helper Functions

function create_avg_json(source_json_path,target_json_path)

if exist(source_json_path,'file')
    content = fileread(source_json_path);
    json_data = jsondecode(content);
else
    json_data = struct(); % start new one
end

json_data.SpatialNormalization = true;
json_data.NormalizationTemplate = 'MNI 152';
json_data.NormalizationSoftware = 'SPM12';
json_data.Description = 'Group average anatomical image. Warped to MNI space using Forward Deformation Field from the Segmentation.';

% Save .json file
fid = fopen(target_json_path,'w');
if fid==-1; warning('Could not save JSON file.'); return; end
fprintf(fid,'%s',jsonencode(json_data,'PrettyPrint',true));
fclose(fid);
end