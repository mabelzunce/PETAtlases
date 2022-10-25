import SimpleITK as sitk
import numpy as np
#import SitkImageManipulation as sitkExtra
import sys
import os
import ImageRegistration as reg
import time
import matplotlib.pyplot as plt
import ants

from SimpleITK import _SimpleITK, SimpleITK

# Add fsl to the PATH envirnoment variable:
fslPath = "/usr/local/fsl/bin"
#os.environ["PATH"] += os.pathsep + fslPath

basePath = "/media/martin/DATADRIVE1/ADNIdata/"
dataPath = basePath + "/ADNI/"
sliceToShow = 160

mriDataToProcess = ["Accelerated_Sagittal_MPRAGE", 'ADNI3_Accelerated_MPRAGE', 'Sag_Accel_IR-FSPGR','Accelerated_Sagittal_MPRAGE_MPR_Cor',
                    'Sagittal_3D_Accelerated_MPRAGE_REPEAT', 'REPEAT_Accelerated_Sagittal_MPRAGE', 'Accelerated_Sagittal_MPRAGE_L__R',
                    'ORIG_Accelerated_Sag_IR-FSPGR', 'Accelerated_Sagittal_IR-FSPGR', 'Accelerated_Sag_IR-FSPGR',
                    'Accelerated_Sagittal_MPRAGE_REPEAT', 'VWIP_Coronal_3D_Accelerated_MPRAGE', 'Accelerated_Sagittal_MPRAGE_MPR_Tra',
                    '3D_MPRAGE', 'Accelerated_Sagittal_MPRAGE_ND', 't1_fl2d_sag', 'AXIAL_RFORMAT_1',
                    'Accelerated_Sagittal_MPRAGE_Phase_A-P', 'Accelerated_Sagittal_MPRAGE_repeat', '3D_T1_SAG',
                    'Repeat_Accelerated_Sagittal_MPRAGE', 'Sagittal_3D_Accelerated_MPRAGE', 'Sagittal_3D_Accelerated_0_angle_MPRAGE', 'Accelerated_Sagittal_MPRAGE']
petDataTypeToProcess = ["ADNI3_av-1451__AC_", "ADNI3_FDG__AC_", "ADNI3_florbetapir__AC_", 'BRAIN_ADNI', 'ADNI3-TAU-2__AC_',
                        'ADNI_Brain_PET__Raw', 'ADNI3-AV45__AC_', 'ADNI3_AV-1451_6X5', 'ADNI_Brain_AC_3D',
                        'ADNI_Brain_PET__Raw_Tau', 'ADNI3_av-1451__AC_', 'ADNI3_florbetapir__AC_', 'ADNI2_FDG__AC_']

outputPath = basePath + "/ADNIproc/"
if not os.path.exists(outputPath):
    os.mkdir(outputPath)
else:
    pass

# Search for ADNI data
files = os.listdir(dataPath)
subjectNames = []
for filename in files:
    if os.path.isdir(dataPath + filename):
        subjectNames.append(filename)
# Get the list of scans available:
scanTypes = []
subjectNamesToProcess = []
for subjectName in subjectNames:
    # Look for what images are available:
    scanTypesThisSubject = os.listdir(dataPath + subjectName + "/")
    scanTypes.extend(scanTypesThisSubject)
    # Check if structural MRI and PET images are available:
    subjectHasMri = False
    subjectHasPet = False
    for scan in scanTypesThisSubject:
        if scan in mriDataToProcess:
            subjectHasMri = True
            break
    for scan in scanTypesThisSubject:
        if scan in petDataTypeToProcess:
            subjectHasPet = True
            break
    if subjectHasMri and subjectHasPet:
        subjectNamesToProcess.append(subjectName)

print('Scan types detected:')
print(set(scanTypes))
print('Subjects to process:')
print(subjectNamesToProcess)

