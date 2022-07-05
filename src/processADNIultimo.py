import SimpleITK as sitk
import numpy as np
#import SitkImageManipulation as sitkExtra
import sys
import os
import ImageRegistration as reg
import time
import matplotlib.pyplot as plt

from SimpleITK import _SimpleITK, SimpleITK

dataPath = "C:\\Users\\Ana Canosa\\Desktop\\Ana\\ADNI\\"

mriDataToProcess = ["Accelerated_Sagittal_MPRAGE"]
petDataTypeToProcess = ["ADNI3_av-1451__AC_", "ADNI3_FDG__AC_", "ADNI3_florbetapir__AC_"]

outputPath ='C:\\Users\\Ana Canosa\\Desktop\\Ana\\ADNI_proc\\'
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
                refImage = sitk.Cast(refImage, sitk.sitkFloat32)

                sitk.WriteImage(t1Image[0], mriOutputDataPath + "{0}_reg.nii".format(t1FilenamesNoExt[0]))
                for i in range(1, len(t1Image)):
                    t1Image[i] = sitk.Cast(t1Image[i], sitk.sitkFloat32)
                    resultReg = reg.RigidImageRegistration(t1Image[i], refImage, printLog=True)
                    t1Image[i] = resultReg['image']
                    sitk.WriteImage(t1Image[i], mriOutputDataPath + "{0}_reg.nii".format(t1FilenamesNoExt[i]))

    lista = os.listdir(dataPath + subjectName + "\\")
    for petData in petDataTypeToProcess:
        for i in lista:
            if i == petData:
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

                            imageArrayPetimages = sitk.GetArrayFromImage(petImages[i])
                            imageArrayPetref = sitk.GetArrayFromImage(petImages[0])

                            print(imageArrayPetimages.shape, imageArrayPetref.shape)

                            # Que slice muestro
                            slice = round(imageArrayPetimages.shape[0]/2)
                            ArraypetImages = imageArrayPetimages[slice, :, :]
                            ArraypetRef = imageArrayPetref[slice, :, :]

                            plt.imshow(ArraypetRef, cmap='gray', alpha=1)
                            plt.imshow(ArraypetImages, cmap='Blues_r', alpha=0.4)
                            plt.savefig(petOutputDataPath + subjectName + "PETimage" + str(i))
                            #plt.show()



                        #Add images:
                        sumImage = petImages[0]
                        for image in petImages[1:]:
                            sumImage = sitk.Add(sumImage, image)
                        sumImagesPET.append(sumImage)

                        # Write images:
                        sitk.WriteImage(sumImage, petOutputDataPath + subjectName + "_sum_reg.nii")

                # Register to T1:
                resultReg = reg.RigidImageRegistration(sumImage, sitk.Cast(t1Image[0], sitk.sitkFloat32), printLog=True)
                sumImageT1 = resultReg['image']
                # Write images:
                sitk.WriteImage(sumImageT1, mriOutputDataPath + subjectName + "_sum_reg_t1.nii")

                imageArraysumT1 = sitk.GetArrayFromImage(sumImageT1)
                imageArrayT1 = sitk.GetArrayFromImage(t1Image[0])

                print(imageArraysumT1.shape, imageArrayT1.shape)

                #Que slice muestro
                ArraysumImageT1 = imageArraysumT1[160, :, :]
                ArrayT1 = imageArrayT1[160, :, :]

                plt.imshow(ArrayT1, cmap='gray', alpha=1)
                plt.imshow(ArraysumImageT1, cmap='hot', alpha=0.4)
                plt.savefig(mriOutputDataPath + subjectName + "T1")
                #plt.show()






