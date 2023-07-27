#! python3
from __future__ import print_function

import SimpleITK as sitk
import ImageRegistration as reg
import numpy as np
import sys
import os

outputPath = "D:\\Martin\\Personal\\UNSAM\\CursoNeuroimagenes\\TrabajosFinales\\NicolasFuentes\\ADNI\\002_S_5018\\RegisteredData\\"
if not os.path.exists(outputPath):
    os.mkdir(outputPath)

petImageFilename = "D:\\Martin\\Personal\\UNSAM\\CursoNeuroimagenes\\TrabajosFinales\\NicolasFuentes\\ADNI\\002_S_5018\\ADNI_Brain_PET__Raw_AV45\\2012-11-15_16_29_51.0\\I347148\\ADNI_002_S_5018_PT_ADNI_Brain_PET__Raw_AV45_br_raw_20121119110623877_305_S174962_I347148.nii"
mriImageFilename = "D:\\Martin\\Personal\\UNSAM\\CursoNeuroimagenes\\TrabajosFinales\\NicolasFuentes\\ADNI\\002_S_5018\\ADNI_002_S_5018_MR_MPRAGE_br_raw_20121112145218294_127_S174291_I346242.nii"

mni152Filename = "D:\\Martin\\Personal\\UNSAM\\CursoNeuroimagenes\\TrabajosFinales\\NicolasFuentes\\Atlas\\icbm_avg_152_t1_tal_nlin_symmetric_VI.mnc"

petImage = sitk.Cast(sitk.ReadImage(petImageFilename), sitk.sitkFloat32)
mriImage = sitk.Cast(sitk.ReadImage(mriImageFilename), sitk.sitkFloat32)
mriMni152Image = sitk.Cast(sitk.ReadImage(mni152Filename), sitk.sitkFloat32)

#mriMni152Image = sitk.Flip(mriMni152Image, [False,True,False])

sitk.WriteImage(petImage, outputPath + "PET.nii")
sitk.WriteImage(mriImage, outputPath + "MRI.nii")
sitk.WriteImage(mriMni152Image, outputPath + "MNI152.nii")

# Registration
resultsRegistration = reg.RigidImageRegistration(petImage, sitk.Cast(mriImage, sitk.sitkFloat32), printLog = True)
sitk.WriteImage(resultsRegistration["image"], outputPath + "regPET.nii")


# Normalize MRI into MNI152.
# Create a mask for MNI 152:
otsuSegmentation = sitk.OtsuMultipleThresholds(mriMni152Image, 3, 0, 128, False)
maskMNI152 = otsuSegmentation > 0
sitk.WriteImage(maskMNI152, outputPath + "maskMNI152.nii")

# Two steps, first affine transform, then nonlinear:
resultsRigidNormalization = reg.RigidImageRegistration(mriImage, mriMni152Image, printLog = True)
sitk.WriteImage(resultsRigidNormalization["image"], outputPath + "normalizedRigidMRI.nii")
resultsAffineNormalization = reg.AffineImageRegistration(resultsRigidNormalization["image"], mriMni152Image, printLog = True)
sitk.WriteImage(resultsAffineNormalization["image"], outputPath + "normalizedAffineMRI.nii")

# Now the nonlinear registration:
resultsNonlinearRegistration = reg.NonlinearImageRegistration(resultsAffineNormalization["image"], mriMni152Image, printLog = True)

sitk.WriteImage(resultsNonlinearRegistration["image"], outputPath + "normalizedMRI.nii")