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

%% PATHS AND FILENAMES
adniPath = [adniPartitionPath '/ADNIdata/FDG/ADNI2_FDG_T1/'];
adniDicomPath = [adniPath '/ADNI/'];
adniProcessedPath = [adniPath '/Processed/'];
adniUnsamPetQuantToolsPath = [adniProcessedPath '/FinalImages/'];
normalizedDataSubfolder = 'ANTs';

outputPath = [adniPath '/Atlases/'];
if ~isdir(outputPath)
    mkdir(outputPath)
end

% ADNI DATABASE COLLECTION
filenameADNICollection = 'ADNI2_FDG_T1_6_05_2023.csv';
adniMergeFullFilename = '/home/martin/data_imaging/ADNIdata/StudyInfo/Study_Info/ADNIMERGE_12Jul2023.csv';
petNormalizedFilenameSuffix = 'PET_intensity_normalization_';
t1NormalizedFilenameSuffix = 'T1_Norm_MNI_152_';
petQuantificationValuesFilenameSuffix = 'CSV_data_';
%segNormalizedFilename = 'Aseg_Norm_MNI_152_ANT.nii.gz';
format = '.nii.gz';
dcmHeadersFilename = 'dcmHeaders.mat';

% Load adni dicom collection csv:
adniCollectionData = readtable([adniPath filenameADNICollection]);
adniMergeData = readtable(adniMergeFullFilename);
%% LOAD ATLASES AND LABELS INFO
labelNamesHammersAtlas = readtable('/home/martin/data/UNSAM/PET/UNSAMPETQuantificationTools/Labels/labels_Hammers.csv');

%% CASES TO PROCESS
processedSubjects = {};
processedSubjectsPetFilenames = {};
j = 1;

dirPath = dir(adniUnsamPetQuantToolsPath);
% Go through all the cases and check if they have the images.
for i = 3 : numel(dirPath)
    filenamePETNormalized = fullfile(adniUnsamPetQuantToolsPath, dirPath(i).name, ...
        [petNormalizedFilenameSuffix dirPath(i).name format]);
    if exist(filenamePETNormalized,'file')
        % Read image
        processedSubjects{j} = dirPath(i).name;
        processedSubjectsPetFilenames{j} = filenamePETNormalized;
        % Read csv
        filenamePETQvalues = fullfile(adniUnsamPetQuantToolsPath, dirPath(i).name, ...
            [petQuantificationValuesFilenameSuffix dirPath(i).name '.csv']);
        petQValuesTable{j} = readtable(filenamePETQvalues);
        petNormUptake(j,:) = petQValuesTable{j}.normalization(petQValuesTable{j}.n_label~=0);
        roiIds(j,:) = petQValuesTable{j}.n_label(petQValuesTable{j}.n_label~=0);
        j = j + 1;
    end
