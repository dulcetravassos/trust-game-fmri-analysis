### System Specifications
The code in this folder was developed and tested on a PC with the following specifications:

*  **Software:** MATLAB R2024b (Update 4 - 24.2.0.2833386), SPM12 (7771), MarsBaR toolbox (v0.45)
*   **OS:** Microsoft Windows 10 (64-bit)
*   **CPU:** Intel(R) Core(TM) i5-10300H CPU @ 2.50GHz
*   **RAM:** 16GB
*   **GPU:** NVIDIA GeForce RTX 2060 with Max-Q Design

> ***Note:** Scripts not specifying time of running took only a couple of minutes. Time is only specified for scripts that took longer to run.*

---


#### [`s00_convert_prt_to_spm`](s00_convert_prt_to_spm.m)

The function prt_to_spm(), using the function read_prt(), reads multiple .prt files from a selected folder; confirms the resolution of time (converting msec to sec); skips empty conditions (meaning 0 trials); detects start time of an event and calculates its duration; and saves a .mat file with a BIDS compliant name. Additionally, it features subject filtering (processing only a predefined list of subjects) and supports the distribution of a universal protocol (for the face localizer task).

<br>

#### [`s01_get_design_matrix`](s01_get_design_matrix.m)

Creates a subject-specific explicit brain mask using tissue probability maps (GM + WM + CSF) to exclude ghost voxels and out-of-brain artifacts. Additionally, it generates the Design Matrix for each task and session, incorporating the 6 motion regressors. It relies on BIDS-compliant event files converted from .prt to .mat (see s00_convert_prt_to_spm).

<br>

#### [`s02_beta_estimation`](s02_beta_estimation.m)

Reads the Design Matrix (SPM.mat) for each subject and task, and runs the estimation algorithm (Classical - Restricted Maximum Likelihood). Generates the estimated regression coefficients (Beta images), the error variance image (ResMS), the analysis mask, and the estimated resels per voxel (RPV) image. To save disk space, individual volume residuals are not saved.

The residuals are not directly saved, but written in the header.

<br>

#### [`s03_contrasts`](s03_contrasts.m)

Reads the Design Matrix (SPM.mat) to extract column names and dynamically defines the statistical contrast vectors for the 1st-Level analysis, covering both task-main and task-localizer. This script automatically adapts to atypical subjects (missing runs or early phase transitions) and handles nuisance conditions (e.g., "excluded" or "NO_RESPONSE" trials) by assigning them a contrast weight of 0. Furthermore, it includes an automatic normalization step, ensuring all contrast weights are balanced for subsequent 2nd-Level group analyses.

Importantly, it skips contrasts lacking sufficient data (eg., subjects missing entire experimental phases) and enforces a strict ordering of universal contrasts to guarantee consistent SPM file indexing (con_XXXX.nii) across the entire sample, preventing mismatch errors during 2nd-Level group analysis. 

The generated outputs (con_\*.nii and spmT_\*.nii files) are saved and ready to be visualized and explored via the SPM Results GUI (or other tools like xjView).

This script includes two sanity check contrasts: one for visual activation (VIDEO > baseline) and one for motor activation (INVESTMENT > baseline).

<br>

#### [`s04_extra_design_quality`](s04_extra_design_quality.m)

This supplementary script evaluates the statistical quality and efficiency of the 1st-Level GLM design matrices. It was specifically developed to assess the impact of a short and fixed Inter-Stimulus Interval (ISI) between the VIDEO and DECISION phases on model collinearity. The primary goal was to validate whether the estimated parameters remain robust and reliable, despite this experimental design limitation.

Metrics used: 

- Correlation Matrices: *to identify specific pairwise collinearity between regressors;*

- Variance Inflation Factor (VIF): *to quantify the inflation of parameter variance;*

- Condition Number: *to assess the global instability of the design matrix;*

- Effective Degrees of Freedom (eDF): *to ensure sufficient statistical power;*

- Visual Overlap Plots: *to qualitatively inspect task regressor overlap.*

Note: The generated outputs and metrics are highly interdependent and, therefore, should be interpreted as a whole (holistically) rather than in isolation.

<br>

#### [`s05_export_results`](s05_export_results.m)

This script extracts results from the previously estimated SPM.mat through an interactive prompt that allows users to define custom statistical threshold parameters (p-value, adjustment method, and minimum cluster size). It automatically generates and exports the peak coordinates (.xls) and the thresholded brain maps (.nii) for all evaluated contrasts, including Conjunction Analyses. To facilitate visualization and reporting and prevent accidental overwrites, all outputs receive a dynamic threshold signature in their filename (eg., thr_p0p001_unc_k20) and are centralized into the '\derivatives\spm-statistics\1st-level-exports\\[task-name]' directory.

<br>

#### [`s06_01_roi_definition_marsbar`](s06_01_roi_definition_marsbar.m)

This script documents the procedure for defining subject-specific functional Regions of Interest (ROIs) using the MarsBaR toolbox for SPM12. This approach ensures functional precision by creating spherical ROIs centered on subject-specific peak activation coordinates (e.g., identifying individual pSTS from independent localizer scans), when available.

<br>

#### [`s06_02_roi_analysis`](s06_02_roi_analysis.m)

This script automates the extraction of mean beta values from the individualized MarsBaR ROIs across all subjects. It includes a custom extraction function based on Andrew Jahn's code [https://github.com/andrewjahn/SPM_Scripts/blob/master/Extract_ROI_Data.m], modified to support spatial alignment between the ROI and Contrast spaces.

It uses the functional contrast's affine matrix (Vcon.mat) to mathematically translate ROI coordinates to the exact voxel space of the functional images and automatically detects and removes absolute zeros (for example, caused by out-of-brain voxels) before calculating the mean. The results are compiled into a structured .csv file.
