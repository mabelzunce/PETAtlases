import SimpleITK as sitk
import numpy as np
#import SitkImageManipulation as sitkExtra
import sys
import os
import ImageRegistration as reg
import time

from SimpleITK import _SimpleITK
dataPath = "C:\\Users\\ecyt\\Desktop\\Ana\\ADNI\\"

mriDataToProcess = ["Accelerated_Sagittal_MPRAGE"]
petDataTypeToProcess = ["ADNI3_av-1451__AC_", "ADNI3_FDG__AC_", "ADNI3_florbetapir__AC_"]

outputPath ='C:\\Users\\ecyt\\Desktop\\Ana\\ADNI_proc\\'
if not os.path.exists(outputPath):
    os.mkdir(outputPath)

# Search for ADNI data
files = os.listdir(dataPath)
subjectNames = []
for filename in files:
    if os.path.isdir(dataPath + filename):
        subjectNames.append(filename)

sumImagesPET = []
for subjectName in subjectNames:
    for mriData in mriDataToProcess:
        dates = os.listdir(dataPath + subjectName + "\\" + mriData + "\\")
        for date in dates:
            direct = os.listdir(dataPath + subjectName + "\\" + mriData + "\\" + date)
            for dir in direct:
                mriDataPath = dataPath + subjectName + "\\" + mriData + "\\" + date + "\\" + dir
                mriOutputDataPath = outputPath + subjectName + "\\" + mriData + "\\" + date + "\\" + dir + "\\"
                if not os.path.exists(mriOutputDataPath):
                    os.makedirs(mriOutputDataPath)
                mriFilenames = os.listdir(mriDataPath)

                # t1Image read  t1
                t1Image = []
                t1FilenamesNoExt = []
                for filename in mriFilenames:
                    [filenamesNoExt, ext] = os.path.splitext(filename)
                    t1FilenamesNoExt.append(filenamesNoExt)
                    t1Image.append(sitk.ReadImage(os.path.join(mriDataPath, filename)))

                #write t1 output path
                refImage = t1Image[0]
                sitk.WriteImage(t1Image[0], mriOutputDataPath + "{0}_reg.nii".format(t1FilenamesNoExt[0]))
                for i in range(1, len(t1Image)):
                    resultReg = reg.RigidImageRegistration(t1Image[i], refImage, printLog=True)
                    t1Image[i] = resultReg['image']
                    sitk.WriteImage(t1Image[i], mriOutputDataPath + "{0}_reg.nii".format( t1FilenamesNoExt[i]))

    for petData in petDataTypeToProcess:
        dates = os.listdir(dataPath + subjectName + "\\" + petData + "\\")
        for date in dates:
            direct = os.listdir(dataPath + subjectName + "\\" + petData + "\\" + date)
            for dir in direct:
                petDataPath = dataPath + subjectName + "\\" + petData + "\\" + date + "\\" + dir
                petOutputDataPath = outputPath + subjectName + "\\" + petData + "\\" + date + "\\" + dir + "\\"
                if not os.path.exists(petOutputDataPath):
                    os.makedirs(petOutputDataPath)
                petFilenames = os.listdir(petDataPath)

                # Read pet images
                petImages = []
                petFilenamesNoExt = []
                for filename in petFilenames:
                    [filenamesNoExt, ext] = os.path.splitext(filename)
                    petFilenamesNoExt.append(filenamesNoExt)
                    petImages.append(sitk.ReadImage(os.path.join(petDataPath,filename)))

                refImage = petImages[0]
                sitk.WriteImage(petImages[0], petOutputDataPath + "{0}_reg.nii".format(petFilenamesNoExt[0]))
                for i in range(1, len(petImages)):
                    resultReg = reg.RigidImageRegistration(petImages[i], refImage, printLog = True)
                    petImages[i] = resultReg['image']
                    sitk.WriteImage(petImages[i], petOutputDataPath + "{0}_reg.nii".format(petFilenamesNoExt[i]))

                #Add images:
                sumImage = petImages[0]
                for image in petImages[1:]:
                    sumImage = sitk.Add(sumImage, image)
                sumImagesPET.append(sumImage)

                # Write images:
                sitk.WriteImage(sumImage, petOutputDataPath + subjectName + "_sum_reg.nii")

                # Register to T1:
                sumImageT1 = reg.RigidImageRegistration(sumImage, t1Image, printLog=True)
                # Write images:
                sitk.WriteImage(sumImageT1, mriOutputDataPath + subjectName + "_sum_reg_t1.nii")