end
%% CREATE ATLAS FOR CN AND EVALUATE USING LEAVE ONE OUT
atlasGroups = {'CN', 'AD'};
% First create atlases for both groups.
for g = 1 : numel(atlasGroups)
    indexAtlas = 0;
    indicesAdniCsvSubjectsPerGroup{g} = [];
    indicesSubjectsPerGroup{g} = [];
    % Go through all subjects and check if they are CN:
    for i = 1 : numel(processedSubjects)
        indexMatchedName = find((strcmpi(processedSubjects{i}, adniCollectionData.Subject)) > 0); 
        indexMatchedNameMerge = find((strcmpi(processedSubjects{i}, adniMergeData.PTID)) > 0); 
        if isempty(indexMatchedName) && isempty(indexMatchedNameMerge)
            warning(sprintf('Case % not found in the database CSV.', processedSubjects{i}));
        else
            
            if isempty(indexMatchedName)
                if numel(indexMatchedNameMerge) > 1
                    indexMatchedNameMerge = indexMatchedNameMerge(1); % We are looking for the initial visit.
                end
                groupThisSubject = adniMergeData.DX_bl{indexMatchedNameMerge};
            else
                if numel(indexMatchedName) > 1
                    indexMatchedName = indexMatchedName(1); % We are looking for the initial visit.
                end
                groupThisSubject = adniCollectionData.Group{indexMatchedName};
            end
            % Is this group:
            if strcmp(groupThisSubject, atlasGroups{g})
                indexAtlas = indexAtlas + 1;
                % Save the indices for later.
                group{i} = groupThisSubject;
                indicesAdniCsvSubjectsPerGroup{g} = [indicesAdniCsvSubjectsPerGroup{g} indexMatchedName];
                indicesSubjectsPerGroup{g} = [indicesSubjectsPerGroup{g} i];
                % Store the data for this subject.
                petImages{g}(:,:,:,indexAtlas) = niftiread(processedSubjectsPetFilenames{i});
                subjectName{g}{indexAtlas} = processedSubjects{i};
                %group{g}{indexAtlas} = groupThisSubject;
                if ~isempty(indexMatchedName)
                    age_years{g}(indexAtlas) = adniCollectionData.Age(indexMatchedName);
                    sex{g}(indexAtlas) = adniCollectionData.Sex{indexMatchedName};
                    visit{g}{indexAtlas} = adniCollectionData.Visit{indexMatchedName};
                    date{g}(indexAtlas) = adniCollectionData.AcqDate(indexMatchedName);   
                else
                    age_years{g}(indexAtlas) = adniMergeData.AGE(indexMatchedNameMerge);
                    sex{g}(indexAtlas) = adniMergeData.PTGENDER{indexMatchedNameMerge}(1);
                    visit{g}{indexAtlas} = adniMergeData.VISCODE{indexMatchedNameMerge};
                    date{g}(indexAtlas) = adniMergeData.EXAMDATE(indexMatchedNameMerge);
                end
            end
            
        end
    end
    % Get the mean value per image:
    meanValueImages = permute(mean(mean(mean(petImages{g}))), [4 3 2 1]);
    figure; bar(meanValueImages);
    petAtlas{g} = mean(petImages{g},4);
    stdAtlas{g} = std(petImages{g},[],4);
    covAtlas{g} = stdAtlas{g}./(petAtlas{g}+1e-20);
    % Show a slice of the atlas:
    figure;
    subplot(1,3,1); imshow(petAtlas{g}(:,:,round(size(petAtlas{g},3)/2))',[]);
    subplot(1,3,2); imshow(stdAtlas{g}(:,:,round(size(petAtlas{g},3)/2))',[]);
    subplot(1,3,3); imshow(covAtlas{g}(:,:,round(size(petAtlas{g},3)/2))',[0 max(covAtlas{g}, [], 'all')*0.2]);
    % Write the images:
    info = niftiinfo(processedSubjectsPetFilenames{1});
    niftiwrite(petAtlas{g}, [outputPath 'AtlasPETFDG_' atlasGroups{g}], info);
    niftiwrite(stdAtlas{g}, [outputPath 'AtlasStdPETFDG_' atlasGroups{g}], info);
    niftiwrite(covAtlas{g}, [outputPath 'AtlasCovPETFDG_' atlasGroups{g}], info);

    % Connectvity Matrices
    petNormUptakeValuesPerGroup{g} = petNormUptake(indicesSubjectsPerGroup{g}, :);
    metabolicConnMatrix{g} = corr(petNormUptakeValuesPerGroup{g});
end
%% CREATE INDICES FOR THE GROUP VARIABLE
groupsIndex = [];
for g = 1 : numel(atlasGroups)
    groupsIndex(strcmp(group, atlasGroups{g})) = g;
end
%% ATLAS DISCRDING OUTLIERS
thresholdNumOutlierRegions = 10;
for g = 1 : numel(atlasGroups)
    outliersPerGroupAndRegions{g} = isoutlier(petNormUptakeValuesPerGroup{g});
    % Now check how many regions:
    numOutlierRegions = sum(outliersPerGroupAndRegions{g},2);
    % Check how many surpass the threshold:
    indicesOutliers{g} = numOutlierRegions > thresholdNumOutlierRegions;
    numOutliers{g} = sum(indicesOutliers{g});
    % Create atlas without outliers:
    petAtlas{g} = mean(petImages{g}(:,:,:,~indicesOutliers{g}), 4);
    stdAtlas{g} = std(petImages{g}(:,:,:,~indicesOutliers{g}),[],4);
    covAtlas{g} = stdAtlas{g}./(petAtlas{g}+1e-20);
    niftiwrite(petAtlas{g}, [outputPath 'AtlasPETFDG_FiltOutliers_' atlasGroups{g}], info);
    niftiwrite(stdAtlas{g}, [outputPath 'AtlasStdPETFDG_FiltOutliers_' atlasGroups{g}], info);
    niftiwrite(covAtlas{g}, [outputPath 'AtlasCovPETFDG_FiltOutliers_' atlasGroups{g}], info);

    fprintf('Number of outliers exluded in the %s atlas: %d.\n', atlasGroups{g}, numOutliers{g});
end
%% SHOW ATLASES
% Create a figure with both atlases:
bothAtlases = [flip(permute(petAtlas{1}, [2 1 3]),1), flip(permute(petAtlas{2}, [2 1 3]),1)];
figure;
imshow(bothAtlases(:,:, size(petAtlas{1},3)/2-5),[]);
colormap('turbo');
colorbar
set(gcf, 'Position', [100 100 1600 1200]);
for g = 1 :numel(atlasGroups)
    y = 15;
    x = (g-1)*size(petAtlas{1},1) + size(petAtlas{1},1)/2-12;
    text(x, y, atlasGroups{g}, 'FontSize', 18, 'FontWeight', 'bold','Color', 'w');
end
%% USE THE ATLASES TO CLASSIFY ALZHEIMERS WITH A LEAVE ONE OUT SCHEME
% Go throough each case, check the group and create a new atlas if this
% subejcts is included in the atlas.
for i = 1 : size(petNormUptake,1)
    % Save the original atlases:
    for g = 1 : numel(atlasGroups)
        petAtlasLeaveOneOut{g} = petAtlas{g};
    end
    % Get the group for this subject:
    groupIndexThisSubject = groupsIndex(i);
    % Index in subgroup:
    indexInGroup = find((indicesSubjectsPerGroup{groupIndexThisSubject} == i) > 0);
    % Generate an atlas without this case, if this subjects is included
    % in the atlas (not an outlier).
    if indicesOutliers{groupIndexThisSubject}(indexInGroup) == 0
        indicesForAtlas = ~indicesOutliers{groupIndexThisSubject};
        indicesForAtlas(indexInGroup) = 0;
        % Update this atlas
        petAtlasLeaveOneOut{groupIndexThisSubject} = mean(petImages{groupIndexThisSubject}(:,:,:,indicesForAtlas),4);
    end
    % Compute distance to each atlas:
    petImageThisSubject = petImages{groupIndexThisSubject}(:,:,:, indexInGroup);
    for g = 1 : numel(atlasGroups)
        ceAtlas(i,g) = crossentropy(petImageThisSubject, petAtlas{g});
        frobeniusDistanceAtlas(i,g) = norm(petImageThisSubject -  petAtlas{g}, 'fro');
    end
end
% Classify each subject based on the frobenius distance:
[minFroDistAtlas, indMinFroDistAtlas] = min(frobeniusDistanceAtlas, [],2);
% Check accuracy of the predictor.
confMatrix = confusionmat(groupsIndex, indMinFroDistAtlas); % Groups index: ground truth, indMinFroDistAtlas: prediction
accuracyAtlasPredictor = (confMatrix(1,1)+confMatrix(2,2))./sum(confMatrix(:))*100;
%% SHOW THE RESULTS IN A CONFUSION MATRIX
figure
cm = confusionchart(groupsIndex,indMinFroDistAtlas);
%% DIFFERENCE BETWEEN ATLASES
% Diff atlases:
diffAtlas = (petAtlas{2}-petAtlas{1})./petAtlas{1}*100;
figure; imshow(diffAtlas(:,:,80),[-50 50])
%% SHOW CONNECTIVITY METABOLIC MATRICES
figure;
for g = 1 : numel(atlasGroups)
    subplot(1,numel(atlasGroups),g); imagesc(metabolicConnMatrix{g}); 
    set(gca,'dataAspectRatio',[1 1 1])
    title(atlasGroups{g})
    colorbar
end
%% WITH ANOTHER COLORBAR
figure;
for g = 1 : numel(atlasGroups)
    subplot(1,numel(atlasGroups),g); imshow(metabolicConnMatrix{g}, [0 1]); 
    colormap(jet)
    set(gca,'dataAspectRatio',[1 1 1])
    title(atlasGroups{g})
    colorbar
end
%% WITH ANOTHER COLORBAR
figure;
for g = 1 : numel(atlasGroups)
    subplot(1,numel(atlasGroups),g); imshow(metabolicConnMatrix{g}, [0 1]); 
    colormap(jet)
    set(gca,'dataAspectRatio',[1 1 1])
    title(atlasGroups{g})
    colorbar
end
