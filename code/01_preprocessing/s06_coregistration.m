%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%                                                                        %
%   Coregistration (Est) (BIDS ready)                                    %
%                                                                        %
%   Matches the anatomical image (after setting the origin) to the mean  % 
%   functional image (meana*), to allow later spatial normalization.     %
%   Note: since this is "Estimate Only", it does not create a new 'r*'   %
%   anatomical file, but updates the header of the existing T1w image.   %
%   This avoids an extra interpolation and preserves the high resolution % 
%   of the anatomical image for the subsequent Segmentation step.        %
%   However, this script also updates the JSON sidecar for the T1w file. % 
%                                                                        %
%   Author: Dulce Travassos                                              %
%   Created: 25/02/2026                                                  %
%   Last update: 28/04/2026                                              %
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
    'sub-002', 'sub-003', 'sub-004', 'sub-006', 'sub-007', 'sub-008', ...
    'sub-009', 'sub-011', 'sub-012', 'sub-013', 'sub-014', 'sub-015', ...
    'sub-016', 'sub-017', 'sub-018', 'sub-019', 'sub-020', 'sub-021', ...
    'sub-022', 'sub-023'
};

%% Align T1w to Functional Space

% Initialize SPM
if isempty(which('spm')); addpath(spm_path); end
spm('defaults', 'FMRI');
spm_jobman('initcfg');

for s = 1:length(subjects)
    subj = subjects{s};
    fprintf('\n==================================================\n');
    fprintf('Coregistering T1w for: %s\n', subj);
    
    func_dir = fullfile(deriv_dir,subj,'func');
    anat_dir = fullfile(deriv_dir,subj,'anat');

    % Find Mean Functional image (Reference - image that remains stationary)
    file_pattern = sprintf('mean*a%s_task-main_run-01_bold.nii', subj);
    mean_struct= dir(fullfile(func_dir,file_pattern));
    if isempty(mean_struct)
        fprintf('[ERROR] Missing Mean Functional Image for %s.\n',subj);
        continue;
    end
    mean_func = fullfile(func_dir,mean_struct(1).name);

    % T1w anatomical (Source - image that jiggles the best to match the reference)
    anat_file = fullfile(anat_dir,[subj '_T1w.nii']);
    if ~exist(anat_file,'file')
        fprintf('[ERROR] Missing T1w file for %s.\n',subj);
        continue;
    end

    out_json = replace(anat_file,'.nii','.json');

    % ####################### SPM Batch #######################
    
    clear matlabbatch;
    matlabbatch{1}.spm.spatial.coreg.estimate.ref = {mean_func};
    matlabbatch{1}.spm.spatial.coreg.estimate.source = {anat_file};
    matlabbatch{1}.spm.spatial.coreg.estimate.other = {''};
    matlabbatch{1}.spm.spatial.coreg.estimate.eoptions.cost_fun = 'nmi';
    matlabbatch{1}.spm.spatial.coreg.estimate.eoptions.sep = [4 2];
    matlabbatch{1}.spm.spatial.coreg.estimate.eoptions.tol = [0.02 0.02 0.02 0.001 0.001 0.001 0.01 0.01 0.01 0.001 0.001 0.001];
    matlabbatch{1}.spm.spatial.coreg.estimate.eoptions.fwhm = [7 7];
    
    try
        spm_jobman('run',matlabbatch);
        fprintf('Success! Creating JSON for BIDS compliance...\n');
        update_anat_json(out_json,subj);
    catch ME
        fprintf('[ERROR] Alignment failed for %s: %s\n',subj,ME.message);
    end
end
fprintf('\nDone!\n');

%% Helper Functions

function update_anat_json(target_json_path,subj)

if exist(target_json_path,'file')
    content = fileread(target_json_path);
    try
        json_data = jsondecode(content);
    catch
        json_data = struct();
    end
else
    json_data = struct();
end

json_data.Coregistration = true;
json_data.Software = 'SPM12';
json_data.CoregistrationMethod = 'Estimate Only';
json_data.Description = 'T1w Coregistered to Mean Functional Image';
json_data.CoregisteredTo = sprintf('Mean Functional Image (mean*a%s_task-main_run-01_bold.nii)',subj);
json_data.Interpolation = 'None (Header transformation only)';

% Save .json file
fid = fopen(target_json_path,'w');
if fid==-1; warning('Could not save JSON file.'); return; end
fprintf(fid,'%s',jsonencode(json_data,'PrettyPrint',true));
fclose(fid);
end