function optimalPortOrder
% Pseudo code.
% 
% - Inputs
% Outputs from subsystems to the left of the current subsystem (Feed forward)
% Inputs sorted by frequency
% Outputs from subsystems to the right of the current subsystem (Feed back)
% 
% - Outputs
% Outputs that go nowhere else (Out)
% Outputs that go into other subsystems
% Outputs that go to inputs to the left (feedback). Sorted by right most
topLevel=gcs;
% Find all selected subsystems in the current level.
subSystems=find_system(topLevel,'FindAll','On','SearchDepth',1,'Selected','on','Type','Block');
% find_system seems to find topLevel as a system even with search depth of 1 remove it
toss=strcmpi(get_param(topLevel,'Parent'),get(subSystems,'Parent'));
subSystems(toss)='';

% Get the position of all the libraries
linkedPosition=cell2mat(get(subSystems,'Position'));
% Sort them by vertical position. Meaning topmost subsystem is 'first'.
% Bottom most subsystem is 'last'.
[~,s]=sort(linkedPosition(:,2));
subSystems=subSystems(s);

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
    ports(i).in=in_tmp(sorted_order); %#ok<*AGROW>
    
    % Repeat for the outports.
    portNames=get(out_tmp,'Name');
    if ~iscell(portNames)
        portNames={portNames};
    end
    [~,sorted_order]=sort(lower(portNames));
    ports(i).out=out_tmp(sorted_order);
