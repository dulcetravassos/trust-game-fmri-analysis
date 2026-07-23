### System Specifications
The code in this folder was developed and tested on a PC with the following specifications:

*  **Software:** MATLAB R2024b (Update 4 - 24.2.0.2833386), SPM12 (7771), MarsBaR toolbox (v0.45)
*   **OS:** Microsoft Windows 10 (64-bit)
*   **CPU:** Intel(R) Core(TM) i5-10300H CPU @ 2.50GHz
*   **RAM:** 16GB
*   **GPU:** NVIDIA GeForce RTX 2060 with Max-Q Design

> ***Note:** Scripts not specifying time of running took only a couple of minutes. Time is only specified for scripts that took longer to run.*

---


#### [`s00_convert_prt`](s00_convert_prt.m)

Translates BrainVoyager protocol files (`.prt`) into SPM-readable `.mat` format and BIDS-compliant `.tsv` event files. It features a mechanism that pools all unique experimental conditions across the dataset to generate a master JSON directory at the root of the rawdata folder, adhering to the BIDS principles.

The function `prt_to_spm()`, using the function `read_prt()`, reads multiple .prt files from a selected folder; confirms the resolution of time (converting msec to sec); skips empty conditions (meaning 0 trials); detects start time of an event and calculates its duration; and saves a .mat file with a BIDS compliant name. Additionally, it features subject filtering (processing only a predefined list of subjects) and supports the distribution of a universal protocol (for the face localizer task).

<br>

#### [`s00_reslice_normalize_rois`](s00_reslice_normalize_rois.m)

This script integrates FreeSurfer anatomical Regions of Interest (ROIs) with the SPM12 pipeline. It first reslices the ROIs to match the native T1w spatial dimensions and then normalizes them to MNI space, using the subject-specific Forward Deformation Fields (`y*`) generated during the structural segmentation step of the preprocessing.

This script enforces Nearest Neighbour interpolation to preserve the integrity of binary masks and organizes the final outputs into subject-specific derivative folders.

<br>

#### [`s00_roi_definition_marsbar`](s00_roi_definition_marsbar.m)

This script documents the procedure for defining subject-specific functional Regions of Interest (ROIs) using the MarsBaR toolbox for SPM12. This approach ensures functional precision by creating spherical ROIs centered on subject-specific peak activation coordinates (e.g., identifying individual pSTS from independent localizer scans), when available.

Additionally, this script automates the computation of a group average structural T1w image to anatomically guide and validate the chosen ROI radius.

<br>

#### [`s01_get_design_matrix`](s01_get_design_matrix.m)

Creates a subject-specific explicit brain mask using tissue probability maps (GM + WM + CSF) to exclude ghost voxels and out-of-brain artifacts. Additionally, it generates the Design Matrix for each task and session, incorporating the 6 motion regressors. It relies on BIDS-compliant event files converted from .prt to .mat (see [`s00_convert_prt`](s00_convert_prt.m)).

<br>

#### [`s02_beta_estimation`](s02_beta_estimation.m)

Reads the Design Matrix (`SPM.mat`) for each subject and task, and runs the estimation algorithm (Classical - Restricted Maximum Likelihood). Generates the estimated regression coefficients (Beta images), the error variance image (ResMS), the analysis mask, and the estimated resels per voxel (RPV) image. To save disk space, individual volume residuals are not saved.

The residuals are not directly saved, but written in the header.

<br>

#### [`s03_contrasts`](s03_contrasts.m)

Reads the Design Matrix (`SPM.mat`) to extract column names and dynamically defines the statistical contrast vectors for the 1st-Level analysis, covering both task-main and task-localizer. This script automatically adapts to atypical subjects (missing runs or early phase transitions) and handles nuisance conditions (e.g., "excluded" or "NO_RESPONSE" trials) by assigning them a contrast weight of 0. Furthermore, it includes an automatic normalization step, ensuring all contrast weights are balanced for subsequent 2nd-Level group analyses.

Importantly, it skips contrasts lacking sufficient data (eg., subjects missing entire experimental phases) and enforces a strict ordering of universal contrasts to guarantee consistent SPM file indexing (`con_XXXX.nii`) across the entire sample, preventing mismatch errors during 2nd-Level group analysis. 

The generated outputs (`con_*.nii` and `spmT_*.nii` files) are saved and ready to be visualized and explored via the SPM Results GUI (or other tools like xjView).

This script includes two sanity check contrasts: one for visual activation (VIDEO > baseline) and one for motor activation (INVESTMENT > baseline).

<br>

#### [`s04_get_2nd_level_design_matrix`](s04_get_2nd_level_design_matrix.m)

Automates the specification of second-level one-sample t-test Design Matrices (SPM.mat) for each functional contrast defined in the first-level analysis. It systematically harvests subject-specific contrast maps (`con_*.nii`) into dedicated directories and includes defensive file-checking to handle missing subject data gracefully.

