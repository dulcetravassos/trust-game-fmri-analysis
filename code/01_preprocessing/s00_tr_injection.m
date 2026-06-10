%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%                                                                        %
%   TR injection in NIfTI headers (for BIDS-compliance)                  %
%                                                                        %
%   This script loops through all subjects in the rawdata folder and     %
%   automatically injects the correct Repetition Time (TR) into the      %
%   NIfTI header (pixdim(5)) based on the file type (anat, fmap, func)   %
%   and task.                                                            %
%                                                                        %
%   Author: Dulce Travassos                                              %
%   Created: 07/05/2026                                                  %
%   Last update: 10/06/2026                                              %
%                                                                        %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

clear all; clc;

%% Initial Configurations
% Change according to your preferences

% Main folder
main_dir = 'C:\Users\User\Desktop\Tese';

spm_path = fullfile(main_dir,'spm12');

% Input and output directories
base_dir = fullfile(main_dir,'data','spm-data');
raw_dir = fullfile(base_dir,'rawdata');
deriv_dir = fullfile(base_dir,'derivatives','spm-preprocessing');

% List of Subjects
subjects = {
    'sub-002', 'sub-003', 'sub-004', 'sub-006', 'sub-007', 'sub-008', ...
    'sub-009', 'sub-011', 'sub-012', 'sub-013', 'sub-014', 'sub-015', ...
    'sub-016', 'sub-017', 'sub-018', 'sub-019', 'sub-020', 'sub-021', ...
    'sub-022', 'sub-023'
};

%% TR injection

% Initialize SPM
if isempty(which('spm')); addpath(spm_path); end
spm('defaults', 'FMRI');
spm_jobman('initcfg');

fprintf('Starting Automatic TR Injection...\n');

for s = 1:length(subjects)
    subj = subjects{s};
    fprintf('\n-------------- %s --------------\n',subj);

    subfolders = {'anat','fmap','func'};

    for f=1:length(subfolders)

        current_folder = fullfile(raw_dir,subj,subfolders{f});

        if ~exist(current_folder,'dir'); continue; end;

        nii_files = dir(fullfile(current_folder,'*.nii'));

        for i=1:length(nii_files)
            file_name = nii_files(i).name;
            file_path = fullfile(current_folder,file_name);

            % Define TR for each file type
            if strcmp(subfolders{f},'anat')
                TR = 2.3;
            elseif strcmp(subfolders{f},'fmap')
                TR = 0.4;
            elseif strcmp(subfolders{f},'func')
                if contains(file_name,'task-main')
                    TR = 2;
                elseif contains(file_name,'task-localizer')
                    TR = 2;
                else
                    continue;
                end
            else
                continue; % ignore other folders
            end

            % Injection in the NIfTI header
            try
                N = nifti(file_path); % check spm12/@nifti/nifti.m

                % Reads old TR
                if isempty(N.timing) || isempty(N.timing.tspace) 
                    old_TR = 0;
                else
                    old_TR = N.timing.tspace;
                end

                if isnan(old_TR); old_TR = 0; end;

                % Verifies if TR injection is needed
                if abs(old_TR-TR)<0.001 % safety against floating-point precision errors
                    fprintf('   -> [SKIPPED] %s (TR already correct: %f)\n',file_name,old_TR);
                else
                    % Inject TR
                    if isempty(N.timing)
                        N.timing = struct('toffset',0,'tspace',TR);
                    else
                        N.timing.tspace = TR; % check spm_file_merge.m
                    end
                    create(N); % check file spm12/@nifti/create.m
                    fprintf('   -> [UPDATED] %s: %f -> %f\n',file_name,old_TR,TR);
                end

            catch ME
                fprintf('[ERROR] Failure to inject in %s: %s\n',file_name,ME.message);
            end
        end
    end
end

fprintf('\nFinished!\n')