end
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
%% Calculate Outport Ordering.
% For each of the subsystems
for i=1:length(subSystems)
    % Initialize each of the different types of outport classifications
    ports(i).outStraight=zeros(0,1);    % Ports that go straight out to the next level up.
    ports(i).outFeedForward=zeros(0,1); % Ports that go into another block after the current block
    ports(i).outFeedBack=zeros(0,1);    % Ports that feed back into another block before the current block
    ports(i).outFeedBoth=zeros(0,1);    % Ports that both feed forward and back.
    % Running index of what block the feedback ports go to.
    feedBackBlock=zeros(1,0);
    % For each of the subsystem's outports.
    for j=1:length(ports(i).out)
        % Get the current outport port name
        outPortName=get(ports(i).out(j),'Name');
        % Get all of the in ports after the current block with the same name
        ins=strcmp(outPortName,get(ports(i).inAfter(:,2),'Name'));
        % Find the last one since you want that line on 'top'.
        inAfterIdx=find(ins,1,'last');
        % Get all of the outports before the current block with the same name.
        ins=strcmp(outPortName,get(ports(i).inBefore(:,2),'Name'));
        % Find the first occurance since you want that feedback line on the
        % 'bottom' to minimize line crossing.
        inBeforeIdx=find(ins,1,'first');
        % If there are no in or out ports with the same name, it goes straight out
        if isempty(inAfterIdx)&&isempty(inBeforeIdx)
            % Classify current port as 'straight out'
            ports(i).outStraight=[ports(i).outStraight,ports(i).out(j)];
            % If there is no block before but there is one after
        elseif ~isempty(inAfterIdx)&&isempty(inBeforeIdx)
            % Classify current port as 'feed forward'.
            ports(i).outFeedForward=[ports(i).outFeedForward,ports(i).out(j)];
            % If there is no block after but there is one before.
        elseif isempty(inAfterIdx)&&~isempty(inBeforeIdx)
            % Classify current port as 'feed back'.
            ports(i).outFeedBack=[ports(i).outFeedBack,ports(i).out(j)];
            % Find the block number for where this port goes back to
            feedBackBlock=[feedBackBlock ports(i).inBefore(inBeforeIdx,1)];
            % If it goes to a block both before and after
        elseif ~isempty(inAfterIdx)&&~isempty(inBeforeIdx)
            % Classify it as a 'feed both'.
            ports(i).outFeedBoth=[ports(i).outFeedBoth,ports(i).out(j)];
        else
            % Unknown combination of ports.
            fprintf('inAfterIdx - %d\n',inAfterIdx);
            fprintf('inBeforeIdx - %d\n',inBeforeIdx);
            save('debug.mat',ports);
            error('Unknown condition');
        end
    end
    % Sort all of the feedback blocks. The ports that go to earlier blocks
    % need to be at the top.
    [~,sort_order]=sort(feedBackBlock);
    ports(i).outFeedBack=ports(i).outFeedBack(sort_order);
    
    % Initialize all of the inport classifications.
    ports(i).inStraight=zeros(1,0); % Ports that come straight in from the outside and go nowhere else
    ports(i).inStraightBeforeReused=zeros(1,0); % Ports that come in from the outside that went to blocks before the current one
    ports(i).inStraightAfterReused=zeros(1,0);  % Ports that come in from the outside that go to blocks after the current one
    ports(i).inFeedForward=zeros(1,0); % Ports that come in  from previous blocks' output
    ports(i).inFeedForwardReused=zeros(1,0); % Ports that come in from previous blocks' output that are reused in blocks after the current one
    ports(i).inFeedBack=zeros(1,0); % Ports that come in from after blocks output.
    reusedInPortsBefore=zeros(1,0); % Get the reused ports that are used before
    reusedInPortsAfter=zeros(1,0); % Get the reused ports that are reused after
    
    % For each of the subsystem's inports.
    for j=1:length(ports(i).in)
        inPortName=get(ports(i).in(j),'Name');
        ins=strcmp(inPortName,get(ports(i).inBefore(:,2),'Name'));
        inBeforeIdx=find(ins,1,'last');
        
        ins=strcmp(get(ports(i).in(j),'Name'),get(ports(i).inAfter(:,2),'Name'));
        inAfterIdx=find(ins,1,'first');
        
        outs=strcmp(get(ports(i).in(j),'Name'),get(ports(i).outBefore(:,2),'Name'));
        outBeforeIdx=find(outs,1);
        
        outs=strcmp(get(ports(i).in(j),'Name'),get(ports(i).outAfter(:,2),'Name'));
        outAfterIdx=find(outs,1);
        
        if (length(outBeforeIdx)>1)
            error('Multiple blocks before %s have the same outport %s',get(ports(i).in,'Parent'),get(ports(i).in,'Name'));
        end
        if (length(outAfterIdx)>1)
            error('Multiple blocks after %s have the same outport %s',get(ports(i).in,'Parent'),get(ports(i).in,'Name'));
        end
        %
        if isempty(inBeforeIdx)&&isempty(outBeforeIdx)&&isempty(outAfterIdx)&&isempty(inAfterIdx)
            ports(i).inStraight=[ports(i).inStraight,ports(i).in(j)];
        elseif ~isempty(outBeforeIdx)&&isempty(inBeforeIdx)&&isempty(outAfterIdx)
            ports(i).inFeedForward=[ports(i).inFeedForward,ports(i).in(j)];
        elseif ~isempty(outBeforeIdx)&&~isempty(inBeforeIdx)&&isempty(outAfterIdx)
            ports(i).inFeedForwardReused=[ports(i).inFeedForwardReused,ports(i).in(j)];
        elseif ~isempty(outAfterIdx)&&isempty(outBeforeIdx)
            ports(i).inFeedBack=[ports(i).inFeedBack,ports(i).in(j)];
        elseif ~isempty(inBeforeIdx)&&isempty(outAfterIdx)
            ports(i).inStraightBeforeReused=[ports(i).inStraightBeforeReused,ports(i).in(j)];
            reusedInPortsBefore=[reusedInPortsBefore ports(i).inBefore(inBeforeIdx,1)];
        elseif ~isempty(inAfterIdx)&&isempty(outAfterIdx)
            ports(i).inStraightAfterReused=[ports(i).inStraightAfterReused,ports(i).in(j)];
            reusedInPortsAfter=[reusedInPortsAfter ports(i).inBefore(inBeforeIdx,1)];
        else
            error('Unknown condition');
        end
    end
    %
    [~,s]=sort(reusedInPortsBefore);
    ports(i).inStraightReused=ports(i).inStraightBeforeReused(s);
    %
    [~,s]=sort(reusedInPortsAfter);
    ports(i).inStraightReused=ports(i).inStraightAfterReused(s);
    %
    ports(i).IdealInOrder=[ports(i).inFeedForward,ports(i).inFeedForwardReused,ports(i).inStraightBeforeReused,ports(i).inStraight,ports(i).inStraightAfterReused,ports(i).inFeedBack];
    ports(i).IdealOutOrder=[ports(i).outStraight,ports(i).outFeedForward,ports(i).outFeedBoth,ports(i).outFeedBack];
    for j=1:length(ports(i).IdealInOrder)
        set(ports(i).IdealInOrder(j),'Port',num2str(j));
    end
    for j=1:length(ports(i).IdealOutOrder)
        set(ports(i).IdealOutOrder(j),'Port',num2str(j));
    end
    alignIO(get(ports(i).in(1),'Parent'));
end

% Remove old inports & outports.
% tlInports=find_system(topLevel,'FindAll','on','SearchDepth',1,'BlockType','Inport');
% tlOutports=find_system(topLevel,'FindAll','on','SearchDepth',1,'BlockType','Outport');
% for i=1:length(tlInports)
% delete_block(tlInports(i));
% end
% for i=1:length(tlOutports)
% delete_block(tlOutports(i));
% end

inportSize=[30 14];
outportSize=[30 14];
 inportsAll=[ports.inStraight ports.inStraightAfterReused];
outportsAll=[ports.outStraight];

inStart=300;
outStart=max(linkedPosition(:,3))+200;


for i=1:length(inportsAll)
    parent=get(inportsAll(i),'Parent');
    portNum=get(inportsAll(i),'Port');
    parentPorts=get_param(parent,'PortHandles');
    inPortPos=get(parentPorts.Inport(str2double(portNum)),'Position');
    %
