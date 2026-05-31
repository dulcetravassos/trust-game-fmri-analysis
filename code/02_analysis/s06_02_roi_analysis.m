%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%                                                                        %
%   ROI Analysis                                                         %
%                                                                        %
%   This script extracts mean beta values from subject-specific MarsBaR  %
%   spherical ROIs. It features a custom function (adapted from Andrew   %
%   Jahn's code) modified to align the ROI and the contrast spaces,      %
%   using the functional contrast's affine matrix. It also automatically %
%   filters out-of-brain artifacts (absolute zeros) before mean          %
%   calculation.                                                         %
%                                                                        %
%   Author: Dulce Travassos                                              %
%   Created: 30/05/2026                                                  %
%   Last update: 31/05/2026                                              %
%                                                                        %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Credits to Andy's Brain Book: https://andysbrainbook.readthedocs.io/en/latest/SPM/SPM_Short_Course/SPM_09_ROIAnalysis.html
% Based on code by Andrew Jahn: https://github.com/andrewjahn/SPM_Scripts/blob/master/Extract_ROI_Data.m

clear all; clc;

%% Initial Configurations
% Change according to your preferences
% Note that some parameters may have to be changed inside the main loop

spm_path = 'C:\Users\User\Desktop\Tese\spm12';

% Input and output directories
base_dir = 'C:\Users\User\Desktop\Tese\data\spm-data';
deriv_dir = fullfile(base_dir,'derivatives');
roi_dir = fullfile(deriv_dir,'spm-rois');
stats_dir = fullfile(deriv_dir,'spm-statistics');

% List of Subjects
subjects = {
    'sub-002', 'sub-003', 'sub-004', 'sub-006', 'sub-007', 'sub-008', ...
    'sub-009', 'sub-011', 'sub-012', 'sub-013', 'sub-014', 'sub-015', ...
    'sub-016', 'sub-017', 'sub-018', 'sub-019', 'sub-020', 'sub-021', ...
    'sub-022', 'sub-023'
};

%% ROI Analysis

% Initialize SPM
if isempty(which('spm')); addpath(spm_path); end
spm('defaults', 'FMRI');
spm_jobman('initcfg');

% User input - selection of ROI and contrast
while true
    region = input('Enter the region (OFA, pSTS or FFA) [case sensitive]: ','s');
    if strcmp(region,'OFA')||strcmp(region,'pSTS')||strcmp(region,'FFA'); break;
    else; fprintf('Invalid region. Try again.\n'); end;
end

while true
    lat = input('Enter laterality (r or l) [case sensitive]: ','s');
    if strcmp(lat,'r')||strcmp(lat,'l'); break;
    else; fprintf('Invalid laterality. Try again.\n'); end;
end

con_names = {'1a','1b','2a','2b','3','4a','4b','4c','4d','5a','5b','5c','6a','6b','6c','7','8a','8b'};
con_codes = {'con_0001','con_0002','con_0003','con_0004','con_0005','con_0006','con_0007','con_0008', ...
    'con_0009','con_0010','con_0011','con_0012','con_0013','con_0014','con_0015','con_0016','con_0017','con_0018'};
fprintf('Available contrasts: %s\n',strjoin(con_names,', '));
while true
    con = input('Enter contrast for ROI analysis (e.g., 1a): ','s');
    idx = find(strcmp(con_names,con));
    if ~isempty(idx)
        con_file_name = con_codes{idx}; break;
    else
        fprintf('Invalid contrast, try again.\n');
    end
end

roi_name_search = sprintf('%s-%s',lat,region); % example: r-FFA; l-pSTS

results_table = table();

fprintf('\n ----- Starting extraction for %s (Contrast %s) -----\n',roi_name_search,con);
for s=1:length(subjects)
    subj = subjects{s};

    subj_stats_dir = fullfile(deriv_dir,subj,'stats','task-main');
    subj_roi_dir = fullfile(roi_dir,subj);

    roi_search = dir(fullfile(subj_roi_dir,sprintf('%s*.nii',roi_name_search)));

    con_dir = fullfile(deriv_dir,'spm-preprocessing',subj,'stats','task-main');
    contrast_file = fullfile(subj_stats_dir,sprintf('%s.nii',con_file_name));

    mean_value = NaN; % default

    if isempty(roi_search)
        fprintf('[WARNING] ROI file not found for %s.\n',subj);
    elseif ~exist(contrast_file,'file')
        fprintf('[WARNING] Contrast %s not found for %s\n',con_file_name,subj);
    else % success
        roi_file = fullfile(subj_roi_dir,roi_search(1).name);
        mean_value = Extract_ROI_Data(roi_file,contrast_file);
        fprintf('%s: extracted value = %.4f\n',subj,mean_value);
    end

    % Append results to the table
    row = table({subj},{roi_name_search},{con},mean_value, ...
        'VariableNames',{'Subject','ROI','Contrast','Mean_Beta'});
    results_table = [results_table; row];
end

% Export output
out_folder = fullfile(stats_dir,'roi-analysis'); 
if ~exist(out_folder,'dir'); mkdir(out_folder); end;
output_fn = sprintf('ROI_Extraction_%s_%s.csv',roi_name_search,con);
writetable(results_table,fullfile(out_folder,output_fn));

%% Helper Functions

function ROI_data = Extract_ROI_Data(ROI, Contrast)

    [Y,XYZmm] = spm_read_vols(spm_vol(ROI)); % check https://github.com/spm/spm/blob/main/spm_read_vols.m

    % Isolate the coordinates where the ROI exists (value > 0)
    roi_mm = XYZmm(:,Y(:)>0);

    % We need to align the contrast and the ROI spaces. We can use the affine matrix Vcon to do so 
    % (check https://github.com/spm/spm12/blob/main/spm_vol.m). Meaning, we are converting the ROI
    % coordinates to the contrast coordinates.
    % According to Linear Algebra, if MNI = Affine Matrix * Voxels, then Voxels = (Affine Matrix)^-1 * MNI
    Vcon = spm_vol(Contrast);
    vox_coords = Vcon.mat \ [roi_mm; ones(1,size(roi_mm,2))]; % note that 1s are being placed after the x y z, to
                                                              % account for matrices with more than 3 dimensions
    
    % Protection against 0s (voxels outside the brain)
    vals = spm_get_data(Vcon,vox_coords(1:3,:));
    vals(vals==0) = NaN;

    ROI_data = nanmean(vals,2);
    
end


   