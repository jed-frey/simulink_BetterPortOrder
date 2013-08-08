function optimalPortOrder(topLevel)
% optimalPortOrder - Orders the ports of subsystems to minimize line
% crossings. It does this by taking determining the order the blocks are
% arranged in (Either vertically or diagonally). And then finding all of
% the port names for that block then determining if ports occur before or
% after that subsystem
%
% Linked libraries will have their status set to 'inactive'. This is so
% that if the changes are not wanted you can always pull when resolving
% link status. If the changes improve the signal flow you can resolve the
% link status and push the results.
%
% Usage:
%
% Syntax:  optimalPortOrder
%
% Inputs:
%    topLevel - Top level system. If this is specified all blocks from this
%    level with the BlockType='SubSystem' will be used. If nothing is given
%    then only selected blocks from the current subsystem will be used.
%
% Outputs:
%    none
%
% Example:
%    optimalPortOrder

% Other m-files required: none
% Subfunctions: none
% MAT-files required: none
%
% See also:
% Author: Jed Frey
% email: mathworks@exstatic.org
% Website: https://github.com/jedediahfrey/simulink_OptimalPortNumbering
% July 2013; Last revision: 29-July-2013

%------------- BEGIN CODE --------------
if nargin<1
    topLevel=gcs;
    errormsg='Please select at least 2 subsystems';
else
    errormsg='Please enter subsystem with least 2 subsystems';
end
% Find all subsystems in the top level.
% To a depth of 1.
subSystems=find_system(topLevel,'FindAll','On','SearchDepth',1,'BlockType','SubSystem','Parent',topLevel,'Type','Block');
% If less than 2 subsystems are selected it's hard to optimize the ports.
if length(subSystems)<2
    errordlg(errormsg);
    error(errormsg);
end

% Get the position of all the subsystems
linkedPosition=cell2mat(get(subSystems,'Position'));
% Sort them by vertical position. Meaning top subsystem is 'first';
% Bottom most subsystem is 'last'.
[~,sort_order]=sort(linkedPosition(:,2));
% Arrange according to the sort results:
subSystems=subSystems(sort_order);
% Disable the link. If all the changes we are about to make are good
% the link can be push back. If not then no harm no foul.
set(subSystems,'LinkStatus','inactive');
%% Find all of the I/O blocks in subsystems
% For each of the subsystems
for i=1:length(subSystems)
    % Find all of the In and Out ports at the top level of the subsystem
    in_tmp=find_system(subSystems(i),'FindAll','on','SearchDepth',1,'BlockType','Inport');
    out_tmp=find_system(subSystems(i),'FindAll','on','SearchDepth',1,'BlockType','Outport');
    % Get the port names.
    if ~isempty(in_tmp)
        portNames=get(in_tmp,'Name');
        % If the portNames is not a cell there is only one of the ports, turn
        % it into a cell so the rest of the processing works.
        if ~iscell(portNames)
            portNames={portNames};
        end
        % Sort by the lowecase representation of the names. Matlab sorts
        % capital and lowercase different.
        [~,sorted_order]=sort(lower(portNames));
        % Rearrange the inports into alphabetical order.
        ports(i).in=in_tmp(sorted_order); %#ok<*SAGROW,*AGROW>
    else
        ports(i).in=cell(0,0);
    end
    % Repeat for the outports.
    if ~isempty(out_tmp)
        portNames=get(out_tmp,'Name');
        if ~iscell(portNames)
            portNames={portNames};
        end
        [~,sorted_order]=sort(lower(portNames));
        ports(i).out=out_tmp(sorted_order);
    else
        ports(i).out=cell(0,0);
    end
end
%% OutPort ordering
%% Get relative port positions
% For each of the subystems.
for i=1:length(subSystems)
    % Initialize the arrays.
    ports(i).inBefore=zeros(0,2); % Ports that go in before current block
    ports(i).inAfter=zeros(0,2);  % Ports that go in after the current block
    ports(i).outBefore=zeros(0,2);% Ports that come out before the current block
    ports(i).outAfter=zeros(0,2); % Ports that come out after the current block
    % For each of the subsystems
    for j=1:length(subSystems)
        % Ignore comparing to itself
        if j==i
            continue
            % For blocks that are before (above) the current block.
        elseif j<i
            % Add the block number and the port handle.
            ports(i).inBefore=[ports(i).inBefore;[j.*ones(size(ports(j).in)) ports(j).in]];
            ports(i).outBefore=[ports(i).outBefore;[j.*ones(size(ports(j).out)) ports(j).out]];
            % For the blocks that are after (below) the current block.
        elseif j>i
            % Add the block number and the port handle.
            ports(i).inAfter=[ports(i).inAfter;[j.*ones(size(ports(j).in)) ports(j).in]];
            ports(i).outAfter=[ports(i).outAfter;[j.*ones(size(ports(j).out)) ports(j).out]];
        end
    end
