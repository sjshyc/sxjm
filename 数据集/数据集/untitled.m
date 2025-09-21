% 设置源域数据所在的根文件夹
rootFolder = 'E:\sxjm\数据集\数据集\源域数据集'; % 请替换为实际文件夹路径

% 获取所有需要整合的数据文件（以.mat文件为例）
filePattern = fullfile(rootFolder, '**', '*.mat');
fileList = dir(filePattern);
fileList = fileList([fileList.isdir] == 0); % 过滤掉文件夹
numFiles = length(fileList);

if numFiles == 0
    error('未找到任何数据文件，请检查路径和文件格式');
end
fprintf('共发现 %d 个数据文件，开始处理...\n', numFiles);

% 确定最大路径深度（用于创建路径列）
maxDepth = 0;
allVariables = {}; % 存储所有文件中的变量名

% 第一次遍历：确定路径深度和所有变量
for i = 1:numFiles
    fullPath = fullfile(fileList(i).folder, fileList(i).name);
    
    % 计算相对路径深度
    relPath = fullfile(fileList(i).folder, fileList(i).name);
    relPath = replace(relPath, rootFolder, '');
    pathParts = strsplit(relPath, filesep);
    pathParts = pathParts(~cellfun('isempty', pathParts)); % 移除空元素
    currentDepth = length(pathParts);
    
    if currentDepth > maxDepth
        maxDepth = currentDepth;
    end
    
    % 记录所有变量名
    try
        data = load(fullPath);
        vars = fieldnames(data);
        allVariables = unique([allVariables, vars]);
    catch
        warning('读取文件 %s 时出错，无法获取变量信息', fullPath);
    end
end

% 初始化表格列 - 先创建空单元格数组
tableData = cell(numFiles, maxDepth + 2 + length(allVariables));
colNames = cell(1, maxDepth + 2 + length(allVariables));

% 设置列名
% 路径层级列
for d = 1:maxDepth
    colNames{d} = sprintf('Level%d', d);
end
% 文件信息列
colNames{maxDepth + 1} = 'FileName';
colNames{maxDepth + 2} = 'FileExtension';
% 变量列
for v = 1:length(allVariables)
    colNames{maxDepth + 2 + v} = allVariables{v};
end

% 第二次遍历：填充数据到单元格数组
for i = 1:numFiles
    currentFile = fileList(i);
    fullPath = fullfile(currentFile.folder, currentFile.name);
    
    % 提取文件名和扩展名
    [~, fileName, fileExt] = fileparts(fullPath);
    
    % 提取路径层级
    relPath = fullfile(currentFile.folder, currentFile.name);
    relPath = replace(relPath, rootFolder, '');
    pathParts = strsplit(relPath, filesep);
    pathParts = pathParts(~cellfun('isempty', pathParts));
    
    % 填充路径层级数据
    for d = 1:maxDepth
        if d <= length(pathParts)
            tableData(i, d) = {pathParts{d}};
        else
            tableData(i, d) = {''}; % 短路径用空字符串填充
        end
    end
    
    % 填充文件信息
    tableData(i, maxDepth + 1) = {fileName};
    tableData(i, maxDepth + 2) = {fileExt};
    
    % 读取文件数据并填充变量列
    try
        data = load(fullPath);
        vars = fieldnames(data);
        
        % 填充存在的变量
        for v = 1:length(vars)
            varIndex = find(strcmp(allVariables, vars{v}));
            if ~isempty(varIndex)
                tableData(i, maxDepth + 2 + varIndex) = {data.(vars{v})};
            end
        end
        
        % 填充不存在的变量（设为NaN）
        missingVars = setdiff(allVariables, vars);
        for v = 1:length(missingVars)
            varIndex = find(strcmp(allVariables, missingVars{v}));
            if ~isempty(varIndex)
                tableData(i, maxDepth + 2 + varIndex) = {NaN};
            end
        end
        
        fprintf('已处理 %d/%d: %s\n', i, numFiles, fullPath);
    catch err
        warning('处理文件 %s 时出错: %s', fullPath, err.message);
        % 出错文件的所有变量都设为NaN
        for v = 1:length(allVariables)
            tableData(i, maxDepth + 2 + v) = {NaN};
        end
    end
end

% 从单元格数组创建表格
combinedTable = cell2table(tableData, 'VariableNames', colNames);

% 验证表格行数
if height(combinedTable) ~= numFiles
    warning('表格行数与文件数量不符！预期 %d 行，实际 %d 行', numFiles, height(combinedTable));
else
    fprintf('表格创建成功，共 %d 行数据\n', height(combinedTable));
end

% 保存整合后的表格
save('hierarchical_integrated_data.mat', 'combinedTable');
disp(['数据整合完成，共处理 ', num2str(numFiles), ' 个文件']);
disp('整合结果已保存为 hierarchical_integrated_data.mat');
    