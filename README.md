# Simulink: Optimal Port Order



``optimalPortOrder`` - Orders the ports of subsystems to minimize line crossings. It does this by taking determining the order the blocks are arranged in (Either vertically or horizontally). And then finding all of the port names for that block then determining if ports occur before or after that subsystem

I like my Simulink models to look like German utility rooms. Nice and clean. This was a deterministic way to generate an 'optimal' port order.

	
	
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