end
%% Calculate 'Optimal' Outport Ordering.
% For each of the subsystems
for i=1:length(subSystems)
    % Initialize each of the different types of outport classifications
    ports(i).outStraight=cell(0,2);    % Ports that go straight out to the next level up.
    ports(i).outFeedForward=cell(0,4); % Ports that go into another block after the current block
    ports(i).outFeedBack=cell(0,4);    % Ports that feed back into another block before the current block
    ports(i).outFeedBoth=cell(0,4);    % Ports that both feed forward and back.
    % For each of the subsystem's outports.
    for j=1:length(ports(i).out)
        % Get the current outport port name
        outPortName=get(ports(i).out(j),'Name'); % Outport name.
        outportname=lower(outPortName); % Lowercase representation of the outport name.
        % Get all of the in ports after the current block with the same name
        ins=strcmpi(outPortName,get(ports(i).inAfter(:,2),'Name'));
        % Find all of them, to be sorted later.
        inAfterIdx=find(ins);
        % Get all of the outports before the current block with the same name.
        ins=strcmp(outPortName,get(ports(i).inBefore(:,2),'Name'));
        % Find the first occurance since you want that feedback line on the
        % 'bottom' to minimize line crossing.
        inBeforeIdx=find(ins);
        % If there are no in or out ports with the same name, it goes straight out
        if isempty(inAfterIdx)&&isempty(inBeforeIdx)
            % Classify current out port as 'straight out'
            ports(i).outStraight=[ports(i).outStraight;{ports(i).out(j) lower(outPortName)}];
            % If there is no block before but there is one after
        elseif ~isempty(inAfterIdx)&&isempty(inBeforeIdx)
            % Classify current out out port as 'feed forward'.
            ports(i).outFeedForward=[ports(i).outFeedForward; ...
                {ports(i).out(j) outportname min(ports(i).inAfter(inAfterIdx,1)) max(ports(i).inAfter(inAfterIdx,1))}];
            % If there is no block after but there is one before.
        elseif isempty(inAfterIdx)&&~isempty(inBeforeIdx)
            % Classify current out port as 'feed back'.
            ports(i).outFeedBack=[ports(i).outFeedBack; ...
                {ports(i).out(j) outportname min(ports(i).inBefore(inBeforeIdx,1)) max(ports(i).inBefore(inBeforeIdx,1))}];
            % If it goes to a block both before and after
        elseif ~isempty(inAfterIdx)&&~isempty(inBeforeIdx)
            % Classify current out port as 'feed both'.
            ports(i).outFeedBoth=[ports(i).outFeedBoth; ...
                {ports(i).out(j) outportname min(ports(i).inBefore(inBeforeIdx,1)) max(ports(i).inAfter(inAfterIdx,1))}];
        else
            % Unknown combination of ports statuses.
            fprintf('inAfterIdx - %d\n',inAfterIdx);
            fprintf('inBeforeIdx - %d\n',inBeforeIdx);
            save('debug.mat',ports);
            error('Unknown condition');
        end
    end
    ports(i).outFeedForward=sortrows(ports(i).outFeedForward,[2]);
    % Sort all of the feedforward blocks. The ports that go to earlier blocks
    % need to be at the bottom the ones that go to later blocks to the top.
    ports(i).outFeedForward=sortrows(ports(i).outFeedForward,[-4 -3 2]);
    % Sort all of the feedback blocks. The ports that go to earlier blocks
    % need to be at the top.
    ports(i).outFeedBack=sortrows(ports(i).outFeedBack,[-4 -3 2]);
    ports(i).outFeedBoth=sortrows(ports(i).outFeedBoth,[-4 -3 2]);
    
    % Calculate the ideal out port ordering
    ports(i).IdealOutOrder=[ports(i).outStraight{:,1}, ... % Ports that go straight out
        ports(i).outFeedForward{:,1},... % Ports that are fed forward
        ports(i).outFeedBoth{:,1}, ... % Ports that feed both
        ports(i).outFeedBack{:,1}]; % Ports that are fed back
    % For each of the out ports set them in the ideal order.
    for j=1:length(ports(i).IdealOutOrder)
        set(ports(i).IdealOutOrder(j),'Port',num2str(j));
    end
