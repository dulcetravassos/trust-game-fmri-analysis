# Short Title: Social Reversal Learning
## Title: Learning and relearning to trust in different social contexts: an fMRI study

**Contributors:** Dulce Travassos

**Date created:** January 2026

**Last updated:** April 2026

**Identifer:** DOI [xxxxx]

**Category:** Project

**Code License:** MIT

**Description:** This repository contains the complete pipeline for fMRI data preprocessing and analysis in SPM for the [xxxx] study.

This repository consists of a SPM project executed primarily in MATLAB, with (xxx) custom scripts required to replicate the results from the [xxx] study. Output files and directory structures follow the Brain Imaging Data Structure (BIDS) naming convention. For a detailed description of all folders and files, please refer to the Repository Structure section below. 
To execute this pipeline, please ensure that MATLAB, SPM12, and FSL (versions specified below) are installed. The scripts are numbered sequentially in the order that they should be run. The data either needed to run these scripts or created by these scripts is available at [xxx]. 
For any further information regarding this repository, please contact: Dulce Travassos, email: uc2021216844 [at] student [dot] uc [dot] pt.

<br>

## Repository Structure (Information about folders and files within):
- **01_preprocessing**: Contains all the sequential scripts required to take the raw/defaced BIDS-formatted DICOM files to fully processed NIfTI images ready for statistical analysis.
  - **s00_dicom_to_nifti.m**: Converts raw DICOM MRI data to BIDS-compliant NIfTI files.
  - **s01_slice_timing.m**: Performs Slice Timing Correction (adapted to deal with damaged subjects with reverse slice order and variable volumes).
  - **s02_set_the_origin.m**: Allows to manually set the AC-PC origin on structural images.
  - **s03_motion_correction_realignment.m**: Realigns functional images to correct for head motion.
  - **s04_get_magnitude_substitute.m**: Creates a 'fake magnitude' (surrogate) for subjects missing complete fieldmap data (magnitude + phasediff).
  - **s05_01_distortion_correction_fsl.m**: Corrects B0 magnetic field geometric inhomogeneities using FSL FUGUE.
  - **s05_02_unzip_create_json_spm.m**: Integrates the FSL outputs back into the SPM/BIDS environment.
  - **s06_coregistration.m**: Aligns the anatomical T1w image to the mean functional image.
  - **s07_segmentation.m**: Partitions the coregistered anatomical image into different tissue classes and generates the deformation fields necessary to normalize to MNI space.
  - **s08_01_normalization_func.m**: Normalizes the functional images to standard MNI space.
  - **s08_02_normalization_anat.m**: Normalizes the anatomical images and tissue probability maps to MNI space.
  - **s09_smoothing.m**: Applies a spatial Gaussian filter to the normalized functional images to increase the Signal-to-Noise Ratio.
- **02_analysis**: Contains scripts for setting up, estimating, and evaluating the 1st and 2nd-level General Linear Models (GLMs).
  - **s00_convert_prt_to_spm.m**: Converts BrainVoyager .prt logfiles to SPM-readable .mat event files.
  - **s01_get_design_matrix.m**: Generates subject-specific Design Matrices and explicit brain masks.
  - **s02_beta_estimation.m**: Runs the GLM estimation algorithm to generate the regression coefficients (Beta images).
  - **s03_contrasts.m**: Dynamically defines and computes the 1st-level statistical contrast vectors.
  - **s04_extra_design_quality.m**: Evaluates the statistical efficiency and multicollinearity of the design matrices.
  - **s05_export_results.m**: Extracts automatically 1st-level statistics, exporting peak coordinates tables (.xls) and thresholded brain maps (.nii) for main contrasts and conjunction analyses.

<br>

## Environment 

### Software:

**Windows Environment:**

* **MatLab**: R2024b (Update 4 - 24.2.0.2833386)

* **SPM12:** Release 7771

**WSL (Linux) Environment:**

* **OS**: Ubuntu v24.04.5 LTS

* **FSL:** v6.0.7.19 *(specifically `fugue` for fieldmap unwarping and `bet` for magnitude skull-stripping)*

### Hardware:

* **OS:** Microsoft Windows 10 (64-bit)

* **CPU:** Intel(R) Core(TM) i5-10300H CPU @ 2.50GHz

* **RAM:** 16GB

* **GPU:** NVIDIA GeForce RTX 2060 with Max-Q Design
