%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%                                                                        %
%   Export Activations Table Results to Excel & Thresholded Maps         %
%                                                                        %
%   This script reads the estimated SPM.mat, applies a statistical       %
%   threshold, and automatically exports the peak coordinates (.xls) and %
%   the thresholded brain maps (.nii) for all evaluated contrasts.       %
%                                                                        %
%   Author: Dulce Travassos                                              %
%   Created: 14/04/2026                                                  %
%   Last update: 01/09/2026                                              %
%                                                                        %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

clear all; clc;

%% Initial Configurations
% Change according to your preferences
% Note that some parameters may have to be changed inside the main loop

% Main folder
main_dir = 'C:\Users\User\Desktop\Tese';

spm_path = fullfile(main_dir,'spm12');

% Input and output directories
base_dir = fullfile(main_dir,'data','spm-data');
deriv_dir = fullfile(base_dir,'derivatives','spm-preprocessing');
export_base_dir = fullfile(base_dir,'derivatives','spm-statistics','1st-level-exports');

% List of Subjects
subjects = {
    'sub-819', 'sub-908', 'sub-147', 'sub-915', 'sub-641', 'sub-119', ...
    'sub-295', 'sub-557', 'sub-958', 'sub-965', 'sub-177', 'sub-971', ...
    'sub-664', 'sub-497', 'sub-805', 'sub-162', 'sub-435', 'sub-917', ...
    'sub-797', 'sub-960'
};

% Tasks
tasks = {'task-main','task-localizer'};

% Statistical Threshold Parameters
fprintf('--------------------------------------------------\n');
fprintf('Statistical Threshold Parameters\n');
fprintf('--------------------------------------------------\n');

% p-value
in_p = input('Enter p-value [default: 0.001]: ','s');
if ~isnan(str2double(in_p))
    p_threshold = str2double(in_p);
else
    p_threshold = 0.001; % fallback
end
fprintf('Using p-value = %f\n',p_threshold);

% p-value adjustment method
in_adj = input('Enter p-value adjustment (none, FWE, FDR) [default: none]: ','s');
if strcmp(in_adj,'none')||strcmp(in_adj,'FWE')||strcmp(in_adj,'FDR')
    p_adjust = in_adj;
else
    p_adjust = 'none'; % fallback
end
fprintf('Using p-value adjustment = %s\n',p_adjust);

% cluster size
in_k = input('Enter minimum cluster size (k extent) [default: 20]: ','s');
if ~isnan(str2double(in_k))
    k_extent = round(str2double(in_k));
else
    k_extent = 20; % fallback
end
fprintf('Using k extent = %f\n',k_extent);

fprintf('\n>>> Proceeding with: p < %f (%s), k >= %f voxels\n',p_threshold,p_adjust,k_extent);

%% Extraction Loop

% Initialize SPM
if isempty(which('spm')); addpath(spm_path); end
spm('defaults', 'FMRI');
spm_jobman('initcfg');

% Name formatting
p_str = strrep(num2str(p_threshold),'.','p');
if strcmp(p_adjust,'none')
    adj_str = 'unc';
else
    adj_str = p_adjust;
end
thr_sig = sprintf('p%s_%s_k%d',p_str,adj_str,k_extent);

