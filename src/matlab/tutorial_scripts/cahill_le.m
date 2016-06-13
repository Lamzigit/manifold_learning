% exampleScript.m: Provides example code for performing Spatial-Spectral 
% Schroedinger Eigenmaps for dimensionality reduction, as described in the
% papers:
%
% 1) N. D. Cahill, W. Czaja, and D. W. Messinger, "Schroedinger Eigenmaps 
% with Nondiagonal Potentials for Spatial-Spectral Clustering of 
% Hyperspectral Imagery," Proc. SPIE Defense & Security: Algorithms and 
% Technologies for Multispectral, Hyperspectral, and Ultraspectral Imagery 
% XX, May 2014. 
%
% 2) N. D. Cahill, W. Czaja, and D. W. Messinger, "Spatial-Spectral
% Schroedinger Eigenmaps for Dimensionality Reduction and Classification of
% Hyperspectral Imagery," submitted.
%
% This example script also performs classification using Support Vector
% Machines, as described in paper 2.
%
clear all; close all; clc;
%% Load Indian Pines data, available from:
% http://www.ehu.es/ccwintco/uploads/6/67/Indian_pines_corrected.mat
% http://www.ehu.es/ccwintco/uploads/6/67/Indian_pines_gt.mat
%

% add file path of where my data is located
addpath('H:\Data\Images\RS\IndianPines\')
% addpath('/media/eman/Emans HDD/Data/Images/RS/IndianPines')

% load the images
load('Indian_pines_corrected.mat');
load('Indian_pines_gt.mat');

% set them to variables
img = indian_pines_corrected;
gt = indian_pines_gt;

% clear the path as well as the datafiles 
clear indian*
% rmpath('/media/eman/Emans HDD/Data/Images/RS/IndianPines')
rmpath('H:\Data\Images\RS\IndianPines\')

%% reorder and rescale data into 2-D array
[numRows,numCols,numSpectra] = size(img);
scfact = mean(reshape(sqrt(sum(img.^2,3)),numRows*numCols,1));
img = img./scfact;
imgVec = reshape(img,[numRows*numCols numSpectra]);
gt_Vec = reshape(gt, [numRows*numCols 1]);

%% get spatial positions of data
[x,y] = meshgrid(1:numCols,1:numRows);
pData = [x(:) y(:)];

%% construct adjacency matrix via one of many methods

% select SSSE method you'd like to use
% options:
%   'SSSE_(SM)^(f,p)' (this is SSSE1 from paper 1)
%   'SSSE_(SM)^(p,f)'
%   'SSSE_(GB)^(f,p)' (this is SSSE2 from paper 1)
%   'SSSE_(GB)^(p,f)'

SSSEMethod = 'SSSE_(SM)^(f,p)';

% parameters
sigma = 1;
k = 20;
eta = 1;

% spectral graph
options.type = 'standard';
options.nn_graph = 'knn';
options.k = k;
options.saved = 0;
options.sigma = 1.0;

[A, ~] = Adjacency(imgVec, options);

%% construct graph laplacian
numNodes = size(A,1);
D = spdiags(full(sum(A)).',0,numNodes,numNodes);
L = D - A;

%% compute generalized eigenvectors - standard laplacian eigenmaps
numEigs = 100;
[XS,lambdaS] = schroedingerEigenmap(L,spalloc(numNodes,numNodes,0),0,numEigs);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Cahill Classification Experiment
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% create training and testing data sets for classification
trainPrct = 0.10;
rng('default'); % so each script generates the same training/testing data
[trainMask,testMask,gtMask] = createTrainTestData(gt,trainPrct);
trainInd = find(trainMask);
testInd = find(testMask);

% predict labels using SVM classifier
test_labels = svmClassify(XS(trainInd,2:end),gt(trainInd),XS(testInd,2:end));
labels = svmClassify(XS(trainInd,2:end),gt(trainInd),XS(:,2:end));

% display ground truth and predicted label image
labelImg = reshape(labels,numRows,numCols);
figure;
subplot(2,2,1) ; imshow(gt,[0 max(gt(:))]); title('Ground Truth Class Labels');
subplot(2,2,2); imshow(gtMask); title('Ground Truth Mask');
subplot(2,2,3); imshow(labelImg,[0 max(gt(:))]); title('Predicted Class Labels');
subplot(2,2,4); imshow(labelImg.*gtMask,[0 max(gt(:))]); title('Predicted Class Labels in Ground Truth Pixels');

% construct accuracy measures

[C, stats] = class_metrics(gt(testMask&gtMask),labels(testMask&gtMask));

% display results
fprintf('Cahills Experiment\n');
fprintf('\n\t\t\t\t\t\t\tLE\n');
fprintf('Overall Accuracy:\t\t\t%6.4f\n',stats.OA);
fprintf('Average Accuracy:\t\t\t%6.4f\n',stats.AA);
fprintf('Average Precision:\t\t\t%6.4f\n',stats.APr);
fprintf('Average Sensitivity:\t\t%6.4f\n',stats.ASe);
fprintf('Average Specificity:\t\t%6.4f\n',stats.ASp);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Eman Classification Experiment
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

gt_Vec = reshape(gt, [numRows*numCols 1]);

% choose training and testing amount

trainoptions.trainPrct = 0.1;
rng('default'); % reproducibility

[X_train, y_train, X_test, y_test, idx] = train_test_split(...
    XS, gt_Vec, trainoptions);

% svm classificiton (w/ Image)
statoptions.imgVec = XS;
[y_pred, labels] = svm_classify(X_train, y_train, X_test, statoptions);


% get statistics
[~, stats] = class_metrics(y_test, y_pred);

% display ground truth and predicted label image
labelImg = reshape(labels,numRows,numCols);
figure;
subplot(2,2,1) ; imshow(gt,[0 max(gt(:))]); title('Ground Truth Class Labels');
subplot(2,2,2); imshow(gtMask); title('Ground Truth Mask');
subplot(2,2,3); imshow(labelImg,[0 max(gt(:))]); title('Predicted Class Labels');
subplot(2,2,4); imshow(labelImg.*gtMask,[0 max(gt(:))]); title('Predicted Class Labels in Ground Truth Pixels');


% display results
fprintf('Emans Experiment\n');
fprintf('\n\t\t\t\t\t\t\tLE\n');
fprintf('Overall Accuracy:\t\t\t%6.4f\n',stats.OA);
fprintf('Average Accuracy:\t\t\t%6.4f\n',stats.AA);
fprintf('Average Precision:\t\t\t%6.4f\n',stats.APr);
fprintf('Average Sensitivity:\t\t%6.4f\n',stats.ASe);
fprintf('Average Specificity:\t\t%6.4f\n',stats.ASp);

% %#############################################################
% %% Experiment II - SVM w/ Assessment versus dimension
% %#############################################################
% 
% gt_Vec = reshape(gt,[numRows*numCols 1]);
% n_components = size(XS,2);
% test_dims = (1:10:n_components);
% 
% % choose training and testing amount
% options.trainPrct = 0.01;
% rng('default');     % reproducibility
% 
% lda_OA = [];
% svm_OA = [];
% 
% h = waitbar(0, 'Initializing waitbar...');
% 
% for dim = test_dims
%     
%     waitbar(dim/n_components,h, 'Performing SVM classification')
%     % # of dimensions
%     embedding = XS(:,1:dim);
%     
%     % training and testing samples
%     [X_train, y_train, X_test, y_test] = train_test_split(...
%     XS, gt_Vec, options);
%     
%     % classifcaiton SVM
%     [y_pred] = svmClassify(X_train, y_train, X_test);
%     
%     [~, stats] = class_metrics(y_test, y_pred);
%     
%     svm_OA = [svm_OA; stats.OA];
%     
%     
%     waitbar(dim/n_components,h, 'Performing LDA classification')
%     % classifiaction LDA
%     lda_obj = fitcdiscr(X_train, y_train);
%     y_pred = predict(lda_obj, X_test);
%     
%     [~, stats] = class_metrics(y_test, y_pred);
% 
%     lda_OA = [lda_OA; stats.OA];
%     
% 
%     
% end
% 
% close(h)
% % 
% % Plot
% 
% figure('Units', 'pixels', ...
%     'Position', [100 100 500 375]);
% hold on;
% 
% % plot lines
% hLDA = line(test_dims, lda_OA);
% hSVM = line(test_dims, svm_OA);
% 
% % set some first round of line parameters
% set(hLDA, ...
%     'Color',        'r', ...
%     'LineWidth',    2);
% set(hSVM, ...
%     'Color',        'b', ...
%     'LineWidth',    2);
% 
% hTitle = title('LE + LDA, SVM - Indian Pines');
% hXLabel = xlabel('d-Dimensions');
% hYLabel = ylabel('Correct Rate');
% 
% hLegend = legend( ...
%     [hLDA, hSVM], ...
%     'LDA - OA',...
%     'SVM - OA',...
%     'location', 'NorthWest');
% 
% % pretty font and axis properties
% set(gca, 'FontName', 'Helvetica');
% set([hTitle, hXLabel, hYLabel],...
%     'FontName', 'AvantGarde');
% set([hXLabel, hYLabel],...
%     'FontSize',10);
% set(hTitle,...
%     'FontSize'  ,   12,...
%     'FontWeight',   'bold');
% 
% set(gca,...
%     'Box',      'off',...
%     'TickDir',  'out',...
%     'TickLength',   [.02, .02],...
%     'XMinorTick',   'on',...
%     'YMinorTick',   'on',...
%     'YGrid',        'on',...
%     'XColor',       [.3,.3,.3],...
%     'YColor',       [.3, .3, .3],...
%     'YLim'      ,   [0 1],...
%     'XLim'      ,   [0 n_components],...
%     'YTick'     ,   0:0.1:1,...
%     'XTick'     ,   0:10:n_components,...
%     'LineWidth' ,   1);
% % 
