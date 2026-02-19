%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%                                                                        %
%   Align Magnitude and Phase to Mean Functional Image                   %
%                                                                        %
%   To perform Distortion Correction on FSL FUGUE, we need both the      %
%   phasediff and magnitude files to be aligned to the brain image       %
%   previously realigned. This script deals with cases in which a run    %
%   has 2 available magnitudes. This script also creates JSON files for  % 
%   each new file, following BIDS standard.                              %
%                                                                        %
%   Author: Dulce Travassos                                              %
%   Created: 19/02/2026                                                  %
%   Last update: 19/02/2026                                              %
%                                                                        %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

clear all; clc;

%% Initial Configurations
% Change according to your preferences
% Note that some parameters may have to be changed inside the main loop

spm_path = 'C:\Users\User\Desktop\Tese\spm12';

% Input and output directories
base_dir = 'C:\Users\User\Desktop\Tese\data\spm-data';
raw_dir = fullfile(base_dir,'rawdata');
deriv_dir = fullfile(base_dir,'derivatives','spm-preprocessing');

% List of Subjects
subjects = {
    'sub-002', 'sub-003', 'sub-004', 'sub-006', 'sub-007', 'sub-008', ...
    'sub-009', 'sub-011', 'sub-012', 'sub-013', 'sub-014', 'sub-015', ...
    'sub-016', 'sub-017', 'sub-018', 'sub-019', 'sub-020', 'sub-021', ...
    'sub-022', 'sub-023'
};

% Subjects that have a "Fake Magnitude" (it is already aligned!)
fake_mag_subjects = {'sub-002', 'sub-003', 'sub-004'};

%% Align Fieldmaps

% Initialize SPM
if isempty(which('spm')); addpath(spm_path); end
spm('defaults', 'FMRI');
spm_jobman('initcfg');