for s = 1:length(subjects)
    subj = subjects{s};
    fprintf('\n==================================================\n');
    fprintf('Extracting Results for: %s\n', subj);

    stats_dir = fullfile(deriv_dir,subj,'stats');
    
    for t=1:length(tasks)
        current_task = tasks{t};

        % Get Design Matrix (SPM.mat)
        design_matrix = fullfile(stats_dir,current_task,'SPM.mat');
        if ~exist(design_matrix,'file')
            fprintf('[WARNING] No SPM.mat found for %s (%s). Skipping.\n',subj,current_task);
            continue;
        end

        % Load SPM.mat & contrasts
        load(design_matrix,'SPM');
        if ~isfield(SPM,'xCon') || isempty(SPM.xCon)
            fprintf('[WARNING] No contrasts defined in SPM.mat for %s (%s). Skipping...\n',subj,current_task);
        end

        num_contrasts = length(SPM.xCon);

        for c=1:num_contrasts

            con_name = SPM.xCon(c).name;

            % ------------------------ Modify Contrast Name ------------------------
            % ">" -> "_vs_"
            safe_name = regexprep(con_name,'\s*>\s*','_vs_');
            % "+" -> "-"
            safe_name = regexprep(safe_name,'\s*\+\s*','_');
            % "(" & ")" -> "_"
            safe_name = regexprep(safe_name,'[()]','_');
            % remove repeated underscores and underscores at teh beginning or end 
            safe_name = regexprep(safe_name,'_+','_');
            safe_name = regexprep(safe_name,'^_|_$','');


            % ####################### SPM Batch #######################     
            % Check http://web.mit.edu/spm_v12/distrib/spm12/config/spm_run_results.m 
            % & https://github.com/spm/MultimodalScripts/blob/master/code/scripted/batch_stats_fmri_job.m 
            clear matlabbatch;
            matlabbatch{1}.spm.stats.results.spmmat = {design_matrix};
            matlabbatch{1}.spm.stats.results.conspec.titlestr = con_name;
            matlabbatch{1}.spm.stats.results.conspec.contrasts = c;
            matlabbatch{1}.spm.stats.results.conspec.threshdesc = p_adjust;
            matlabbatch{1}.spm.stats.results.conspec.thresh = p_threshold;
            matlabbatch{1}.spm.stats.results.conspec.extent = k_extent;
            matlabbatch{1}.spm.stats.results.conspec.conjunction = 1;
            matlabbatch{1}.spm.stats.results.conspec.mask.none = 1;
            % Export Excel table
            matlabbatch{1}.spm.stats.results.export{1}.xls = true;
            % Export Thresholded SPM map (.nii)
            matlabbatch{1}.spm.stats.results.export{2}.tspm.basename = ['thr_' thr_sig '_' safe_name];

            try
                spm_jobman('run', matlabbatch);
                fprintf('>>> Exported successfully %s\n',con_name);
            catch ME
                fprintf('[ERROR] Failed to export contrast %s for %s: %s\n',con_name,subj,ME.message);
                continue;
            end

            export_dir = fullfile(export_base_dir,current_task);
            if ~exist(export_dir,'dir'); mkdir(export_dir); end;

            % Copy NIfTI image and Excel file to the '1st_level_exports' folder
            tspm_file = fullfile(stats_dir,current_task,sprintf('spmT_%04d_thr_%s_%s.nii',c,thr_sig,safe_name));
            if exist(tspm_file,'file')
                copyfile(tspm_file,fullfile(export_dir,sprintf('%s_spmT_%04d_thr_%s_%s.nii',subj,c,thr_sig,safe_name)));
            end
            xls_files = dir(fullfile(stats_dir,current_task,'*.xls*'));
            if ~isempty(xls_files)
                % we want to copy the most recent .xls file only
                [~,idx] = max([xls_files.datenum]);
                latest_xls = fullfile(stats_dir,current_task,xls_files(idx).name);
                [~,~,ext] = fileparts(latest_xls); % safety measure to detect .xlsx extensions, for example
                copyfile(latest_xls,fullfile(export_dir,sprintf('%s_con_%04d_thr_%s_%s%s',subj,c,thr_sig,safe_name,ext)));
            end

        end

        % ######################### Conjunction Analysis #########################
        if strcmp(current_task,'task-localizer')
            fprintf('>>> Generating Conjunction Analysis...\n');
            
            idx_con1 = find(contains({SPM.xCon.name},'Faces > Objects'));
            idx_con2 = find(contains({SPM.xCon.name},'Faces > Scrambled'));
            if ~isempty(idx_con1) && ~isempty(idx_con2)
                safe_conj_name = 'Conjunction_Faces_vs_Objects_AND_Scrambled';
                
                % ####################### SPM Batch #######################     
                clear matlabbatch;
                matlabbatch{1}.spm.stats.results.spmmat = {design_matrix};
                matlabbatch{1}.spm.stats.results.conspec.titlestr = 'Faces > Objects AND Faces > Scrambled';
                matlabbatch{1}.spm.stats.results.conspec.contrasts = [idx_con1, idx_con2];
                matlabbatch{1}.spm.stats.results.conspec.threshdesc = p_adjust;
                matlabbatch{1}.spm.stats.results.conspec.thresh = p_threshold;
                matlabbatch{1}.spm.stats.results.conspec.extent = k_extent-10; % reduced to be less restritive
                matlabbatch{1}.spm.stats.results.conspec.conjunction = 1;
                matlabbatch{1}.spm.stats.results.conspec.mask.none = 1;
                % Export Excel table
                matlabbatch{1}.spm.stats.results.export{1}.xls = true;
                % Export Thresholded SPM map (.nii)
                matlabbatch{1}.spm.stats.results.export{2}.tspm.basename = ['thr_' thr_sig '_' safe_conj_name];
                
                try
                spm_jobman('run', matlabbatch);
                fprintf('>>> Conjunction exported successfully %s\n',safe_conj_name);
                catch ME
                    fprintf('[ERROR] Failed to export Conjunction for %s: %s\n',subj,ME.message);
                    continue;
                end
    
                export_dir = fullfile(export_base_dir,current_task);
                if ~exist(export_dir,'dir'); mkdir(export_dir); end;
    
                % Copy NIfTI image and Excel file to the '1st_level_exports' folder
                conj_nii = dir(fullfile(stats_dir,current_task,['*thr_' thr_sig '_' safe_conj_name '.nii']));
                if ~isempty(conj_nii)
                    copyfile(fullfile(stats_dir,current_task,conj_nii(1).name),fullfile(export_dir,sprintf('%s_spmT_CONJ_thr_%s_%s.nii',subj,thr_sig,safe_conj_name)));
                end
                xls_files = dir(fullfile(stats_dir,current_task,'*.xls*'));
                if ~isempty(xls_files)
                    % we want to copy the most recent .xls file only
                    [~,idx] = max([xls_files.datenum]);
                    latest_xls = fullfile(stats_dir,current_task,xls_files(idx).name);
                    [~,~,ext] = fileparts(latest_xls); % safety measure to detect .xlsx extensions, for example
                    copyfile(latest_xls,fullfile(export_dir,sprintf('%s_con_CONJ_thr_%s_%s%s',subj,thr_sig,safe_conj_name,ext)));
                end
            end
        end
    end
end

fprintf('\nFinished!\n')