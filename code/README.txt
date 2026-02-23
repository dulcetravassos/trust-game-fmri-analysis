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

Processes the raw phasediff and magnitude files to generate a continuous fieldmap (in rad/s) and applies it directly to the functional images to correct for B0 magnetic field inhomogeneities.
This script performs several key corrections strictly within the Native space using FSL:
1) SIEMENS Scaling Bug: Divides the raw Siemens phasediff by 2 using 'fslmaths' to correct the amplitude scale back to the standard 4096 expected by FSL;
2) Skull-stripping: Applies FSL 'bet' to extract the brain from the real magnitude files to improve fieldmap estimation;
3) SIEMENS Slice Dimension Bug: Uses FSL 'flirt' to truncate the magnitude image when the scanner reconstructs it with +1 slice compared to the phasediff (common in cases with magnitude1 or magnitude2 instead of regular magnitude);
4) Fieldmap Preparation: Runs 'fsl_prepare_fieldmap' to compute the unwrapped fieldmap in rad/s ('fmap_rads_*.nii.gz') and cleans residual NaNs (fslmaths);
5) Unwarping: Applies the generated fieldmap to the realigned BOLD functional images using FSL FUGUE, outputting the distortion-corrected images ('ura*.nii.gz').
Being a .m file containing bash code, you are supposed to copy-paste the code lines for each subject to a WSL interpreter (Linux) instead of running the script itself on Matlab.


---------------------------------------------- s05_02_unzip_create_json_spm ----------------------------------------------

Bridges the FSL outputs back to the SPM environment. It automatically unzips the FSL-generated *.nii.gz files (fmap_rads* and ura*) into standard .nii files.
Additionally, it generates BIDS-compliant JSON sidecars for both the fieldmaps and the new unwarped functional images. For the functional data, it reads the original 'ra*.json' metadata and appends the appropriate Distortion Correction tags.

