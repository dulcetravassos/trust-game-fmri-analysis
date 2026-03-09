##################################################################################
#									         #
#  The code was developed and tested on a PC with the following specifications:  #
#									         #
#  Software: MATLAB R2024b (Update 4 - 24.2.0.2833386)			         #
#  	     SPM12 (7771)							 #
#	     Ubuntu v24.04.5 LTS						 #
#	     FSL v6.0.7.19 (FUGUS)						 #
#  OS: Microsoft Windows 10 (64-bit)					         #
#  CPU: Intel(R) Core(TM) i5-10300H CPU @ 2.50GHz			         #
#  RAM: 16GB								         #
#  GPU: NVIDIA GeForce RTX 2060 with Max-Q Design			         #
#									         #
##################################################################################

Note*: Scripts not specifying time of running took only a couple of minutes. Time is only specified for scripts that took longer to run.

--------------------------------------------- s00_dicom_to_nifti --------------------------------------------- 

Converts raw DICOM MRI data (anatomical, functional, fieldmaps) into NIfTI files suitable for preprocessing and analysis in SPM12. Saves a JSON file with metadata. Output filenames follow BIDS conventions, when applicable.


--------------------------------------------- s00_convert_prt_to_spm ---------------------------------------------

The function prt_to_spm(), using the function read_prt(), reads multiple .prt files from a selected folder; confirms the resolution of time (converting msec to sec); skips empty conditions (meaning 0 trials); detects start time of an event and calculates its duration; and saves a .mat file with a BIDS compliant name. 


--------------------------------------------- s01_slice_timing --------------------------------------------- 

Slice Timing Correction script adapted to deal with subjects with reverse slice order and variable volumes. Saves output in derivatives folder with a JSON file (BIDS friendly). 
Time: ~15 minutes per subject (Main Task + Face Localizer).


--------------------------------------------- s02_set_the_origin --------------------------------------------- 

Makes a copy of the original/raw anatomic images to the correct BIDS derivative folder and opens that copy on the SPM display, to allow the user to set the origin (AC-PC).


--------------------------------------- s03_motion_correction_realignment ---------------------------------------

Performs the SPM12 operation "Realign: Estimate & Reslice" on slice-timed data ('a...' files). The "Estimate" calculates the motion parameters (rp_*.txt) and the "Reslice" applies these parameters and writes new 'r...' files and generates a mean image (mean*.nii).
Time: ~25 minutes per subject (Main Task + Face Localizer).

Note: Reslicing is performed at this stage to provide physical aligned files required for Distortion Correction in FSL.


------------------------------------------ s04_get_magnitude_substitute ------------------------------------------

Creates a 'fake magnitude' (surrogate) by skull-stripping the T1w image for subjects missing magnitude files, since performing Distortion Correction in FSL requires complete fieldmaps (magnitude + phasediff).
The process involves Segmentation (generates tissue probability maps for grey matter, white matter and CSF) and ImCalc (applies the expression "i1.*((i2+i3+i4)>0.5)" to keep only voxels with >50% probability of actually being brain tisse).
Finally, the alignment to the phasediff space is done in a 2-step coregistration process to avoid SPM crashes:
1) Estimate & Reslice to the Mean Functional image (aligns the structural mask to the subject's functional head position using mutual information);
2) Write (Reslice ONLY) to the Native Phasediff (forcing the functional-aligned T1w into the exact spatial grid and voxel dimensions of the raw phasediff without attempting mutual information estimation).
This script automatically cleans up the intermediate files generated mid-operation (e.g., c1, c2, m_*) to prevent overwriting conflicts in later pipeline stages.


---------------------------------------------- s05_01_distortion_correction_fsl ----------------------------------------------

Processes the raw phasediff and magnitude files to generate a continuous fieldmap (in rad/s), coregisters it to the functional space, and applies it to correct for B0 magnetic field inhomogeneities.
This script performs several key corrections strictly using FSL via a WSL interpreter:
1) SIEMENS Scaling: Divides the raw Siemens phasediff by 2 using 'fslmaths' to correct the amplitude scale back to the standard 4096 expected by FSL;
2) Skull-stripping: Applies FSL 'bet' to extract the brain from the real magnitude files to improve fieldmap estimation;
3) Slice Dimension: Uses FSL 'flirt' to truncate the magnitude image when the scanner reconstructs it with +1 slice compared to the phasediff (common in cases with magnitude1 or magnitude2 instead of regular magnitude);
4) Fieldmap Preparation: Runs 'fsl_prepare_fieldmap' to compute the unwrapped fieldmap in rad/s ('fmap_rads_*.nii.gz') and cleans residual NaNs (fslmaths);
5) Functional Coregistration: Uses FSL 'flirt' to calculate the transformation matrix from the magnitude image to the realigned BOLD functional image, and applies this matrix to the fieldmap to create a functionally-aligned fieldmap ('rfmap_rads_*.nii.gz');
6) Unwarping: Applies the coregistered fieldmap to the realigned BOLD functional images using FSL FUGUE, outputting the final distortion-corrected images ('ura*.nii.gz').

NOTE: Being a .m file containing bash code, you are supposed to copy-paste the code lines for each subject to a WSL interpreter (Linux) instead of running the script itself on Matlab.


---------------------------------------------- s05_02_unzip_create_json_spm ----------------------------------------------

Bridges the FSL outputs back to the SPM environment. It automatically unzips the FSL-generated *.nii.gz files (rfmap_rads* and ura*) into standard .nii files.
Additionally, it generates BIDS-compliant JSON sidecars for both the fieldmaps and the new unwarped functional images. For the functional data, it reads the original 'ra*.json' metadata and appends the appropriate Distortion Correction tags and information.


--------------------------------------------- s06_coregistration --------------------------------------------- 

Matches the anatomical image to the mean functional image. This script is "Estimate Only" and, therefore, does not create a new 'r*' anatomical file, but updates the header of the existing T1w image. This avoids an extra interpolation and preserves the high resolution of the anatomical image for subsequent steps. This script also updates the JSON sidecar for the T1w file.


------------------------------------------------ s07_segmentation ------------------------------------------------ 

Partitions the coregistered anatomical image into different tissues (Grey Matter, White Matter, CSF, etc.). Generates the spatial deformation parameters (Forward Deformation Field, 'y_*') needed to normalize both the anatomical and functional images to MNI space later, and a bias-corrected structural image ('m*).


--------------------------------------------- s08_01_normalization_func --------------------------------------------- 

Normalizes the functional images to MNI space, by applying the Forward Deformation Field (y_*) generated during the Segmentation.
Time: ~17 minutes per subject (Main Task + Face Localizer).


--------------------------------------------- s08_02_normalization_anat ---------------------------------------------

Similar to the previous script, but applies the deformation field to the bias-corrected anatomical image (m*), resulting in the normalized structural image (wm*).


------------------------------------------------- s09_smoothing -------------------------------------------------

Applies a spatial Gaussian filter to the normalized functional images (wura*), increasing the Signal-to-Noise Ratio and 
accommodating anatomical variations between subjects for group stats.
Time: ~30 minutes per subject (Main Task + Face Localizer).