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
%% CREATE ATLAS FOR CN
atlasGroups = {'CN', 'AD'};
for g = 1 : numel(atlasGroups)
    indexAtlas = 0;
    indicesAdniCsvSubjectsPerGroup{g} = [];
    indicesSubjectsPerGroup{g} = [];
    clear petImage;
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
                groupThisSubject = adniCollectionData.Group(indexMatchedName);
            end
            % Is this group:
            if strcmp(groupThisSubject, atlasGroups{g})
                indexAtlas = indexAtlas + 1;
                % Save the indices for later.
                indicesAdniCsvSubjectsPerGroup{g} = [indicesAdniCsvSubjectsPerGroup{g} indexMatchedName];
                indicesSubjectsPerGroup{g} = [indicesSubjectsPerGroup{g} i];
                % Store the data for this subject.
                petImage(:,:,:,indexAtlas) = niftiread(processedSubjectsPetFilenames{i});
                subjectName{g}{indexAtlas} = processedSubjects{i};
                group{g}{indexAtlas} = groupThisSubject;
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
    meanValueImages = permute(mean(mean(mean(petImage))), [4 3 2 1]);
    figure; bar(meanValueImages);
    petAtlas{g} = mean(petImage,4);
    stdAtlas{g} = std(petImage,[],4);
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

%% DIFFERENCE BETWEEN ATLASES
% Diff atlases:
diffAtlas = (petAtlas{2}-petAtlas{1})./petAtlas{1}*100;
figure; imshow(diffAtlas(:,:,120),[-50 50])
%% SHOW CONNECTIVITY METABOLIC MATRICES
figure;
for g = 1 : numel(atlasGroups)
    subplot(1,numel(atlasGroups),g); imagesc(metabolicConnMatrix{g}); 
    set(gca,'dataAspectRatio',[1 1 1])
    title(atlasGroups{g})
    colorbar
end
%% SAVE CONNECTIVITY MATRICES
for g = 1 : numel(atlasGroups)
    figure;
    imshow(metabolicConnMatrix{g}, [0 1]); 
    colormap(jet);
    set(gca,'dataAspectRatio',[1 1 1])
    %title(atlasGroups{g})
    colorbar
    set(gcf, 'Position', [100 100 2000 2000])
    saveas(gca, [outputPath sprintf('ConnectivityMatrix_%s.png', atlasGroups{g})])
    exportgraphics(gca, [outputPath sprintf('ConnectivityMatrix_%s.png', atlasGroups{g})])
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
%% Inter-hemispheric connectivity
indicesLeftRois = find(strcmp(petQValuesTable{1}.hemisphere(petQValuesTable{1}.n_label~=0), 'L')>0);
indicesRightRois = find(strcmp(petQValuesTable{1}.hemisphere(petQValuesTable{1}.n_label~=0), 'R')>0);
% Correlation right and left matrices:
figure;
for g = 1 : numel(atlasGroups)
    metabolicLeftRightConnMatrix{g} = corr(petNormUptake(indicesSubjectsPerGroup{g}, indicesLeftRois), ...
        petNormUptake(indicesSubjectsPerGroup{g}, indicesRightRois));
    subplot(1,numel(atlasGroups),g); imshow(metabolicLeftRightConnMatrix{g}, [0 1]); 
    colormap(jet)
    set(gca,'dataAspectRatio',[1 1 1])
    title(atlasGroups{g})
    colorbar
end
%% USE THE MAP TO CLASSIFY ALZHEIMERS
for i = 1 : size(petNormUptake,1)
    petImageThisSubject= niftiread(processedSubjectsPetFilenames{i});
    matrixPerSubject = petNormUptake(i,:)' * petNormUptake(i,:);
%     subplot(1,numel(atlasGroups)+1,1); imshow(matrixPerSubject, [0 1]); 
%     colormap(jet);
%     for g = 1 : numel(atlasGroups)
%         subplot(1,numel(atlasGroups)+1,g+1); imshow(metabolicConnMatrix{g}, [0 1]); 
%         colormap(jet);
%     end
%     pause;
    % Compute distance to each matrix:
    for g = 1 : numel(atlasGroups)
        ce(i,g) = crossentropy(matrixPerSubject, metabolicConnMatrix{g});
        ecuDistance(i,g) = norm(matrixPerSubject -  metabolicConnMatrix{g});
        frobeniusDistance(i,g) = norm(matrixPerSubject -  metabolicConnMatrix{g}, 'fro');
    end
    % Compute distance to each atlas:
    for g = 1 : numel(atlasGroups)
        ceAtlas(i,g) = crossentropy(petImageThisSubject, petAtlas{g});
        frobeniusDistanceAtlas(i,g) = norm(petImageThisSubject -  petAtlas{g}, 'fro');
    end