end
%% Inport ordering
for i=1:length(subSystems)
    % Case 1: Ports that come straight in from the outside
    % And go nowhere else
    ports(i).inStraight=cell(0,6);
    % Case 2: Ports that come in from the outside
    % And go to into blocks after the current one
    ports(i).inStraightUsedAfter=cell(0,6);
    % Case 3: Ports that come in from the outside
    % And go to into blocks before the current one
    ports(i).inStraightUsedBefore=cell(0,6);
    % Case 4: Ports that come in from the outside
    % And go to into blocks before & after the current one
    ports(i).inStraightUsedBoth=cell(0,6);
    % Case 5: Ports that come in from after blocks output
    % And go nowhere else
    ports(i).inFeedBack=cell(0,6);
    % Case 6: Ports that come in from after blocks' output
    % And go to into blocks after the current one
    ports(i).inFeedBackUsedAfter=cell(0,6); % Ports that come in from after blocks output.
    % Case 7: Ports that come in from after blocks' output
    % And go to into blocks before the current one
    ports(i).inFeedBackUsedBefore=cell(0,6);
    % Case 8: Ports that come in from after blocks' output
    % And go to into blocks before & after the current one
    ports(i).inFeedBackUsedBoth=cell(0,6);
    % Case 9: Ports that come in from before blocks' output
    % And go nowhere else
    ports(i).inFeedForward=cell(0,6);
    % Case 10: Ports that come in from before blocks' output
    % And go to into blocks after the current one
    ports(i).inFeedForwardUsedAfter=cell(0,6);
    % Case 11: Ports that come in from before blocks' output
    % And go to into blocks before the current one
    ports(i).inFeedForwardUsedBefore=cell(0,6);
    % Case 12: Ports that come in from before blocks' output
    % And go to into blocks before & after the current one
    ports(i).inFeedForwardUsedBoth=cell(0,6);
    % For each of the subsystem's inports.
    for j=1:length(ports(i).in)
        % Get the current inport name.
        inPortHdl=ports(i).in(j);
        inPortName=get(inPortHdl,'Name');
        inportname=lower(inPortName);
        % Find out ports with the same name before the current block
        outs=strcmp(inPortName,get(ports(i).outBefore(:,2),'Name'));
        outBeforeIdx=find(outs,1);
        % Find outports with the same name after the current block
        outs=strcmp(inPortName,get(ports(i).outAfter(:,2),'Name'));
        outAfterIdx=find(outs,1);
        % Find out ports with the same name before the current block
        ins=strcmp(inPortName,get(ports(i).inBefore(:,2),'Name'));
        inBeforeIdx=find(ins);
        % Find outports with the same name after the current block
        ins=strcmp(inPortName,get(ports(i).inAfter(:,2),'Name'));
        inAfterIdx=find(ins);
        %% Get all important parameters
        if ~isempty(outBeforeIdx)&&~isempty(outAfterIdx)
            error('Duplicate outport names');
        elseif ~isempty(outBeforeIdx)
            outPortNum=str2double(get(ports(i).outBefore(outBeforeIdx,2),'Port'));
            outPortBlock=ports(i).outBefore(outBeforeIdx,1);
        elseif ~isempty(outAfterIdx)
            outPortNum=str2double(get(ports(i).outAfter(outAfterIdx,2),'Port'));
            outPortBlock=ports(i).outAfter(outAfterIdx,1);
        else
            outPortNum=[];
            outPortBlock=[];
        end
        if ~isempty(inBeforeIdx)
            inPortBlockFirst=min(ports(i).inAfter(inAfterIdx,1));
        else
            inPortBlockFirst=[];
        end
        if ~isempty(inAfterIdx)
            inPortBlockLast=max(ports(i).inAfter(inAfterIdx,1));
        else
            inPortBlockLast=[];
        end
        %% Classify all of the inports
        %% Case 1
        if  isempty(outBeforeIdx)&& ...
                isempty(outAfterIdx)&& ...
                isempty(inBeforeIdx)&& ...
                isempty(inAfterIdx)
            ports(i).inStraight=[ports(i).inStraight;
                {inPortHdl inportname outPortBlock outPortNum inPortBlockFirst inPortBlockLast}];
            %% Case 2
        elseif  isempty(outBeforeIdx)&& ...
                isempty(outAfterIdx)&& ...
                isempty(inBeforeIdx)&& ...
                ~isempty(inAfterIdx)
            ports(i).inStraightUsedAfter=[ports(i).inStraightUsedAfter;
                {inPortHdl inportname outPortBlock outPortNum inPortBlockFirst inPortBlockLast}];     
            %% Case 3
        elseif  isempty(outBeforeIdx)&& ...
                isempty(outAfterIdx)&& ...
                ~isempty(inBeforeIdx)&& ...
                isempty(inAfterIdx)
            ports(i).inStraightUsedBefore=[ports(i).inStraightUsedBefore;
                {inPortHdl inportname outPortBlock outPortNum inPortBlockFirst inPortBlockLast}];     
            %% Case 4
        elseif  isempty(outBeforeIdx)&& ...
                isempty(outAfterIdx)&& ...
                ~isempty(inBeforeIdx)&& ...
                ~isempty(inAfterIdx)
            ports(i).inStraightUsedBoth=[ports(i).inStraightUsedBoth;
                {inPortHdl inportname outPortBlock outPortNum inPortBlockFirst inPortBlockLast}];     
            %% Case 5
        elseif  isempty(outBeforeIdx)&& ...
                ~isempty(outAfterIdx)&& ...
                isempty(inBeforeIdx)&& ...
                isempty(inAfterIdx)
            ports(i).inFeedBack=[ports(i).inFeedBack;
                {inPortHdl inportname outPortBlock outPortNum inPortBlockFirst inPortBlockLast}];     
            %% Case 6
        elseif  isempty(outBeforeIdx)&& ...
                ~isempty(outAfterIdx)&& ...
                isempty(inBeforeIdx)&& ...
                ~isempty(inAfterIdx)
            ports(i).inFeedBackUsedAfter=[ports(i).inFeedBackUsedAfter;
                {inPortHdl inportname outPortBlock outPortNum inPortBlockFirst inPortBlockLast}];     
            %% Case 7
        elseif  isempty(outBeforeIdx)&& ...
                ~isempty(outAfterIdx)&& ...
                ~isempty(inBeforeIdx)&& ...
                isempty(inAfterIdx)
            ports(i).inFeedBackUsedBefore=[ports(i).inFeedBackUsedBefore;
                {inPortHdl inportname outPortBlock outPortNum inPortBlockFirst inPortBlockLast}];     
            %% Case 8
        elseif  isempty(outBeforeIdx)&& ...
                ~isempty(outAfterIdx)&& ...
                ~isempty(inBeforeIdx)&& ...
                ~isempty(inAfterIdx)
            ports(i).inFeedBackUsedBoth=[ports(i).inFeedBackUsedBoth;
                {inPortHdl inportname outPortBlock outPortNum inPortBlockFirst inPortBlockLast}];     
            %% Case 9
        elseif ~isempty(outBeforeIdx)&& ...
                isempty(outAfterIdx)&& ...
                isempty(inBeforeIdx)&& ...
                isempty(inAfterIdx)
            ports(i).inFeedForward=[ports(i).inFeedForward;
                {inPortHdl inportname outPortBlock outPortNum inPortBlockFirst inPortBlockLast}];     
            %% Case 10
        elseif ~isempty(outBeforeIdx)&& ...
                isempty(outAfterIdx)&& ...
                isempty(inBeforeIdx)&& ...
                ~isempty(inAfterIdx)
            ports(i).inFeedForwardUsedAfter=[ports(i).inFeedForwardUsedAfter;
                {inPortHdl inportname outPortBlock outPortNum inPortBlockFirst inPortBlockLast}];     
            %% Case 11
        elseif ~isempty(outBeforeIdx)&& ...
                isempty(outAfterIdx)&& ...
                ~isempty(inBeforeIdx)&& ...
                isempty(inAfterIdx)
            ports(i).inFeedForwardUsedBefore=[ports(i).inFeedForwardUsedBefore;
                {inPortHdl inportname outPortBlock outPortNum inPortBlockFirst inPortBlockLast}];     
            %% Case 12
        elseif ~isempty(outBeforeIdx)&& ...
                isempty(outAfterIdx)&& ...
                ~isempty(inBeforeIdx)&& ...
                ~isempty(inAfterIdx)
            ports(i).inFeedForwardUsedBoth=[ports(i).inFeedForwardUsedBoth;
                {inPortHdl inportname outPortBlock outPortNum inPortBlockFirst inPortBlockLast}];     
            %% Case 13
        elseif ~isempty(outBeforeIdx)&& ...
                ~isempty(outAfterIdx)&& ...
                isempty(inBeforeIdx)&& ...
                isempty(inAfterIdx)
            error('Duplicate named outports before and after');
            %% Case 14
        elseif ~isempty(outBeforeIdx)&& ...
                ~isempty(outAfterIdx)&& ...
                isempty(inBeforeIdx)&& ...
                ~isempty(inAfterIdx)
            error('Duplicate named outports before and after');
            %% Case 15
        elseif ~isempty(outBeforeIdx)&& ...
                ~isempty(outAfterIdx)&& ...
                ~isempty(inBeforeIdx)&& ...
                isempty(inAfterIdx)
            error('Duplicate named outports before and after');
            %% Case 16
        elseif ~isempty(outBeforeIdx)&& ...
                ~isempty(outAfterIdx)&& ...
                ~isempty(inBeforeIdx)&& ...
                ~isempty(inAfterIdx)
            error('Duplicate named outports before and after');
        else
            error('OPTIMAL:UNPOSSIBLE','Impossible inport permutation')
        end
    end
    inStraightAll=sortrows([ports(i).inStraight; 
        ports(i).inStraightUsedAfter; 
        ports(i).inStraightUsedBefore; 
        ports(i).inStraightUsedBoth],2);
    inFeedForwardAll=sortrows([ports(i).inFeedForward;
        ports(i).inFeedForwardUsedBefore;
        ports(i).inFeedForwardUsedAfter;
        ports(i).inFeedForwardUsedBoth],[3 4]);
    inFeedBackAll=sortrows([ports(i).inFeedBack;
        ports(i).inFeedBackUsedBefore;
        ports(i).inFeedBackUsedAfter
        ports(i).inFeedBackUsedBoth],[-3 4]);
    ports(i).IdealInOrder=[inFeedForwardAll{:,1}, ...
        inStraightAll{:,1}, ...
        inFeedBackAll{:,1}];
    for j=1:length(ports(i).IdealInOrder)
        set(ports(i).IdealInOrder(j),'Port',num2str(j));
    end
