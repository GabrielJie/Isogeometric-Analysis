%--------------------------------------------------------------------------
%  Author: Isaac J. Lee (ijlee2@ices.utexas.edu)
%  
%  
%  Summary:
%  
%  This routine creates the assembly files for the problem of a 2D square
%  plate with a circular hole that is subjected to a uniaxial tension.
%  We use symmetry and model a quarter of the plate, and use quadratic
%  NURBS as basis functions.
%  
%  
%  Instructions:
%  
%  Use the terminal to run the driver file with this command:
%  
%      ./matbg.sh driver_generate_assemblyFile.m output
%  
%  Note that,
%  
%      numRefinements is the number of times we h-refine the knot vectors
%  
%  
%  Output:
%  
%  1. Assembly files (.mat files)
%--------------------------------------------------------------------------
function generate_assemblyFile(numRefinements)
    % Set the path to the assembly files directory
    directory_assembly = sprintf('../assembly_files/numRefinements%d/', numRefinements);
    
    % Create the directory if it does not exist
    if ~exist(directory_assembly, 'dir')
        mkdir(directory_assembly);
    end
    
    % File paths
    file_assembly_global = strcat(directory_assembly, 'file_assembly_global');
    file_assembly_patch  = strcat(directory_assembly, 'file_assembly_patch');
    
    
    %----------------------------------------------------------------------
    %  Initialize parameters for FEM
    %----------------------------------------------------------------------
    % Number of patches
    numPatches = 1;
    
    % Number of elements on each patch
    numElementsOnPatch = zeros(numPatches, 1);
    
    % Number of nodes on each patch
    numNodesOnPatch = zeros(numPatches, 1);
    
    % Number of nodes encountered before the patch
    numNodesBeforePatch = zeros(numPatches, 1);
    
    % Number of matrix entries that will be computed
    numMatrixEntries = 0;
    
    % Number of degrees of freedom (DOFs)
    numDOFs = 0;
    
    % Number of DOFs (fields) defined on each node
    numDOFsPerNode = 2;
    
    % Shared nodes array
    SN_array = [];
    
    % Global nodes array
    GN_array = [];
    
    
    %----------------------------------------------------------------------
    %  Initialize parameters for 2D plane stress
    %----------------------------------------------------------------------
    % Cross-sectional thickness (m)
    material_thickness = 0.002;
    
    
    %----------------------------------------------------------------------
    %  Create an array of NURBS structs
    %  
    %  description
    %      -- the description of the NURBS patch used for debugging 
    %      -- string
    %  
    %  knots1, knots2, knots3
    %      -- the knot vectors in directions 1, 2, and 3
    %      -- column vectors
    %  
    %  nodes
    %      -- the control points in the physical space
    %      -- matrix with d columns, where d is the dimension
    %  
    %  p1, p2, p3
    %      -- the degree of the NURBS in directions 1, 2, and 3
    %      -- positive integers
    %----------------------------------------------------------------------
    patches(numPatches) = ...
        struct('elementType'        , 'NURBS', ...
               'description'        , '', ...
               'material_E'         , 0, ...
               'material_nu'        , 0, ...
               'p1'                 , 0, ...
               'p2'                 , 0, ...
               'p3'                 , 0, ...
               'knots1'             , [], ...
               'knots2'             , [], ...
               'knots3'             , [], ...
               'nodes'              , [], ...
               'numNodes1'          , 0, ...
               'numNodes2'          , 0, ...
               'numNodes3'          , 0, ...
               'numNodesPerElement1', 0, ...
               'numNodesPerElement2', 0, ...
               'numNodesPerElement3', 0, ...
               'numNodesPerElement' , 0, ...
               'numDOFsPerElement'  , 0, ...
               'bezierExtractions1' , [], ...
               'bezierExtractions2' , [], ...
               'bezierExtractions3' , [], ...
               'numElements1'       , 0, ...
               'numElements2'       , 0, ...
               'numElements3'       , 0, ...
               'elementSizes1'      , [], ...
               'elementSizes2'      , [], ...
               'elementSizes3'      , [], ...
               'IEN_array'          , [], ...
               'numQuadraturePoints', []);
    
    
    %----------------------------------------------------------------------
    %  Set the description
    %----------------------------------------------------------------------
    patches(1).description = strcat('2D square plate with a circular hole, refinement level', sprintf(' %d', numRefinements));
    
    
    %----------------------------------------------------------------------
    %  Set the material parameters
    %----------------------------------------------------------------------
    patches(1).material_E = 210e9;    % Young's modulus (Pa)
    patches(1).material_nu = 0.3;     % Poisson's ratio (dimensionless)
    
    
    %----------------------------------------------------------------------
    %  Set the degrees
    %----------------------------------------------------------------------
    patches(1).p1 = 2;
    patches(1).p2 = 2;
    
    
    %----------------------------------------------------------------------
    %  Set the knots
    %----------------------------------------------------------------------
    patches(1).knots1 = [0; 0; 0; 1; 2; 2; 2];
    patches(1).knots2 = [0; 0; 0; 2; 2; 2];
    
    
    %----------------------------------------------------------------------
    %  Set the nodes
    %----------------------------------------------------------------------
    % Parameters for specimen size (all lengths in m)
    plate_length = 0.1;               % The plate has length and width of 2L
    hole_radius = 0.01;               % Radius of the circular hole
    
    % Some useful constants
    plate_middle = (hole_radius + plate_length) / 2;
    constant_sq2m1 = sqrt(2) - 1;
    w23 = (2 + sqrt(2)) / 4;
    
    patches(1).nodes = [0                            , hole_radius                  , 1; ...
                        constant_sq2m1 * hole_radius , hole_radius                  , w23; ...
                        hole_radius                  , constant_sq2m1 * hole_radius , w23; ...
                        hole_radius                  , 0                            , 1; ...
                        ...
                        0                            , plate_middle                 , 1; ...
                        constant_sq2m1 * plate_middle, plate_middle                 , w23; ...
                        plate_middle                 , constant_sq2m1 * plate_middle, w23; ...
                        plate_middle                 , 0                            , 1; ...
                        ...
                        0                            , plate_length                 , 1; ...
                        plate_length                 , plate_length                 , w23; ...
                        plate_length                 , plate_length                 , w23; ...
                        plate_length                 , 0                            , 1];
    
    
    %----------------------------------------------------------------------
    %  Project the NURBS nodes to B-spline nodes for degree elevation and
    %  knot refinement
    %----------------------------------------------------------------------
    for p = 1 : numPatches
        patches(p).nodes = project_up(patches(p).nodes);
    end
    
    
    %----------------------------------------------------------------------
    %  Elevate the degrees
    %----------------------------------------------------------------------
    %{
    for p = 1 : numPatches
        % Elevate the degree to 2 in all directions
        [patches(p).knots1, patches(p).knots2, patches(p).nodes, patches(p).p1, patches(p).p2] = ...
            refine_p_surface(patches(p).knots1, ...
                             patches(p).knots2, ...
                             patches(p).nodes, ...
                             patches(p).p1, ...
                             patches(p).p2, ...
                             0, 0);
    end
    %}
    
    
    %----------------------------------------------------------------------
    %  Refine the knots
    %----------------------------------------------------------------------
    % Set the knots for insertion
    temp1 = setdiff((0 : 0.5^numRefinements : 1)', [0; 1]);
    temp2 = setdiff((0 : 0.5^numRefinements : 2)', [0; 2]);
    
    knotsForInsertion1 = [(0 + temp1); (1 + temp1)];
    knotsForInsertion2 = temp2;
    
    clear temp1 temp2;
    
    % Refine the knot vectors
    [patches(1).knots1, patches(1).knots2, patches(1).nodes] = ...
        refine_h_surface(patches(1).knots1, ...
                         patches(1).knots2, ...
                         patches(1).nodes, ...
                         patches(1).p1, ...
                         patches(1).p2, ...
                         knotsForInsertion1, knotsForInsertion2);
    
    clear knotsForInsertion1 knotsForInsertion2;
    
    
    %----------------------------------------------------------------------
    %  Project the B-spline nodes back to NURBS nodes
    %----------------------------------------------------------------------
    for p = 1 : numPatches
        patches(p).nodes = project_down(patches(p).nodes);
        
        % Draw the NURBS patch (for debugging)
%        draw_nurbs_surface(patches(p).knots1, patches(p).knots2, patches(p).nodes, patches(p).p1, patches(p).p2);
%        axis image;
%        return;
    end
    
    
    %----------------------------------------------------------------------
    %  Build the Bezier extractions and the IEN array
    %----------------------------------------------------------------------
    for p = 1 : numPatches
        [patches(p).bezierExtractions1, nodeIndexShifts1, patches(p).numElements1, patches(p).elementSizes1] = build_bezier_extraction(patches(p).knots1, patches(p).p1);
        [patches(p).bezierExtractions2, nodeIndexShifts2, patches(p).numElements2, patches(p).elementSizes2] = build_bezier_extraction(patches(p).knots2, patches(p).p2);
        
        patches(p).IEN_array = build_ien_array(patches(p).knots1, ...
                                               patches(p).knots2, ...
                                               [], ...
                                               patches(p).p1, ...
                                               patches(p).p2, ...
                                               [], ...
                                               nodeIndexShifts1, ...
                                               nodeIndexShifts2, ...
                                               []);
    end
    
    clear nodeIndexShifts1 nodeIndexShifts2;
    
    
    %----------------------------------------------------------------------
    %  Find the numbers of nodes, elements, and matrix entries
    %----------------------------------------------------------------------
    for p = 1 : numPatches
        % Number of nodes along each direction
        patches(p).numNodes1 = size(patches(p).knots1, 1) - (patches(p).p1 + 1);
        patches(p).numNodes2 = size(patches(p).knots2, 1) - (patches(p).p2 + 1);
        
        % Number of nodes on the patch
        numNodesOnPatch(p) = patches(p).numNodes1 * patches(p).numNodes2;
        
        % Number of nodes before the patch
        if (p > 1)
            numNodesBeforePatch(p) = numNodesBeforePatch(p - 1) + numNodesOnPatch(p - 1);
        end
        
        % Number of elements on the patch
        numElementsOnPatch(p) = patches(p).numElements1 * patches(p).numElements2;
        
        % Number of nodes on each element along each direction
        patches(p).numNodesPerElement1 = patches(p).p1 + 1;
        patches(p).numNodesPerElement2 = patches(p).p2 + 1;
        patches(p).numNodesPerElement = patches(p).numNodesPerElement1 * patches(p).numNodesPerElement2;
        
        % Number of DOFs on each element
        patches(p).numDOFsPerElement = numDOFsPerNode * patches(p).numNodesPerElement;
        
        % Number of matrix entries that we will compute as a result
        numMatrixEntriesPerElement = patches(p).numDOFsPerElement^2;
        numMatrixEntries = numMatrixEntries + numMatrixEntriesPerElement * numElementsOnPatch(p);
    end
    
    
    %----------------------------------------------------------------------
    %  Build the SN array
    %  [my patch index, my node index, target patch index, target node index]
    %----------------------------------------------------------------------
    SN_array = [];
    
    
    %----------------------------------------------------------------------
    %  Build the GN array
    %----------------------------------------------------------------------
    GN_array = build_gn_array(SN_array, numNodesOnPatch);
    
    % Number of degrees of freedom
    numDOFs = numDOFsPerNode * size(unique(GN_array), 1);
    
    
    %----------------------------------------------------------------------
    %  Set the quadrature rule
    %----------------------------------------------------------------------
    for p = 1 : numPatches
        patches(p).numQuadraturePoints = [3; 3];
    end
    
    
    %----------------------------------------------------------------------
    %  Save the assembly files
    %----------------------------------------------------------------------
    % Assembly file for the global structure
    save(file_assembly_global, ...
         'numPatches'         , ...
         'numElementsOnPatch' , ...
         'numNodesOnPatch'    , ...
         'numNodesBeforePatch', ...
         'numMatrixEntries'   , ...
         'numDOFs'            , ...
         'numDOFsPerNode'     , ...
         'SN_array'           , ...
         'GN_array'           , ...
         ...
         'material_thickness' , ...
         '-v7.3');
    
    % Assembly file for the patches
    for p = 1 : numPatches
        elementType         = patches(p).elementType;
        description         = patches(p).description;
        material_E          = patches(p).material_E;
        material_nu         = patches(p).material_nu;
        p1                  = patches(p).p1;
        p2                  = patches(p).p2;
        p3                  = patches(p).p3;
        knots1              = patches(p).knots1;
        knots2              = patches(p).knots2;
        knots3              = patches(p).knots3;
        nodes               = patches(p).nodes;
        numNodes1           = patches(p).numNodes1;
        numNodes2           = patches(p).numNodes2;
        numNodes3           = patches(p).numNodes3;
        numNodesPerElement1 = patches(p).numNodesPerElement1;
        numNodesPerElement2 = patches(p).numNodesPerElement2;
        numNodesPerElement3 = patches(p).numNodesPerElement3;
        numNodesPerElement  = patches(p).numNodesPerElement;
        numDOFsPerElement   = patches(p).numDOFsPerElement;
        bezierExtractions1  = patches(p).bezierExtractions1;
        bezierExtractions2  = patches(p).bezierExtractions2;
        bezierExtractions3  = patches(p).bezierExtractions3;
        numElements1        = patches(p).numElements1;
        numElements2        = patches(p).numElements2;
        numElements3        = patches(p).numElements3;
        elementSizes1       = patches(p).elementSizes1;
        elementSizes2       = patches(p).elementSizes2;
        elementSizes3       = patches(p).elementSizes3;
        IEN_array           = patches(p).IEN_array;
        numQuadraturePoints = patches(p).numQuadraturePoints;
        
        save(sprintf('%s%d', file_assembly_patch, p), ...
             'elementType'        , ...
             'description'        , ...
             'material_E'         , ...
             'material_nu'        , ...
             'p1'                 , ...
             'p2'                 , ...
             'p3'                 , ...
             'knots1'             , ...
             'knots2'             , ...
             'knots3'             , ...
             'nodes'              , ...
             'numNodes1'          , ...
             'numNodes2'          , ...
             'numNodes3'          , ...
             'numNodesPerElement1', ...
             'numNodesPerElement2', ...
             'numNodesPerElement3', ...
             'numNodesPerElement' , ...
             'numDOFsPerElement'  , ...
             'bezierExtractions1' , ...
             'bezierExtractions2' , ...
             'bezierExtractions3' , ...
             'numElements1'       , ...
             'numElements2'       , ...
             'numElements3'       , ...
             'elementSizes1'      , ...
             'elementSizes2'      , ...
             'elementSizes3'      , ...
             'IEN_array'          , ...
             'numQuadraturePoints', ...
             '-v7.3');
    end
    
    
    %----------------------------------------------------------------------
    %  Set the boundary conditions
    %----------------------------------------------------------------------
    generate_bcFile(numRefinements);
end