%     portName=get(
    try
    tmp=add_block('built-in/Inport',sprintf('%s/%s',topLevel,get(inportsAll(i),'Name')),'Position',[10 inPortPos(2)-inportSize(2)/2 10+inportSize(1) inPortPos(2)+inportSize(2)/2]);
    end
    add_line(topLevel,sprintf('%s/1',get(tmp,'Name')),sprintf('%s/%s',get_param(parent,'Name'),portNum));
    
end

for i=1:length(outportsAll)
    parent=get(outportsAll(i),'Parent');
    portNum=get(outportsAll(i),'Port');
    parentPorts=get_param(parent,'PortHandles');
    outPortPos=get(parentPorts.Outport(str2double(portNum)),'Position');
    %
%     portName=get(
    try
    tmp=add_block('built-in/Outport',sprintf('%s/%s',topLevel,get(outportsAll(i),'Name')),'Position',[outStart outPortPos(2)-outportSize(2)/2 outStart+inportSize(1) outPortPos(2)+outportSize(2)/2]);
    end 
    add_line(topLevel,sprintf('%s/%s',get_param(parent,'Name'),portNum),sprintf('%s/1',get(tmp,'Name')));
end




%%
% 
% - Outputs
% Outputs that go nowhere else (Out)
% Outputs that go into other subsystems furthest to the right last. Sorted
%   by alphabetical name.
% Outputs that go to inputs to the left (feedback). Sorted by right most
%   first. Sorted by alphabetical name

% Ideal order
% 

% Sort position 

% 
% Relink for debugging purposes.
unLinkedSubSystems=find_system('lib_EMD1/lib_EMD1','FindAll','On','SearchDepth',1,'LinkStatus','inactive');
set(unLinkedSubSystems,'LinkStatus','restore');
% 
% % fid=fopen('InnOuts.csv','w');
% Ins=[];
% for linkedSubSystem=linkedSubSystems
%     if strncmpi(get(linkedSubSystem,'ReferenceBlock'),'LibGasControl',13)
%         continue;
%     end
%     lib=strtok(get(linkedSubSystem,'ReferenceBlock'),'/');
%     open_system(lib);
%     set_param(lib, 'Lock', 'off');
%     closeSubSystems(lib);
% 
%     ins=find_system(get(linkedSubSystem,'ReferenceBlock'),'FindAll','on','SearchDepth',1,'BlockType','Inport');
%     outs=find_system(get(linkedSubSystem,'ReferenceBlock'),'FindAll','on','SearchDepth',1,'BlockType','Outport');
%     Ins=[Ins;ins];
%     Outs=[Outs;outs];
% end
% 
% Outs=[];
% 
% OutNames=(get(Outs,'Name'));
% OutNamesUnique=sort(OutNames);
% 
% InNames=(get(Ins,'Name'));
% InNamesUnique=setdiff(InNames,OutNamesUnique);
% 
% 
% Parents=get([Ins;Outs],'Parent');•
% ParentsUnique=sort(unique(Parents));
% 
% InNamesFreq=zeros(1,numel(InNamesUnique));
% for i=1:numel(InNamesUnique)
%     InNamesFreq(i)=sum(cell2mat(strfind(InNames,InNamesUnique{i})));
% end
% 
% [InNamesFreq,SortFreqIdx]=sort(InNamesFreq,2,'descend');
% 
% InNamesUnique=InNamesUnique(SortFreqIdx);

% IdealOrder=[OutNamesUnique;InNamesUnique];
% %%
% for i=1:numel(ParentsUnique)
%     InPorts=find_system(ParentsUnique{i},'FindAll','on','SearchDepth',1,'BlockType','Inport');
%     OutPorts=find_system(ParentsUnique{i},'FindAll','on','SearchDepth',1,'BlockType','Outport');
%     open_system(ParentsUnique{i});
%     InNames=get(InPorts,'Name');
%     OutNames=get(OutPorts,'Name');
%     InPortIdx=zeros(1,numel(InNames));
%     if iscell(InNames)
%         idx=1;
%         for j=1:numel(IdealOrder)
%             if ~ismember(InNames,IdealOrder{j})
%                 continue;
%             end
%             for k=1:numel(InNames)
%                 if strcmp(IdealOrder{j},InNames{k})
%                     set(InPorts(k),'Port',num2str(idx));
%                     idx=idx+1;
%                     break;
%                 end
%             end
%         end
%     end
%     
%     if iscell(OutNames)
%         idx=1;
%         for j=1:numel(IdealOrder)
%             if ~ismember(OutNames,IdealOrder{j})
%                 continue;
%             end
%             for k=1:numel(OutNames)
%                 if strcmp(IdealOrder{j},OutNames{k})
%                     set(OutPorts(k),'Port',num2str(idx));
%                     idx=idx+1;
%                     break;
%                 end
%             end
%         end
%     end
%     alignIO(ParentsUnique{i});
%     close_system(ParentsUnique{i});
% end