end

% inportStyle = questdlg('For duplicate inports would you like to connect to a single inport or use duplicate inports?', ...
%     'Add Duplicate Style', ...
%     'Duplicate Inport', 'Single Inport', 'Duplicate Inport');
%
%     elseif strcmp(inportStyle,'Single Inport')
%         % Initialize all of the inport classifications.
%
%         reusedInPortsBefore=zeros(1,0); % Get the reused ports that are used before
%         reusedInPortsAfter=zeros(1,0); % Get the reused ports that are reused after
%         feedForwardPorts=zeros(1,0); % Get the feed forward ports blocks that are used before.
%     else
%         error('PORTORDER:UNKNOWNSTYLE','Unknown inport style: %s',inportStyle);
%     end
%
%         % If there are outports with the same name both before and after
%         % there is a problem.
%         if ~isempty(outBeforeIdx)&&~isempty(outAfterIdx)
%             error('There is an outport named ''%s'' both before and after ''%s''.',inPortName,get(ports(i).in(j),'Parent'));
%         end
%         % Classify all of the inports.
%         % If there is no occurance of the block name either before or after
%         if isempty(inBeforeIdx)&&isempty(outBeforeIdx)&&isempty(outAfterIdx)&&isempty(inAfterIdx)
%
%             %         elseif ~isempty(outBeforeIdx)&&isempty(inBeforeIdx)&&isempty(outAfterIdx)
%         elseif ~isempty(outBeforeIdx)
%             % Classify current in port as 'Feed Forward' from prevous block.
%             ports(i).inFeedForward=[ports(i).inFeedForward,ports(i).in(j)];
%             % Get the block number of the inport used before.
%             feedForwardPorts=[feedForwardPorts ports(i).outBefore(outBeforeIdx,1)];
%             % If there is an outport in a previous block AND an inport in a
%             % previous block but not in an after block.
%         elseif ~isempty(outBeforeIdx)&&~isempty(inBeforeIdx)&&isempty(outAfterIdx)
%             % Classify current in port as 'Feed Forward' from previous
%             % block that has previously been used as an in port.
%             ports(i).inFeedForwardReused=[ports(i).inFeedForwardReused,ports(i).in(j)];
%             % If there is an outport after.
%         elseif ~isempty(outAfterIdx)
%             % Classify current inport as 'Feed Back' from block after.
%             ports(i).inFeedBack=[ports(i).inFeedBack,ports(i).in(j)];
%             % If there is an inport before but no outport after
%         elseif ~isempty(inBeforeIdx)&&isempty(outAfterIdx)
%             % Classify current in port as 'Straight in, used in previous block'
%             ports(i).inStraightUsedBefore=[ports(i).inStraightUsedBefore,ports(i).in(j)];
%             % Get the block number of the inport used before.
%             reusedInPortsBefore=[reusedInPortsBefore ports(i).inBefore(inBeforeIdx,1)];
%             % If there is an inport after but no outport after
%         elseif ~isempty(inAfterIdx)&&isempty(outAfterIdx)
%             % Classify current in port as 'Straight in, used in later block'
%             ports(i).inStraightUsedAfter=[ports(i).inStraightUsedAfter,ports(i).in(j)];
%             % Get the block number of the inport used after.
%             reusedInPortsAfter=[reusedInPortsAfter ports(i).inBefore(inBeforeIdx,1)];
%         else
%             error('Unknown condition');
%         end
%     end
%     % Sort the reused inports from previous blocks by the block they were
%     % previously used in.
%     [~,s]=sort(reusedInPortsBefore);
%     ports(i).inStraightReused=ports(i).inStraightUsedBefore(s);
%
%     % Sort the reused inports from later blocks by the block they will be
%     % used in.
%     [~,s]=sort(reusedInPortsAfter);
%     ports(i).inStraightReused=ports(i).inStraightUsedAfter(s);
%
%     % Sort the reused inports from later blocks by the block they will be
%     % used in.
%     [~,s]=sort(feedForwardPorts);
%     ports(i).inFeedForward=ports(i).inFeedForward(s);
%     % Calculate the ideal in port ordering
%     ports(i).IdealInOrder=[ports(i).inFeedForward, ... % Ports that are fed forward
%         ports(i).inFeedForwardReused, .... % Ports that are fed forward and reused
%         ports(i).inStraightUsedBefore, ... % Ports that come in straight but reused before
%         ports(i).inStraight, ... % Ports that come in straight
%         ports(i).inStraightUsedAfter,...  % Ports that come in straight but are reused after
%         ports(i).inFeedBack]; % Ports that are fed back
%
%     % For each of the in ports ideal order in the ideal order.
%     for j=1:length(ports(i).IdealInOrder)
%         set(ports(i).IdealInOrder(j),'Port',num2str(j));
%     end
% end
% %% Clear old ports and lines
% ButtonName = questdlg('Would you like to clear current lines, inports and out ports (strongly suggested)', ...
%     'Clear existing', ...
%     'Yes', 'No', 'Yes');
% if strcmp(ButtonName,'Yes')
%     lines=find_system(topLevel,'FindAll','On','SearchDepth',1,'Type','Line');
%     delete_line(lines);
%     tmp=1;
%     while ~isempty(tmp)
%         tmp=find_system(topLevel,'FindAll','On','SearchDepth',1,'BlockType','Inport');
%         for i=1:length(tmp)
%             delete_block(tmp(i));
%         end
%     end
%     tmp=find_system(topLevel,'FindAll','On','SearchDepth',1,'BlockType','InportShadow');
%     for i=1:length(tmp)
%         delete_block(tmp(i));
%     end
%     tmp=1;
%     while ~isempty(tmp)
%         tmp=find_system(topLevel,'FindAll','On','SearchDepth',1,'BlockType','Outport');
%         for i=1:length(tmp)
%             delete_block(tmp(i));
%         end
%     end
% end
% %% Add Inports & Connect.
% ButtonName = questdlg('Would you like to add in and out ports for blocks that go straight in or out', ...
%     'Add I/O', ...
%     'Yes', 'No', 'Yes');
% if strcmp(ButtonName,'Yes')
%     % Specify inport and outport sizes.
%     inportSize=[30 14];
%     outportSize=[30 14];
%     % All of the inports to add ports for
%     inportsAll=[ports.inStraight ports.inStraightUsedAfter];
%     % Add all of the outports to add ports for.
%     outportsAll=[ports.outStraight];
%     % Offset
%     offset=200;
%     % Offset from the left
%     inStart=max([10 min(linkedPosition(:,1))-offset]);
%     % Offset after the last block.
%     outStart=max(linkedPosition(:,3))+offset;
%
%     % For each of the inports.
%     for i=1:length(inportsAll)
%         % Get the parent of the inport.
%         parent=get(inportsAll(i),'Parent');
%         % Get the port number of the inport
%         portNum=get(inportsAll(i),'Port');
%         % Get the port handles of the parent.
%         parentPorts=get_param(parent,'PortHandles');
%         % Get the inport position of the specified port number.
%         inPortPos=get(parentPorts.Inport(str2double(portNum)),'Position');
%         try
%             % Add a block at the top level with the name of the inport.
%             tmp=add_block('built-in/Inport',sprintf('%s/%s',topLevel,get(inportsAll(i),'Name')),'Position',[inStart inPortPos(2)-inportSize(2)/2 inStart+inportSize(1) inPortPos(2)+inportSize(2)/2]);
%         end
%         try
%             % Add a line from the recently added inport to the in port.
%             add_line(topLevel,sprintf('%s/1',get(inportsAll(i),'Name')),sprintf('%s/%s',get_param(parent,'Name'),portNum));
%         end
%     end
%     % For each of the outports.
%     for i=1:length(outportsAll)
%         % Get the parent of the outport.
%         parent=get(outportsAll(i),'Parent');
%         % Get the port number of the outport
%         portNum=get(outportsAll(i),'Port');
%         % Get the port handles of the parent
%         parentPorts=get_param(parent,'PortHandles');
%         % Get the position of the specified outports.
%         outPortPos=get(parentPorts.Outport(str2double(portNum)),'Position');
%         try
%             % Add a new outport.
%             tmp=add_block('built-in/Outport',sprintf('%s/%s',topLevel,get(outportsAll(i),'Name')),'Position',[outStart outPortPos(2)-outportSize(2)/2 outStart+inportSize(1) outPortPos(2)+outportSize(2)/2]);
%         end;try
%             % Connect the new outport.
%             add_line(topLevel,sprintf('%s/%s',get_param(parent,'Name'),portNum),sprintf('%s/1',get(outportsAll(i),'Name')));
%         end
%     end
%     % Create duplicate inports
%     ButtonName = questdlg('Would you like to add duplicate inports for signals already used? These will connect all reused inports to a duplicate inport block', ...
%         'Add Duplicate In', ...
%         'Yes', 'No', 'Yes');
%     if strcmp(ButtonName,'Yes')
%         %% Connect Reused Inports
%         inPortsReused=[ports.inStraightUsedBefore];
%         for i=1:length(inPortsReused)
%             % Get the parent of the outport.5
%             parent=get(inPortsReused(i),'Parent');
%             % Get the port number of the outport
%             portNum=get(inPortsReused(i),'Port');
%             % Get the port handles of the parent
%             parentPorts=get_param(parent,'PortHandles');
%             % Get the inport position.
%             inPortPos=get(parentPorts.Inport(str2double(portNum)),'Position');
%             try
%                 tmp=add_block(sprintf('%s/%s',topLevel,get(inPortsReused(i),'Name')),sprintf('%s/%s',topLevel,get(inPortsReused(i),'Name')),'CopyOption', 'duplicate', 'MakeNameUnique', 'on', 'Position',[inStart inPortPos(2)-inportSize(2)/2 inStart+inportSize(1) inPortPos(2)+inportSize(2)/2]);
%                 add_line(topLevel,sprintf('%s/1',get(tmp,'Name')),sprintf('%s/%s',get_param(parent,'Name'),portNum));
%             end
%         end
%
%     end
% end
% %% Connect Feed Forward
% ButtonName = questdlg('Would you like to add connect feed forward ports?', ...
%     'FeedForward In', ...
%     'Yes', 'No', 'Yes');
% if strcmp(ButtonName,'Yes')
%     inFeedForwards=[ports.inFeedForward ports.inFeedForwardReused];
%     outFeedForwards=[ports.outFeedForward ports(i).outFeedBack];
%     % %
%     for i=1:length(outFeedForwards)
%         % Get the parent of the outport.
%         parentOut=get(outFeedForwards(i),'Parent');
%         % Get the port number of the outport
%         portNumOut=get(outFeedForwards(i),'Port');
%         %
%         fedInPorts=inFeedForwards(strcmp(get(outFeedForwards(i),'Name'),get(inFeedForwards,'Name')));
%         for j=1:length(fedInPorts)
%             parentIn=get(fedInPorts(j),'Parent');
%             % Get the port number of the outport
%             portNumIn=get(fedInPorts(j),'Port');
%             outName=sprintf('%s/%s',get_param(parentOut,'Name'),portNumOut);
%             inName=sprintf('%s/%s',get_param(parentIn,'Name'),portNumIn);
%             add_line(topLevel,outName,inName,'autorouting','on')
%         end
%     end
% end
%
% %% Connect Feed Back w/delay
% ButtonName = questdlg('Would you like to add connect feedback w/delay ports?', ...
%     'FeedForward In', ...
%     'Yes', 'No', 'Yes');
% if strcmp(ButtonName,'Yes')
%     outFeedBacks=fliplr([ports.outFeedBack,ports.outFeedBoth]);
%     inFeedBacks=[ports.inFeedBack];
%     offset=[20 60];
%     delaySize=[15 40];
%     for i=1:length(outFeedBacks)
%         % Get the parent of the outport.
%         parentOut=get(outFeedBacks(i),'Parent');
%         % Get the port number of the outport
%         portNumOut=get(outFeedBacks(i),'Port');
%         % Get the handles of the outports of the out parent block
%         parentOutHandles=get_param(parentOut,'PortHandles');
%         % Where should the line start.
%         startPos=get(parentOutHandles.Outport(str2double(portNumOut)),'Position');
%         parentBlock=get_param(parentOut,'Position');
%
%         fedInPorts=inFeedBacks(strcmp(get(outFeedBacks(i),'Name'),get(inFeedBacks,'Name')));
%         n=length(fedInPorts);
%         for j=1:n
%             try
%                 % Get the parent of the inport.
%                 parentIn=get(fedInPorts(j),'Parent');
%                 % Get the port number of the outport
%                 portNumIn=get(fedInPorts(j),'Port');
%                 % Get the handles of the inports of the in parent block.
%                 parentInHandles=get_param(parentIn,'PortHandles');
%                 % Where should the line end
%                 endPos=get(parentInHandles.Inport(str2double(portNumIn)),'Position');
%
%                 pos=[parentBlock(3)-delaySize(1) parentBlock(4)+offset(2).*(i*j)-delaySize(2)/2 parentBlock(3) parentBlock(4)+offset(2).*(i*j)+delaySize(2)/2];
%                 blockPath=sprintf('%s/%sDelay',topLevel,get(outFeedBacks(i),'Name'));
%                 try
%                     tmp=get_param(blockPath,'Handle');
%                     set(tmp,'Position',pos);
%                 catch
%                     tmp=add_block('built-in/UnitDelay',blockPath,'Position',pos,'Orientation','Left');
%                 end
%                 tmp=get(tmp,'PortHandles');
%                 delayIn =get(tmp.Inport,'Position');
%                 delayOut=get(tmp.Outport,'Position');
%
%                 % Line from out block to delay.
%                 pos=zeros(4,2);
%                 pos(1,:)=startPos;
%                 pos(2,:)=[pos(1,1)+offset(1).*(i*j) pos(1,2)];
%                 pos(3,:)=[pos(2,1)               delayIn(2)];
%                 pos(4,:)=delayIn;
%                 add_line(topLevel,pos);
%
%                 % Line from delay to in block
%                 pos=zeros(4,2);
%                 pos(4,:)=endPos;
%                 pos(3,:)=[endPos(1)-offset(1).*(i*j) endPos(2)];
%                 pos(2,:)=[endPos(1)-offset(1).*(i*j) delayOut(2)];
%                 pos(1,:)=delayOut;
%                 add_line(topLevel,pos);
%             end
%         end
%     end
% end
%
% %% Relink inactive subsystems?
% ButtonName = questdlg('Would you like to push changes to linked libraries?', ...
%     'FeedForward In', ...
%     'Yes', 'No', 'Yes');
% if strcmp(ButtonName,'Yes')
%     %%
%     if false
%         unLinkedSubSystems=find_system(topLevel,'FindAll','On','SearchDepth',1,'LinkStatus','inactive');
%         set(unLinkedSubSystems,'LinkStatus','propagate');
%     end
% end