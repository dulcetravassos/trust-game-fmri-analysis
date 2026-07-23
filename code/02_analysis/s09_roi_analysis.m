%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%                                                                        %
%   ROI Analysis - Interactive Single Extraction & T-Test                %
%                                                                        %
%   This script extracts mean beta values from subject-specific ROIs.    %
%   It supports both unilateral ROIs (spherical or anatomical) and       %
%   bilateral anatomical ROIs (splitting hemispheres via MNI             %
%   coordinates).                                                        %
%                                                                        %
%   It features a custom function (adapted from Andrew Jahn's code)      %
%   modified to align the ROI and the contrast spaces, using the         %
%   functional contrast's affine matrix. It also automatically filters   %
%   out-of-brain artifacts (absolute zeros) prior to computing mean      %
%   values.                                                              %
%                                                                        %
%   Exports a structured .csv file and performs a One-Sample T-Test      %
%   against zero, saving a summary report in a .txt file.                %
%                                                                        %
%   Author: Dulce Travassos                                              %
%   Created: 30/05/2026                                                  %
%   Last update: 23/07/2026                                              %
%                                                                        %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Credits to Andy's Brain Book: https://andysbrainbook.readthedocs.io/en/latest/SPM/SPM_Short_Course/SPM_09_ROIAnalysis.html
% Based on code by Andrew Jahn: https://github.com/andrewjahn/SPM_Scripts/blob/master/Extract_ROI_Data.m

clear all; clc;

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
stats_dir = fullfile(deriv_dir,'spm-statistics');

% List of Subjects
subjects = {
    'sub-002', 'sub-003', 'sub-004', 'sub-006', 'sub-007', 'sub-008', ...
    'sub-009', 'sub-011', 'sub-012', 'sub-013', 'sub-014', 'sub-015', ...
    'sub-016', 'sub-017', 'sub-018', 'sub-019', 'sub-020', 'sub-021', ...
    'sub-022', 'sub-023'
};


% Are anatomical ROIs bilateral (.nii with both hemispheres) or unilateral?
isBilateral = false;

%% ROI Analysis

% Initialize SPM
if isempty(which('spm')); addpath(spm_path); end
spm('defaults', 'FMRI');
spm_jobman('initcfg');

% User input - selection of ROI and contrast
valid_regions = {'OFA','FFA','pSTS','amygdala','caudate','NAcc'};
while true
    raw_region = input('Enter the region (OFA, pSTS, FFA, amygdala, caudate, or NAcc) [case insensitive]: ','s');
    idx = find(strcmpi(raw_region,valid_regions),1);
    if ~isempty(idx); region = valid_regions{idx}; break;
    else; fprintf('Invalid region. Try again.\n'); end;
end

while true
    lat = input('Enter laterality (r or l) [case insensitive]: ','s'); 
    lat = lower(lat);
    if strcmp(lat,'r')||strcmp(lat,'l'); break;
    else; fprintf('Invalid laterality. Try again.\n'); end;
end

con_names = {'1a','1b','2a','2b','3','4a','4b','4c','4d','5a','5b','5c','6a','6b','6c','7','8a','8b'};
con_codes = {'con_0003','con_0004','con_0005','con_0006','con_0007','con_0008','con_0009','con_0010','con_0011', ...
    'con_0012','con_0013','con_0014','con_0015','con_0016','con_0017','con_0018','con_0019','con_0020'};
fprintf('Available contrasts: %s\n',strjoin(con_names,', '));
while true
    con = input('Enter contrast for ROI analysis (e.g., 1a) [case insensitive]: ','s');
    idx = find(strcmpi(con_names,con),1);
    if ~isempty(idx)
        con_file_name = con_codes{idx}; break;
    else
        fprintf('Invalid contrast, try again.\n');
    end
end

base_roi_name = sprintf('%s-%s',lat,region); % universal name for printing and saving (e.g., 'r-FFA', 'l-amygdala')

results_table = table();

fprintf('\n ----- Starting extraction for %s (Contrast %s) -----\n',base_roi_name,con);
for s=1:length(subjects)
    subj = subjects{s};
    subj_stats_dir = fullfile(deriv_dir,subj,'stats','task-main');
    subj_roi_dir = fullfile(roi_dir,subj);

    if ismember(region,{'OFA','pSTS','FFA'})
        roi_name_search = sprintf('%s-%s',lat,region); % example: r-FFA; l-OFA
    else
        if isBilateral
            roi_name_search = sprintf('%s_%sRL',subj,region); % example: sub-020_amygdalaRL; sub-006_caudateRL
        else
            roi_name_search = sprintf('%s%s',region,upper(lat)); % example: amygdalaR; caudateL
        end
    end

    roi_search = dir(fullfile(subj_roi_dir,sprintf('%s*.nii',roi_name_search)));

    con_dir = fullfile(deriv_dir,'spm-preprocessing',subj,'stats','task-main');
    contrast_file = fullfile(con_dir,sprintf('%s.nii',con_file_name));

    mean_value = NaN; % default

    if isempty(roi_search)
        fprintf('[WARNING] ROI file not found for %s.\n',subj);
    elseif ~exist(contrast_file,'file')
        fprintf('[WARNING] Contrast %s not found for %s\n',con_file_name,subj);
    else % success
        roi_file = fullfile(subj_roi_dir,roi_search(1).name);
        mean_value = Extract_ROI_Data(roi_file,contrast_file,lat,isBilateral);
        fprintf('%s: extracted value = %.4f\n',subj,mean_value);
    end

    % Append results to the table
    row = table({subj},{base_roi_name},{con},mean_value, ...
        'VariableNames',{'Subject','ROI','Contrast','Mean_Beta'});
    results_table = [results_table; row];
end

% Export output
out_folder = fullfile(stats_dir,'roi-analysis'); 
if ~exist(out_folder,'dir'); mkdir(out_folder); end;
output_fn = sprintf('ROI_Extraction_%s_%s.csv',con,base_roi_name);
writetable(results_table,fullfile(out_folder,output_fn));


% One Sample T-Test
beta = results_table.Mean_Beta;
beta = beta(~isnan(beta)); % skips sub-009's NaNs

if ~isempty(beta)
    [h,p,ci,stats] = ttest(beta);
    
    results_folder = fullfile(out_folder,'results');
    if ~exist(results_folder,'dir'); mkdir(results_folder); end;
    txt_fn = sprintf('Stats_%s_%s.txt',con,base_roi_name);
    txt_path = fullfile(results_folder,txt_fn);
    
    fileID = fopen(txt_path,'w');
    for fid=[1,fileID] % when 1, prints on the console; when fileID, writes in the file
        fprintf(fid,'------------------------------------------\n');
        fprintf(fid,' Statistical Summary (One-Sample T-Test)\n');
        fprintf(fid,'------------------------------------------\n');
        fprintf(fid,'ROI: %s\n',base_roi_name);
        fprintf(fid,'Contrast: %s (%s)\n',con,con_file_name);
        fprintf(fid,'N (valid subjects): %d\n',length(beta));
        fprintf(fid,'Mean beta: %.4f\n',mean(beta));
        fprintf(fid,'SD: %.4f\n',std(beta));
        fprintf(fid,'t(%d): %.3f\n',stats.df,stats.tstat);
        fprintf(fid,'p-value: %.4f\n',p);
        fprintf(fid,'95%% CI: [%.4f %.4f]\n',ci(1),ci(2));
        fprintf(fileID,"Cohen's d = %.3f\n",mean(beta)/std(beta));
    end
    fclose(fileID);
    fprintf('Statistical summary saved to: %s\n',txt_path);
end

%% Helper Functions

function ROI_data = Extract_ROI_Data(ROI, Contrast, lat, isBilateral)

    [Y,XYZmm] = spm_read_vols(spm_vol(ROI)); % check https://github.com/spm/spm/blob/main/spm_read_vols.m

    % Isolate the coordinates where the ROI exists (value > 0)
    roi_mm = XYZmm(:,Y(:)>0);

    if isBilateral
        % Separate hemispheres (for .nii including both hemispheres!)
        % if x < 0 = left; if x > 0 = right
        if strcmp(lat,'l')
            roi_mm = roi_mm(:,roi_mm(1,:)<0);
        elseif strcmp(lat,'r')
            roi_mm = roi_mm(:,roi_mm(1,:)>0);
        end
    end

    if isempty(roi_mm) 
        ROI_data = NaN; 
        return; 
    end

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


   