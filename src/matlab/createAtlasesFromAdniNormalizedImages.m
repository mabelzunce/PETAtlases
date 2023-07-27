clear all
close all

dataPartitionPath = '/data/'; %'D:/'
adniPartitionPath = '/data_imaging/'; %'F:/'
% Load data:
loadData = 0;
%% ADD PATHS
addpath([dataPartitionPath 'UNSAM/Brain/dicm2nii/'])
addpath(genpath([dataPartitionPath 'UNSAM/Brain/DPABI_V6.2_220915/']))
addpath([dataPartitionPath 'UNSAM/Brain/spm12/spm12/'])
addpath([dataPartitionPath 'UNSAM/Brain/DPABI_V6.2_220915/DPARSF/'])

/home/martin/data_imaging/ADNIdata/FDG/ADNI2_FDG_T1/Processed/FinalImages/002_S_5018/
%% PATHS AND FILENAMES
adniPath = [adniPartitionPath '/ADNIdata/FDG/ADNI2_FDG_T1/'];
adniDicomPath = [adniPath '/ADNI/'];
adniProcessedPath = [adniPath '/Processed/'];
normalizedDataSubfolder = 'ANTs';

outputPath = [adniPath '/Atlases/'];
if ~isdir(outputPath)
    mkdir(outputPath)
end

% ADNI DATABASE COLLECTION
filenameADNICollection = 'ADNI2_FDG_T1_6_05_2023.csv';
petNormalizedFilename = 'PET_Norm_MNI_152_ANT.nii.gz';
t1NormalizedFilename = 'T1_Norm_MNI_152_ANT1Warp.nii.gz';
segNormalizedFilename = 'Aseg_Norm_MNI_152_ANT.nii.gz';
format = '.nii.gz';
dcmHeadersFilename = 'dcmHeaders.mat';

% Load adni dicom collection csv:
adniCollectionData = readtable([adniPath filenameADNICollection]);

%% CASES TO PROCESS
processedSubjects = {};
processedSubjectsPetFilenames = {};
j = 1;

dirPath = dir(adniProcessedPath);
% Go through all the cases and check if they have the images.
for i = 3 : numel(dirPath)
    filenamePETNormalized = fullfile(adniProcessedPath, dirPath(i).name, normalizedDataSubfolder, petNormalizedFilename);
    if exist(filenamePETNormalized,'file')
        processedSubjects{j} = dirPath(i).name;
        processedSubjectsPetFilenames{j} = filenamePETNormalized;
        j = j + 1;
    end
end
%% CREATE ATLAS FOR CN
atlasGroup = 'CN';
indexAtlas = 0;
% Go through all subjects and check if they are CN:
for i = 1 : numel(processedSubjects)
    indexMatchedName = find((strcmpi(processedSubjects{i}, adniCollectionData.Subject)) > 0); 
    if isempty(indexMatchedName)
        warning(sprintf('Case % not found in the database CSV.', processedSubjects{i}));
    end
    if numel(indexMatchedName) > 1
        indexMatchedName = indexMatchedName(1); % We are looking for the initial visit.
    end
    % Is this group:
    if strcmp(adniCollectionData.Group(indexMatchedName), atlasGroup)
        indexAtlas = indexAtlas + 1;
        petImage(:,:,:,indexAtlas) = niftiread(processedSubjectsPetFilenames{i});
        subjectName{indexAtlas} = adniCollectionData.Subject{indexMatchedName};
        group{indexAtlas} = adniCollectionData.Group{indexMatchedName};
        age_years(indexAtlas) = adniCollectionData.Age(indexMatchedName);
        sex(indexAtlas) = adniCollectionData.Sex{indexMatchedName};
        visit{indexAtlas} = adniCollectionData.Visit{indexMatchedName};
        date(indexAtlas) = adniCollectionData.AcqDate(indexMatchedName);
    end
end
%%
% Get the mean value per image:
meanValueImages = permute(mean(mean(mean(petImage))), [4 3 2 1]);
figure; bar(meanValueImages);
petAtlas = mean(petImage,4);
stdAtlas = std(petImage,4);

% Write the images:
info = niftiinfo(processedSubjectsPetFilenames{1});