<br>

#### [`s05_2nd_level_beta_estimation`](s05_2nd_level_beta_estimation.m)

Reads the Design Matrix (`SPM.mat`) for each contrast, and runs the estimation algorithm using Restricted Maximum Likelihood. Generates the estimated group regression coefficients (`beta_*.nii`), the error variance image (`ResMS.nii`), the analysis mask (`mask.nii`), and the estimated resels per voxel (`RPV.nii`).

To save disk space, the residuals are not directly saved, but written in the header.

<br>

#### [`s06_get_group_roi`](s06_get_group_roi.m)

Processes subject-specific bilateral anatomical ROIs into unilateral consensus masks optimized for group-level analyses in SPM. For hemisphere separation, this script directly loads NIfTI volumes using `spm_vol` and `spm_read_vols`, applies the image's affine transformation matrix (`V.mat`) to map 3D voxel indices into real-world MNI space, and isolates the hemisphere volumes using the rule `x<0` for Left and `x>0` for Right. 

Additionally, to prevent statistical power degradation in Small Volume Correction (SVC), masks are summed across subjects and dynamically thresholded at 50% spatial overlap. A voxel is only retained in the final consensus mask ('*L_avg.nii' or '*R_avg.nii') if at least 10 out of 20 subjects share anatomical assignment at that MNI coordinate.

<br>

#### [`s07_extra_design_quality`](s07_extra_design_quality.m)

This supplementary script evaluates the statistical quality and efficiency of the 1st-Level GLM design matrices. It was specifically developed to assess the impact of a short and fixed Inter-Stimulus Interval (ISI) between the VIDEO and DECISION phases on model collinearity. The primary goal was to validate whether the estimated parameters remain robust and reliable, despite this experimental design limitation.

Metrics used: 

- Correlation Matrices: *to identify specific pairwise collinearity between regressors;*

- Variance Inflation Factor (VIF): *to quantify the inflation of parameter variance;*

- Condition Number: *to assess the global instability of the design matrix;*

- Effective Degrees of Freedom (eDF): *to ensure sufficient statistical power;*

- Visual Overlap Plots: *to qualitatively inspect task regressor overlap.*

Note: The generated outputs and metrics are highly interdependent and, therefore, should be interpreted as a whole (holistically) rather than in isolation.

<br>

#### [`s08_export_results`](s08_export_results.m)

This script extracts results from the previously estimated SPM.mat through an interactive prompt that allows users to define custom statistical threshold parameters (p-value, adjustment method, and minimum cluster size). It automatically generates and exports the peak coordinates (.xls) and the thresholded brain maps (.nii) for all evaluated contrasts, including Conjunction Analyses. To facilitate visualization and reporting and prevent accidental overwrites, all outputs receive a dynamic threshold signature in their filename (eg., thr_p0p001_unc_k20) and are centralized into the '\derivatives\spm-statistics\1st-level-exports\\[task-name]' directory.

<br>

#### [`s09_roi_analysis`](s09_roi_analysis.m)

This script provides an interactive interface to extract mean beta values for a user-selected ROI, laterality, and functional contrast, across all subjects. It supports both individualized spherical ROIs (generated via MarsBar) and anatomical subcortical ROIs (from FreeSurfer). 

It features a custom extraction function adapted from [`Andrew Jahn's code`](https://github.com/andrewjahn/SPM_Scripts/blob/master/Extract_ROI_Data.m), modified to support spatial alignment between the ROI and Contrast spaces, using the functional contrast's affine matrix (`Vcon.mat`) to mathematically translate ROI coordinates to the exact voxel space of the functional images. The script automatically filters absolute zeros (for example, caused by out-of-brain voxels) before calculating the mean value. 

The extracted data is compiled into a single structured `.csv` file. Additionally, the script performs a One-Sample T-Test against zero across valid subjects, printing the statistical summary (t-statistic, p-value, 95% CI, mean, SD, and Cohen's d) directly to the console and saving it as a .txt report inside the `results/` subfolder.

It supports both unilateral and bilateral images. To process bilateral images, it applies an automated spatial filter based on standard MNI coordinates to isolate the target hemisphere (where x < 0 defines the left hemisphere, and x > 0 the right hemisphere).

<br>

#### [`s09_roi_analysis_batch`](s09_roi_analysis_batch.m)

This script automates the full extraction of mean beta values across all subjects, regions, lateralities, and functional contrasts in a single run, eliminating the need for manual user input. It shares the same core spatial transformation and zero-filtering as [`s09_roi_analysis`](s09_roi_analysis.m), ensuring complete consistency across spatial states. 

It iteratively generates dedicated and structured `.csv` files for every individual ROI and contrast combination. Furthermore, it automatically computes a One-Sample T-Test against zero for each condition, exporting individual statistical summaries (`.txt`) and a consolidated summary table (`.csv`) per contrast into the `results/` subfolder.
