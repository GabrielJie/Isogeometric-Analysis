function generate_bcFile(numRefinements)
    % Set the path to the assembly files directory
    directory_assembly = sprintf('../assembly_files/numRefinements%d/', numRefinements);
    
    % File paths
    file_assembly_global = strcat(directory_assembly, 'file_assembly_global');
    file_assembly_patch  = strcat(directory_assembly, 'file_assembly_patch');
    
    % Load the global assembly file
    load(file_assembly_global, ...
         'numPatches', ...
         'numNodesOnPatch', ...
         'numDOFs', ...
         'numDOFsPerNode', ...
         'GN_array');
    
    
    %----------------------------------------------------------------------
    %  Initialize the BC arrays
    %----------------------------------------------------------------------
    BCs_displacement = [];
    BCs_force = [];
    
    
    %----------------------------------------------------------------------
    % ---------------------------------------------------------------------
    %   Begin: Set BCs for patch 1
    % ---------------------------------------------------------------------
    %----------------------------------------------------------------------
    load(sprintf('%s%d', file_assembly_patch, 1), ...
         'numNodesPerElement1', ...
         'numNodesPerElement2', ...
         'numNodesPerElement3', ...
         'numElements1', ...
         'numElements2', ...
         'numElements3', ...
         'IEN_array');
    
    
    %----------------------------------------------------------------------
    %  Displacements for top grip
    %----------------------------------------------------------------------
    % Element index for the grip along direction 1
    numElements1_grip = 2^floor((numRefinements + 1) / 2);
    elementIndex1_grip = (1 : numElements1_grip)';
    
    
    % Degrees of freedom and BC values
    dofIndex = [1; 2; 3];
    bcValue = [0; 0; 0];
    
    
    % y-z surface, x = 0
    BCs_numNodes = (1 * numElements2 * numElements3) * (1 * numNodesPerElement2 * numNodesPerElement3);
    
    elementIndex = find_element_index(1, ...
                                      (1 : numElements2)', ...
                                      (1 : numElements3)', ...
                                      numElements1, ...
                                      numElements2, ...
                                      numElements3);
    
    nodeIndex = find_node_index(1, ...
                                (1 : numNodesPerElement2)', ...
                                (1 : numNodesPerElement3)', ...
                                numNodesPerElement1, ...
                                numNodesPerElement2, ...
                                numNodesPerElement3, ...
                                IEN_array(:, elementIndex));
    
    BCs_displacement = [BCs_displacement; ...
                        [kron(GN_array(nodeIndex), ones(3, 1)), repmat(dofIndex, BCs_numNodes, 1), repmat(bcValue, BCs_numNodes, 1)]];
    
    %{
    % x-y surface, z = 0
    BCs_numNodes = (numElements1_grip * numElements2 * 1) * (numNodesPerElement1 * numNodesPerElement2 * 1);
    
    elementIndex = find_element_index(elementIndex1_grip, ...
                                      (1 : numElements2)', ...
                                      1, ...
                                      numElements1, ...
                                      numElements2, ...
                                      numElements3);
    
    nodeIndex = find_node_index((1 : numNodesPerElement1)', ...
                                (1 : numNodesPerElement2)', ...
                                1, ...
                                numNodesPerElement1, ...
                                numNodesPerElement2, ...
                                numNodesPerElement3, ...
                                IEN_array(:, elementIndex));
    
    BCs_displacement = [BCs_displacement; ...
                        [kron(GN_array(nodeIndex), ones(3, 1)), repmat(dofIndex, BCs_numNodes, 1), repmat(bcValue, BCs_numNodes, 1)]];
    
    
    % x-y surface, z = bar_thickness
    BCs_numNodes = (numElements1_grip * numElements2 * 1) * (numNodesPerElement1 * numNodesPerElement2 * 1);
    
    elementIndex = find_element_index(elementIndex1_grip, ...
                                      (1 : numElements2)', ...
                                      numElements3, ...
                                      numElements1, ...
                                      numElements2, ...
                                      numElements3);
    
    nodeIndex = find_node_index((1 : numNodesPerElement1)', ...
                                (1 : numNodesPerElement2)', ...
                                numNodesPerElement3, ...
                                numNodesPerElement1, ...
                                numNodesPerElement2, ...
                                numNodesPerElement3, ...
                                IEN_array(:, elementIndex));
    
    BCs_displacement = [BCs_displacement; ...
                        [kron(GN_array(nodeIndex), ones(3, 1)), repmat(dofIndex, BCs_numNodes, 1), repmat(bcValue, BCs_numNodes, 1)]];
    
    
    % x-z surface, y = 0
    BCs_numNodes = (numElements1_grip * 1 * numElements3) * (numNodesPerElement1 * 1 * numNodesPerElement3);
    
    elementIndex = find_element_index(elementIndex1_grip, ...
                                      1, ...
                                      (1 : numElements3)', ...
                                      numElements1, ...
                                      numElements2, ...
                                      numElements3);
    
    nodeIndex = find_node_index((1 : numNodesPerElement1)', ...
                                1, ...
                                (1 : numNodesPerElement3)', ...
                                numNodesPerElement1, ...
                                numNodesPerElement2, ...
                                numNodesPerElement3, ...
                                IEN_array(:, elementIndex));
    
    BCs_displacement = [BCs_displacement; ...
                        [kron(GN_array(nodeIndex), ones(3, 1)), repmat(dofIndex, BCs_numNodes, 1), repmat(bcValue, BCs_numNodes, 1)]];
    
    
    % x-z surface, y = grip_width
    BCs_numNodes = (numElements1_grip * 1 * numElements3) * (numNodesPerElement1 * 1 * numNodesPerElement3);
    
    elementIndex = find_element_index(elementIndex1_grip, ...
                                      numElements2, ...
                                      (1 : numElements3)', ...
                                      numElements1, ...
                                      numElements2, ...
                                      numElements3);
    
    nodeIndex = find_node_index((1 : numNodesPerElement1)', ...
                                numNodesPerElement2, ...
                                (1 : numNodesPerElement3)', ...
                                numNodesPerElement1, ...
                                numNodesPerElement2, ...
                                numNodesPerElement3, ...
                                IEN_array(:, elementIndex));
    
    BCs_displacement = [BCs_displacement; ...
                        [kron(GN_array(nodeIndex), ones(3, 1)), repmat(dofIndex, BCs_numNodes, 1), repmat(bcValue, BCs_numNodes, 1)]];
    %}
    
    %----------------------------------------------------------------------
    %  Displacements for bottom grip
    %----------------------------------------------------------------------
    % Element index for the grip along direction 1
    numElements1_grip = 2^floor((numRefinements + 1) / 2);
    elementIndex1_grip = ((numElements1 - numElements1_grip + 1) : numElements1)';
    
    
    % Degrees of freedom and BC values
    dofIndex = [1; 2; 3];
    bcValue = [10e-3; 0; 0];
    
    
    % y-z surface, x = bar_totalLength
    BCs_numNodes = (1 * numElements2 * numElements3) * (1 * numNodesPerElement2 * numNodesPerElement3);
    
    elementIndex = find_element_index(numElements1, ...
                                      (1 : numElements2)', ...
                                      (1 : numElements3)', ...
                                      numElements1, ...
                                      numElements2, ...
                                      numElements3);
    
    nodeIndex = find_node_index(numNodesPerElement1, ...
                                (1 : numNodesPerElement2)', ...
                                (1 : numNodesPerElement3)', ...
                                numNodesPerElement1, ...
                                numNodesPerElement2, ...
                                numNodesPerElement3, ...
                                IEN_array(:, elementIndex));
    
    BCs_displacement = [BCs_displacement; ...
                        [kron(GN_array(nodeIndex), ones(3, 1)), repmat(dofIndex, BCs_numNodes, 1), repmat(bcValue, BCs_numNodes, 1)]];
    
    %{
    % x-y surface, z = 0
    BCs_numNodes = (numElements1_grip * numElements2 * 1) * (numNodesPerElement1 * numNodesPerElement2 * 1);
    
    elementIndex = find_element_index(elementIndex1_grip, ...
                                      (1 : numElements2)', ...
                                      1, ...
                                      numElements1, ...
                                      numElements2, ...
                                      numElements3);
    
    nodeIndex = find_node_index((1 : numNodesPerElement1)', ...
                                (1 : numNodesPerElement2)', ...
                                1, ...
                                numNodesPerElement1, ...
                                numNodesPerElement2, ...
                                numNodesPerElement3, ...
                                IEN_array(:, elementIndex));
    
    BCs_displacement = [BCs_displacement; ...
                        [kron(GN_array(nodeIndex), ones(3, 1)), repmat(dofIndex, BCs_numNodes, 1), repmat(bcValue, BCs_numNodes, 1)]];
    
    
    % x-y surface, z = bar_thickness
    BCs_numNodes = (numElements1_grip * numElements2 * 1) * (numNodesPerElement1 * numNodesPerElement2 * 1);
    
    elementIndex = find_element_index(elementIndex1_grip, ...
                                      (1 : numElements2)', ...
                                      numElements3, ...
                                      numElements1, ...
                                      numElements2, ...
                                      numElements3);
    
    nodeIndex = find_node_index((1 : numNodesPerElement1)', ...
                                (1 : numNodesPerElement2)', ...
                                numNodesPerElement3, ...
                                numNodesPerElement1, ...
                                numNodesPerElement2, ...
                                numNodesPerElement3, ...
                                IEN_array(:, elementIndex));
    
    BCs_displacement = [BCs_displacement; ...
                        [kron(GN_array(nodeIndex), ones(3, 1)), repmat(dofIndex, BCs_numNodes, 1), repmat(bcValue, BCs_numNodes, 1)]];
    
    
    % x-z surface, y = 0
    BCs_numNodes = (numElements1_grip * 1 * numElements3) * (numNodesPerElement1 * 1 * numNodesPerElement3);
    
    elementIndex = find_element_index(elementIndex1_grip, ...
                                      1, ...
                                      (1 : numElements3)', ...
                                      numElements1, ...
                                      numElements2, ...
                                      numElements3);
    
    nodeIndex = find_node_index((1 : numNodesPerElement1)', ...
                                1, ...
                                (1 : numNodesPerElement3)', ...
                                numNodesPerElement1, ...
                                numNodesPerElement2, ...
                                numNodesPerElement3, ...
                                IEN_array(:, elementIndex));
    
    BCs_displacement = [BCs_displacement; ...
                        [kron(GN_array(nodeIndex), ones(3, 1)), repmat(dofIndex, BCs_numNodes, 1), repmat(bcValue, BCs_numNodes, 1)]];
    
    
    % x-z surface, y = grip_width
    BCs_numNodes = (numElements1_grip * 1 * numElements3) * (numNodesPerElement1 * 1 * numNodesPerElement3);
    
    elementIndex = find_element_index(elementIndex1_grip, ...
                                      numElements2, ...
                                      (1 : numElements3)', ...
                                      numElements1, ...
                                      numElements2, ...
                                      numElements3);
    
    nodeIndex = find_node_index((1 : numNodesPerElement1)', ...
                                numNodesPerElement2, ...
                                (1 : numNodesPerElement3)', ...
                                numNodesPerElement1, ...
                                numNodesPerElement2, ...
                                numNodesPerElement3, ...
                                IEN_array(:, elementIndex));
    
    BCs_displacement = [BCs_displacement; ...
                        [kron(GN_array(nodeIndex), ones(3, 1)), repmat(dofIndex, BCs_numNodes, 1), repmat(bcValue, BCs_numNodes, 1)]];
    %}
    
    %----------------------------------------------------------------------
    % ---------------------------------------------------------------------
    %   End: Set BCs for patch 1
    % ---------------------------------------------------------------------
    %----------------------------------------------------------------------
    
    
    
    %----------------------------------------------------------------------
    %  Build the ID array and BC array
    %----------------------------------------------------------------------
    ID_array = build_id_array(BCs_displacement, numDOFsPerNode, GN_array);
    
    [BCU_array, BCF_array] = build_bc_array(BCs_displacement, BCs_force, ID_array);
    
    % Number of unknown degrees of freedom
    numUnknownDOFs = numDOFs - size(BCU_array, 1);
    
    clear BCs_displacement BCs_force;
    
    
    %----------------------------------------------------------------------
    %  Save the BC files
    %----------------------------------------------------------------------
    save(sprintf('%sfile_bc', directory_assembly), ...
         'ID_array', ...
         'BCU_array', ...
         'BCF_array', ...
         'numUnknownDOFs', ...
         '-v7.3');
end