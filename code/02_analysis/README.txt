##################################################################################
#									         #
#  The code was developed and tested on a PC with the following specifications:  #
#									         #
#  Software: MATLAB R2024b (Update 4 - 24.2.0.2833386)			         #
#  	     SPM12 (7771)							 #
#  OS: Microsoft Windows 10 (64-bit)					         #
#  CPU: Intel(R) Core(TM) i5-10300H CPU @ 2.50GHz			         #
#  RAM: 16GB								         #
#  GPU: NVIDIA GeForce RTX 2060 with Max-Q Design			         #
#									         #
##################################################################################

Note*: Scripts not specifying time of running took only a couple of minutes. Time is only specified for scripts that took longer to run.

--------------------------------------------- s00_convert_prt_to_spm ---------------------------------------------

The function prt_to_spm(), using the function read_prt(), reads multiple .prt files from a selected folder; confirms the resolution of time (converting msec to sec); skips empty conditions (meaning 0 trials); detects start time of an event and calculates its duration; and saves a .mat file with a BIDS compliant name. Additionally, it features subject filtering (processing only a predefined list of subjects) and supports the distribution of a universal protocol (for the face localizer task).


--------------------------------------------- s01_get_design_matrix --------------------------------------------- 

Creates a subject-specific explicit brain mask using tissue probability maps (GM + WM + CSF) to exclude ghost voxels and out-of-brain artifacts. Additionally, it generates the Design Matrix for each task and session, incorporating the 6 motion regressors. It relies on BIDS-compliant event files converted from .prt to .mat (see s00_convert_prt_to_spm).


--------------------------------------------- s02_beta_estimation ---------------------------------------------

Reads the Design Matrix (SPM.mat) for each subject and task, and runs the estimation algorithm (Classical - Restricted Maximum Likelihood). Generates the estimated regression coefficients (Beta images), the error variance image (ResMS), the analysis mask, and the estimated resels per voxel (RPV) image. To save disk space, individual volume residuals are not saved.
The residuals are not directly saved, but written in the header.


--------------------------------------------- s03_contrasts ---------------------------------------------

Reads the Design Matrix (SPM.mat) to extract column names and dynamically defines the statistical contrast vectors for the 1st-Level analysis, covering both task-main and task-localizer. This script automatically adapts to atypical subjects (missing runs or early phase transitions) and handles nuisance conditions (e.g., "excluded" or "NO_RESPONSE" trials) by assigning them a contrast weight of 0. Furthermore, it includes an automatic normalization step, ensuring all contrast weights are balanced for subsequent 2nd-Level group analyses.
The generated outputs (con_*.nii and spmT_*.nii files) are saved and ready to be visualized and explored via the SPM Results GUI (or other tools like xjView).
This script includes two sanity check contrasts: one for visual activation (VIDEO > baseline) and one for motor activation (INVESTMENT > baseline).