sumImagesPET = []
for subjectName in subjectNamesToProcess:
    t1Images = []
    t1FilenamesNoExt = []
    for mriData in mriDataToProcess:
        if os.path.exists(dataPath + subjectName + "/" + mriData + "/"):
            pathThisMriSequence = dataPath + subjectName + "/" + mriData + "/"
            dates = os.listdir(pathThisMriSequence)
            for date in dates:
                direct = os.listdir(pathThisMriSequence + date)
                for dir in direct:
                    mriDataPath = pathThisMriSequence + date + "/" + dir
                    mriOutputDataPath = outputPath + subjectName + "/" + mriData + "/" + date + "/" + dir + "/"
                    if not os.path.exists(mriOutputDataPath):
                        os.makedirs(mriOutputDataPath)
                    # It should be only one:
                    mriFilenames = os.listdir(mriDataPath)
                    for filename in mriFilenames:
                        [filenamesNoExt, ext] = os.path.splitext(filename)
                        t1FilenamesNoExt.append(mriOutputDataPath + filenamesNoExt)
                        t1Images.append(sitk.ReadImage(os.path.join(mriDataPath, filename)))

            # Process the MRIs for all the dates, using the older as a reference:
            refImage = t1Images[0]
            refImage = sitk.Cast(refImage, sitk.sitkFloat32)
            sitk.WriteImage(t1Images[0], "{0}_reg_to_first_session.nii.gz".format(t1FilenamesNoExt[0]), True)
            for i in range(1, len(t1Images)):
                t1Images[i] = sitk.Cast(t1Images[i], sitk.sitkFloat32)
                resultReg = reg.RigidImageRegistration(t1Images[i], refImage, printLog=True)
                t1Images[i] = resultReg['image']
                sitk.WriteImage(t1Images[i], "{0}_reg_to_first_session.nii.gz".format(t1FilenamesNoExt[i]), True)
                # Extract brain:
                #os.system("bet {0} {1} -R -f 0.5 -g 0".format("{0}_reg_to_first_session".format(t1FilenamesNoExt[i]),
                #                                              "{0}_reg_to_first_session_brain".format(t1FilenamesNoExt[i])))

    for petData in petDataTypeToProcess:
        if os.path.exists(dataPath + subjectName + "/" + petData + "/"):
            pathThisPetTracer = dataPath + subjectName + "/" + petData + "/"
            dates = os.listdir(pathThisPetTracer)
            for date in dates:
                direct = os.listdir(pathThisPetTracer + date)
                for dir in direct:
                    petImages = []
                    petFilenamesNoExt = []
                    petDataPath = pathThisPetTracer + date + "/" + dir + "/"
                    petOutputDataPath = outputPath + subjectName + "/" + petData + "/" + date + "/" + dir + "/"
                    if not os.path.exists(petOutputDataPath):
                        os.makedirs(petOutputDataPath)
                    petFilenames = os.listdir(petDataPath)
                    # Read pet images for this tracer and date and register between them (in case there was motion) and sum them:
                    petImages = []
                    petFilenamesNoExt = []
                    for filename in petFilenames:
                        [filenamesNoExt, ext] = os.path.splitext(filename)
                        petFilenamesNoExt.append(filenamesNoExt)
                        petImages.append(sitk.ReadImage(os.path.join(petDataPath,filename)))

                    # Registration between frames, they are not saved. Only saved after registered to the T1 reference image:
                    refPetImage = petImages[0]
                    for i in range(1, len(petImages)):
                        resultReg = reg.RigidImageRegistration(petImages[i], refPetImage, printLog = True)
                        petImages[i] = resultReg['image']

                    # Now compute the sum and register all of them to the t1 used as a reference:
                    sumImage = petImages[0]
                    for image in petImages[1:]:
                        sumImage = sitk.Add(sumImage, image)
                    # Register to t1 using the sum and apply the transform to all the frames:
                    resultReg = reg.RigidImageRegistration(sumImage, sitk.Cast(refImage, sitk.sitkFloat32),
                                                           printLog=True)
                    sumImage = resultReg['image']
                    txPet2Mri = resultReg['tx']
                    # Write sum image:
                    sitk.WriteImage(sumImage, petOutputDataPath + subjectName + "_sum_reg_t1.nii.gz")
                    # Apply transform to each frame and save the image:
                    for i in range(0, len(petImages)):
                        petImages[i] = reg.ApplyRegTransform(petImages[i], txPet2Mri, refImage=refImage, interpolator=sitk.sitkLinear)
                        sitk.WriteImage(petImages[i], petOutputDataPath + petFilenamesNoExt[i] + "_reg_t1.nii.gz")

                    imageArraySum= sitk.GetArrayFromImage(sumImage)
                    imageArrayT1 = sitk.GetArrayFromImage(refImage)
                    sliceSum = imageArraySum[sliceToShow, :, :]
                    sliceT1 = imageArrayT1[sliceToShow, :, :]

                    plt.imshow(sliceT1, cmap='gray', alpha=1)
                    plt.imshow(sliceSum, cmap='hot', alpha=0.4)
                    plt.savefig(petOutputDataPath + subjectName + "_pet_t1")