for s = 1:length(subjects)
    subj = subjects{s};
    fprintf('\n==================================================\n');
    fprintf('Aligning fieldmaps for: %s\n', subj);
    
    raw_fmap_dir = fullfile(raw_dir,subj,'fmap');
    deriv_fmap_dir = fullfile(deriv_dir,subj,'fmap');
    func_dir = fullfile(deriv_dir,subj,'func');

    if ~exist(deriv_fmap_dir,'dir'); mkdir(deriv_fmap_dir); end

    % Get all phasediff files for this subject in the rawdata
    phase_struct = dir(fullfile(raw_fmap_dir,'*_phasediff.nii'));
    if isempty(phase_struct)
        fprintf('[WARNING] No phasediff files found for %s in rawdata.\n',subj);
        continue;
    end

    % Find Mean Functional image (Reference)
    file_pattern = sprintf('mean*a%s_task-main_run-01_bold.nii', subj);
    mean_struct= dir(fullfile(func_dir,file_pattern));
    if isempty(mean_struct)
        fprintf('[ERROR] Missing Mean Functional Image for %s.',subj);
        continue;
    end
    mean_func = fullfile(func_dir,mean_struct(1).name);
    
    is_fake_mag = ismember(subj,fake_mag_subjects);

    for p = 1:length(phase_struct)
        phase_raw_name = phase_struct(p).name;
        phase_raw_path = fullfile(raw_fmap_dir,phase_raw_name);

        run_idx = regexp(phase_raw_name, 'run-\d+','match');
        if isempty(run_idx); continue; end;
        current_run = run_idx{1};

        fprintf('\n>> Processing run %s...\n',current_run);

        % First, we need to select and copy the raw files to the
        % derivatives (to maintain the rawfile folder intact!)
        phase_deriv_path = fullfile(deriv_fmap_dir,phase_raw_name);
        if ~exist(phase_deriv_path,'file')
            copyfile(phase_raw_path,phase_deriv_path);
            copyfile(replace(phase_raw_path,'.nii','.json'),replace(phase_deriv_path,'.nii','.json')); % also copy JSON file!
        end

        if ~is_fake_mag % if fake magnitude, it is already aligned to the mean functional image...
            target_mag_name='';
            % There are some runs that have 2 magnitude files (magnitude1 & magnitude2), instead of a 
            % single magnitude. By manual analysis, we concluded that the magnitude1 file was always
            % better, EXCEPT for runs 6 and 8 of sub-009, where magnitude2 had the best quality.
            if strcmp(subj,'sub-009') && (strcmp(current_run,'run-06')||strcmp(current_run,'run-08'))
                target_mag_name = strrep(phase_raw_name,'phasediff','magnitude2');
                fprintf('[IMPORTANT!] Forcing magnitude2 for %s %s\n',subj,current_run);
            else
                % In the remaining cases, we can try to use 'magnitude1'; if
                % that file does not exist, we know it has to be 'magnitude'!
                mag1_name = strrep(phase_raw_name,'phasediff','magnitude1');
                mag_name = strrep(phase_raw_name,'phasediff','magnitude');
                if exist(fullfile(raw_fmap_dir,mag1_name),'file')
                    target_mag_name = mag1_name;
                elseif exist(fullfile(raw_fmap_dir,mag_name),'file')
                    target_mag_name = mag_name;
                end
            end

            if isempty(target_mag_name)
                fprintf('[ERROR] Could not find a matching magnitude for %s!\n',phase_raw_name);
                continue;
            end
            
            % Copy selected magnitude to derivatives
            mag_raw_path = fullfile(raw_fmap_dir,target_mag_name);
            mag_deriv_path = fullfile(deriv_fmap_dir,target_mag_name);

            if ~exist(mag_deriv_path,'file')
                copyfile(mag_raw_path,mag_deriv_path);
                if exist(replace(mag_raw_path,'.nii','.json'),'file')
                    copyfile(replace(mag_raw_path,'.nii','.json'),replace(mag_deriv_path,'.nii','.json'));
                end
            end
            fprintf('* Selected Magnitude: %s\n',target_mag_name);
        else
            fprintf('* Using previously generated Fake Magnitude.\n');
            mag_deriv_path = fullfile(deriv_fmap_dir,strrep(phase_raw_name,'phasediff','magnitude'));
        end

        % ####################### SPM Batch #######################
        
        clear matlabbatch;

        if is_fake_mag % already aligned, only needs reslicing
            fprintf('>> Reslicing phasediff to Mean Functional grid...\n');
            matlabbatch{1}.spm.spatial.coreg.write.ref = {mean_func};
            matlabbatch{1}.spm.spatial.coreg.write.source = {phase_deriv_path};
            matlabbatch{1}.spm.spatial.coreg.write.other = {''};
            matlabbatch{1}.spm.spatial.coreg.write.roptions.interp = 4;
            matlabbatch{1}.spm.spatial.coreg.write.roptions.wrap = [0 0 0];
            matlabbatch{1}.spm.spatial.coreg.write.roptions.mask = 0;
            matlabbatch{1}.spm.spatial.coreg.write.roptions.prefix = 'r';
        else % normal magnitudes need coregistration to mean func and to phasediff
            matlabbatch{1}.spm.spatial.coreg.estwrite.ref = {mean_func};
            matlabbatch{1}.spm.spatial.coreg.estwrite.source = {mag_deriv_path};
            matlabbatch{1}.spm.spatial.coreg.estwrite.other = {phase_deriv_path};
            matlabbatch{1}.spm.spatial.coreg.estwrite.eoptions.cost_fun = 'nmi';
            matlabbatch{1}.spm.spatial.coreg.estwrite.eoptions.sep = [4 2];
            matlabbatch{1}.spm.spatial.coreg.estwrite.eoptions.tol = [0.02 0.02 0.02 0.001 0.001 0.001 0.01 0.01 0.01 0.001 0.001 0.001];
            matlabbatch{1}.spm.spatial.coreg.estwrite.eoptions.fwhm = [7 7];
            matlabbatch{1}.spm.spatial.coreg.estwrite.roptions.interp = 4;
            matlabbatch{1}.spm.spatial.coreg.estwrite.roptions.wrap = [0 0 0];
            matlabbatch{1}.spm.spatial.coreg.estwrite.roptions.mask = 0;
            matlabbatch{1}.spm.spatial.coreg.estwrite.roptions.prefix = 'r';
        end
        try
            spm_jobman('run',matlabbatch);
        catch ME
            fprintf('[ERROR] Coregistration failed for %s %s: %s\n',subj,current_run,ME.message);
        end
    end
end
fprintf('\nDone!\n');