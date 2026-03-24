%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%                                                                        %
%   Check Design Quality (extra script)                                  %
%                                                                        %
%   This script tests the statistical quality of the 1st-level design,   %
%   using robust metrics (Correlation, VIF, Condition Number, Effective  %
%   Degrees of Freedom, alongside visual Overlap Plots).                 %
%   It was written specifically to assess how a short and fixed Inter-   %
%   -Stimulus Interval (ISI) between the VIDEO and DECISION phases       %
%   affected the collinearity of the model, and to validate if the       %
%   estimated parameters remain reliabe, despite this design limitation. %
%   The outputs should be interpreted not in isolation, but as a whole.  %
%                                                                        %
%   Author: Dulce Travassos                                              %
%   Created: 24/03/2026                                                  %
%   Last update: 24/03/2026                                              %
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

% List of Subjects to test
subjects = {
    'sub-002', 'sub-003', 'sub-004', 'sub-006', 'sub-007', 'sub-008', ...
    'sub-009', 'sub-011', 'sub-012', 'sub-013', 'sub-014', 'sub-015', ...
    'sub-016', 'sub-017', 'sub-018', 'sub-019', 'sub-020', 'sub-021', ...
    'sub-022', 'sub-023'
};

% Tasks to test
tasks = {'task-main', %'task-localizer'
    };

%% Check Design Quality

% Initialize SPM
if isempty(which('spm')); addpath(spm_path); end
spm('defaults', 'FMRI');
spm_jobman('initcfg');

for s = 1:length(subjects)
    subj = subjects{s};

    for t = 1:length(tasks)
        task = tasks{t};

        fprintf('\n===================================================\n');
        fprintf('>>>>>>>> ANALYSING: %s %s <<<<<<<<\n',upper(subj),task);
        fprintf('===================================================\n')

        % Load SPM.mat
        spm_file = fullfile(deriv_dir,subj,'stats',task,'SPM.mat');
        if ~exist(spm_file,'file')
            fprintf('[WARNING] No SPM.mat found for %s. Skipping...\n',subj);
            continue;
        end
        load(spm_file,'SPM');
        
        X = SPM.xX.X; % Design Matrix
        names = SPM.xX.name; % Columns' names
        TR = SPM.xY.RT; % TR

        % Skip/clean constant columns, to avoid mathematical errors
        X_var = X(:,var(X)>0); % if var = 0, then the values in the column are constant
        names_var = names(var(X)>0);
        R = corr(X_var);
    
        %% Correlation Between Conditions
        % Highly correlated conditions are problematic, because the SPM GLM model struggles to separate 
        % the shared variance, making it difficult to attribute the BOLD signal to a specific condition.
        
        fprintf('\n -------- Correlations above 0.5 --------\n');
        threshold = 0.5;
        [row,col] = find(abs(R)>threshold);
        valid = row<col; % avoids repetition & the diagonal
        row = row(valid); col = col(valid);
        
        has_warning = false;
        for i = 1:length(row)
            name1 = names_var{row(i)};
            name2 = names_var{col(i)};

            % Skip movement x movement
            if ~isempty(regexp(name1,'R\d+','once')) && ~isempty(regexp(name2,'R\d+','once')); continue; end;

            has_warning = true;
            fprintf('r = %.02f | %s <---> %s\n',R(row(i),col(i)),name1,name2);
        end
        if ~has_warning
            fprintf('No correlation above %.02f found.\n',threshold);
        end

        % Visual heatmap
        figure; imagesc(R); colorbar;
        title(sprintf('Design Matrix Correlation (R) - %s',subj));
        xlabel('Regressors (Columns)'); ylabel('Regressors (Columns)');

        fprintf('\n##############################################\n');
        
        %% VIF (Variance Inflation Factor)
        % VIF quantifies how much the variance of an estimated regression coefficient is inflated due to 
        % multicollinearity. VIF = 1 signifies no redundancy among variables (perfect orthogonality), 
        % while VIF = inf signifies exact multicollinearity.
           
        % the VIF can be calculated as the diagonal of the inverse of the correlation matrix (https://doi.org/10.1016/B978-044452701-1.00076-4)
        VIF = diag(pinv(R)); % note - using pinv() instead of inv() (pseudoinverse)
        
        fprintf('\n -------- VIF --------\n');
        fprintf('VIF: if <5 Good, if >5 Warning, if >10 Critical\n\n');
        
        for i = 1:length(names_var)
            % Skip movement x movement
            if isempty(regexp(names_var{i},'R\d+','once'))
                fprintf('VIF = %.2f | %s\n',VIF(i),names_var{i});
            end
        end

        fprintf('\n##############################################\n');

        %% Eigenvalues & Condition Number of a Matrix
        % The condition number (derived from the eigenvalues) measures the stability of the design matrix, 
        % indicating how sensitive the final GLM model is to noise. Specifically, a very high condition
        % number means small changes in the data could result in highly unreliable beta estimates. 
        % Pratically, this means that a high variety in eigenvalues translates to columns contributing
        % with much more information than others. In fMRI terms, this could mean that there are highly 
        % collinear experimental events that the GLM cannot effectively separate, and compensates by 
        % assigning unpredictable (extreme) beta weights to those conditions.
        
        fprintf('\n -------- Condition Number (Eigenvalues) --------\n');
        fprintf('kappa: if <30 Good, if 30-100 Warning, if >100 Critical\n\n');
        cond_num = cond(X_var);

        fprintf('Condition Number (Kappa) = %.2f\n',cond_num);
        fprintf('\n##############################################\n');

        %% Effective Degrees of Freedom
        % Represents the number of truly independent observations in the time series, adjusted for the 
        % inherent temporal autocorrelation of the BOLD signal. The higher the degrees of freedom, the
        % greater the statistical power, making it easier to detect true activations.
        
        fprintf('\n -------- Effective Degrees of Freedom --------\n');
        erdf = SPM.xX.erdf; % effective residual degrees of freedom
        fprintf('eDF = %.2f\n',erdf);
        fprintf('\n##############################################\n');

        %% Overlap plots
        % Visual demonstration of the temporal overlap (shared variance) between the predicted BOLD 
        % responses (convolved) of two consecutive events. High visual overlap might explain the 
        % mathematical collinearity and shows the shared BOLD signal that the GLM struggles to separate.

        fprintf('\n -------- BOLD Sobreposition: VIDEO & DECISION --------\n');
        if s == 1 % show only for sub-001, or else it would open 20 figures

            idx_video = find(contains(names,'Sn(1) congruent_VIDEO'),1);
            idx_decision = find(contains(names,'Sn(1) congruent_DECISION'),1);
            
            if ~isempty(idx_video) && ~isempty(idx_decision)
                window = 1:min(200,size(X,1)); 
                time_secs = (window-1)*TR;
                
                point_video = X(window,idx_video);
                point_decision = X(window,idx_decision);
                
                figure;
                plot(time_secs,point_video,'b'); hold on;
                plot(time_secs,point_decision,'r');
                
                title(sprintf('BOLD Sobreposition: VIDEO vs. DECISION (%s)',subj));
                xlabel('Time (s)'); ylabel('Amplitude');
                legend('Video','Decision','Location','best');
                grid on;
                
                r = corr(point_video,point_decision);
                txt = sprintf('r = %.2f',r);
                text(max(time_secs)*0.7,max(point_video)*0.9,txt);
            end
        end
    end
end