end
%%
[minFroDistAtlas, indMinFroDistAtlas] = min(frobeniusDistanceAtlas, [],2);
%%
classes = cell(size(petNormUptake, 1),1);
% Binary label of AD
indexGroupAD = strcmp(atlasGroups, 'AD');
for g = 1 : numel(indexGroupAD)
    for i = 1 : numel(indicesSubjectsPerGroup{g})
        classes{indicesSubjectsPerGroup{g}(i)} = atlasGroups{g};
    end
end
%%
predictionAtlases = cell(size(petNormUptake, 1),1);
for g = 1 : numel(atlasGroups)
    indClass = find(indMinFroDistAtlas == g > 0);
    for i = 1 : numel(indClass)
        predictionAtlases{indClass(i)} = atlasGroups{g};
    end
end

ind = strcmp(predictionAtlases, classes);
predictionError = sum(ind == 0)./numel(ind);
%% CLASSIFIER BASED IN A SVM
classes = cell(size(petNormUptake, 1),1);
% Binary label of AD
indexGroupAD = strcmp(atlasGroups, 'AD');
for g = 1 : numel(indexGroupAD)
    for i = 1 : numel(indicesSubjectsPerGroup{g})
        classes{indicesSubjectsPerGroup{g}(i)} = atlasGroups{g};
    end
end
SVMModel = fitcsvm(petNormUptake,classes);

sv = SVMModel.SupportVectors;
figure
gscatter(petNormUptake(:,1),petNormUptake(:,2),classes)
hold on
plot(sv(:,1),sv(:,2),'ko','MarkerSize',10)
legend('CN','AD','Support Vector')
hold off
%% PET NORM UPTAKE DIFFERENCES
for g = 1 : numel(atlasGroups)
    meanUptakePerRegionAndGroup(g,:) = mean(petNormUptakeValuesPerGroup{g});
end
% Get the difference:
diffUptakePerGroup = [meanUptakePerRegionAndGroup(2,:) - meanUptakePerRegionAndGroup(1,:)];

% BOXPLOT
figure;
set(gcf, 'Position', [100 100 4000 2400]);
%ha = boxchart(ax1, nameSingleMuscle, ...
%volValues_cm3(namedMuscle == labelsMuscle(i)),'GroupByColor',namedGroup(namedMuscle == labelsMuscle(i)), 'Notch', 'on');
regionsIds = repmat(1:size(petNormUptake,2), size(petNormUptake,1), 1);
vecRegionsIds = vec(regionsIds);
labelNames = labelNamesHammersAtlas.structure(roiIds);
vecLabelNames = categorical(vec(labelNames));
vecPetNormUptake = vec(petNormUptake);
vecClasses = vec(repmat(classes, 1, size(petNormUptake,2)));
boxchart(vecLabelNames, vecPetNormUptake, 'GroupByColor', vecClasses);
%%
% Estimate signiicant differences with kruskalwallis:
for i = 1 : size(petNormUptake,2)
    p(i) = kruskalwallis(petNormUptake(:,i),classes,'off');
end
%%
for i = 1 : size(petNormUptake,2)
    [h_ttest(i), p_ttest(i)] = ttest2(petNormUptakeValuesPerGroup{1}(:,i), petNormUptakeValuesPerGroup{2}(:,i));
end
% Names of the regions that are different:
disp(labelNames(1,h_ttest==1))
%%
SVMModel = fitcsvm(petNormUptake,classes,'Standardize',true,'KernelFunction','RBF',...
    'KernelScale','auto');
CVSVMModel = crossval(SVMModel);
classLoss = kfoldLoss(CVSVMModel);
%%
svInd = SVMModel.IsSupportVector;
h = 0.02; % Mesh grid step size
[X1,X2] = meshgrid(min(petNormUptake(:,1)):h:max(petNormUptake(:,1)),...
    min(petNormUptake(:,2)):h:max(petNormUptake(:,2)));
[~,score] = predict(SVMModel,[petNormUptake(:),petNormUptake(:)]);
scoreGrid = reshape(score,size(petNormUptake,1),size(petNormUptake,2));

figure
plot(petNormUptake(:,1),petNormUptake(:,2),'k.')
hold on
plot(petNormUptake(svInd,1),petNormUptake(svInd,2),'ro','MarkerSize',10)
contour(X1,X2,scoreGrid)
colorbar;
title('{\bf Iris Outlier Detection via One-Class SVM}')
xlabel('Sepal Length (cm)')
ylabel('Sepal Width (cm)')
legend('Observation','Support Vector')
hold off