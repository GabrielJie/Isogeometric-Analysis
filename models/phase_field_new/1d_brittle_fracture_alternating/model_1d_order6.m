%--------------------------------------------------------------------------
%  Author: Isaac J. Lee (ijlee2@ices.utexas.edu)
%  
%  
%  Summary:
%  
%  This routine solves the problem of 1D cracked bar in tension, so that
%  we can validate the 6th-order phase field theory for brittle fracture.
%  
%  We alternatingly solve the momentum and phase field equations (direct
%  method) to get the displacement and phase fields.
%  
%  
%  Instructions:
%  
%  Use the terminal to run the driver file with this command:
%  
%      ./matbg.sh driver_order6.m output
%  
%  Note that,
%  
%      path_to_assembly_directory is the path to the assembly files directory
%      path_to_results_directory is the path to the results directory
%      restartTime is the alternation step at which we start the simulation
%  
%  
%  Output:
%  
%  1. Coefficients for the displacement and phase fields (.mat files)
%--------------------------------------------------------------------------
function model_1d_order6(path_to_assembly_directory, path_to_results_directory, restartTime)
    % Feedback for user
    fprintf('\n');
    fprintf('----------------------------------------------------------------\n');
    fprintf('----------------------------------------------------------------\n\n');
    fprintf('  6th-order phase field theory in 1D.\n\n');
    
    
    % Load the global assembly file
    load(sprintf('%sfile_assembly_global', path_to_assembly_directory), ...
         'numPatches'         , ...
         'numNodesBeforePatch', ...
         'numMatrixEntries'   , ...
         'numDOFs'            , ...
         'numDOFsPerNode'     , ...
         ...
         'material_A'         , ...
         'material_G_c'       , ...
         'material_ell_0'     , ...
         ...
         'maxAlternations');
    
    % Load the patch assembly file
    load(sprintf('%sfile_assembly_patch%d', path_to_assembly_directory, 1), ...
         'elementType'       , ...
         'material_E'        , ...
         'p1'                , ...
         'nodes'             , ...
         'numNodesPerElement', ...
         'numDOFsPerElement' , ...
         'bezierExtractions1', ...
         'numElements1'      , ...
         'elementSizes1'     , ...
         'IEN_array'         , ...
         'numQuadraturePoints');
    
    % Load the BCs
    load(sprintf('%sfile_bc', path_to_assembly_directory), ...
         'LM_array1'      , 'LM_array2'      , ...
         'BCU_array1'     , 'BCU_array2'     , ...
         'BCF_array1'     , 'BCF_array2'     , ...
         'numUnknownDOFs1', 'numUnknownDOFs2', ...
         'index_u1'       , 'index_u2'       , ...
         'index_f1'       , 'index_f2');
    
    
    
    %----------------------------------------------------------------------
    %  Initialize the fields
    %----------------------------------------------------------------------
    if (restartTime == 0)
        initialize(6, path_to_assembly_directory, path_to_results_directory);
        load(sprintf('%sfile_results_alternation%d', path_to_results_directory, 0), 'u1', 'u2');
        
    else
        load(sprintf('%sfile_results_alternation%d', path_to_results_directory, restartTime), 'u1', 'u2');
        
    end
    
    
    %----------------------------------------------------------------------
    %  Set quadrature rule
    %----------------------------------------------------------------------
    % Some useful constants for quadrature
    constant_p1p1 = p1 + 1;
    
    % Set the quadrature rule
    [z1, w] = set_1d_gauss_quadrature_for_bernstein(numQuadraturePoints);
    numQuadraturePointsPerElement = numQuadraturePoints;
    
    
    % Evaluate the Bernstein polynomials for direction 1 at the
    % quadrature points
    Bernstein1_der0 = zeros(constant_p1p1, numQuadraturePoints);
    Bernstein1_der1 = zeros(constant_p1p1, numQuadraturePoints);
    Bernstein1_der2 = zeros(constant_p1p1, numQuadraturePoints);
    Bernstein1_der3 = zeros(constant_p1p1, numQuadraturePoints);
    
    for q_e = 1 : numQuadraturePoints
        temp = eval_1d_bernstein_der(z1(q_e), p1);
        
        Bernstein1_der0(:, q_e) = temp(:, 1);
        Bernstein1_der1(:, q_e) = temp(:, 2);
        Bernstein1_der2(:, q_e) = temp(:, 3);
        Bernstein1_der3(:, q_e) = temp(:, 4);
    end
    
    clear z1 temp;
    
    
    
    %----------------------------------------------------------------------
    % ---------------------------------------------------------------------
    %   Begin: Loop over alterations
    % ---------------------------------------------------------------------
    %----------------------------------------------------------------------
    % Some useful constants for phase field theory
    constant_stiffness = material_E * material_A;
    constant_G_c       = material_G_c * material_A / (2 * material_ell_0);
    constant_ell_0_sq  = material_ell_0^2;
    
    
    % Some useful constant for global assembly
    constant_p1p1_sq = constant_p1p1^2;
    
    
    % Initialization for element matrices K11, K12, K22
    elementMatrix = zeros(constant_p1p1);
    
    % Initialization for element vectors f1, f2
    elementVector = zeros(constant_p1p1, 1);
    
    
    % Vector of ones for global assembly
    vector_of_ones = ones(constant_p1p1, 1);
    
    % Vector of indices for element matrices
    indices_for_elementMatrix = (1 : constant_p1p1_sq)';
    
    
    % Number of matrix entries that we compute for the momentum and
    % phase field equations
    numMatrixEntriesPerElement = constant_p1p1_sq;
    
    % Initialize row, column, value arrays for the stiffness matrices
    % K11 and K22
    temp = zeros(numMatrixEntriesPerElement * numElements1, 1);
    
    rows_for_K    = temp;
    columns_for_K = temp;
    values_for_K  = temp;
    
    clear temp;
    
    
    for alternation = (restartTime + 1) : maxAlternations
        fprintf('\n');
        fprintf('- Alternation index = %d\n', alternation);
        
        
        
        %------------------------------------------------------------------
        % -----------------------------------------------------------------
        %   1. Find the displacement field (u1)
        % -----------------------------------------------------------------
        %------------------------------------------------------------------
        % Initialize the RHS vector and prescribe the known forces
        f1 = zeros(numDOFs, 1);
        f1(BCF_array1(:, 1)) = BCF_array1(:, 2);
        
        % Index that was last used to set the entry of K
        lastIndex_for_K = 0;
        
        
        
        %------------------------------------------------------------------
        % -----------------------------------------------------------------
        %   Begin: Loop over elements (e = e1)
        % -----------------------------------------------------------------
        %------------------------------------------------------------------
        for e = 1 : numElements1
            % Find the Bezier extraction matrix
            bezierExtractions1_e = bezierExtractions1(:, :, e);
            
            % Evaluate the map derivative dt/dxi (constant)
            dt_dxi = 1 / elementSizes1(e);
            
            
            %--------------------------------------------------------------
            %  Evaluate the basis functions in the parametric domain
            %  Matrix: (numNodesPerElement) x (numQuadraturePointsPerElement)
            %--------------------------------------------------------------
            % Find the positions of the nodes
            nodes_e = nodes(IEN_array(:, e), :)';
            
            % Evaluate the B-splines
            basis_der0 =           bezierExtractions1_e  * Bernstein1_der0;
            basis_der1 = (dt_dxi * bezierExtractions1_e) * Bernstein1_der1;
            
            
            %--------------------------------------------------------------
            %  Evaluate the map derivatives (x = x1)
            %  Matrix: (numDOFsPerNode) x (numQuadraturePointsPerElement)
            %--------------------------------------------------------------
            dx_dxi = nodes_e * basis_der1;
            
            
            
            %--------------------------------------------------------------
            % -------------------------------------------------------------
            %   Begin: Loop over quadrature points (q_e)
            % -------------------------------------------------------------
            %--------------------------------------------------------------
            % Initialize the element stiffness matrix and the element
            % internal force vector
            K11_e = elementMatrix;
%           f1_e  = elementVector;
            
            % Find the equation indices for the element
            index_equation1 = LM_array1(:, e);
            index_equation2 = LM_array2(:, e);
            
            % Find the coefficients of the phase field
            u2_e = u2(index_equation2)';
            
            
            for q_e = 1 : numQuadraturePointsPerElement
                %----------------------------------------------------------
                %  Form the Jacobian matrix
                %  Matrix: (numDOFsPerNode) x (numDOFsPerNode)
                %----------------------------------------------------------
                JacobianMatrix = dx_dxi(:, q_e);
                
                % Evaluate the Jacobian
                Jacobian = JacobianMatrix / dt_dxi;
                
                if (Jacobian <= 0)
                    fprintf('\n');
                    fprintf('  Error: Jacobian is not positive for e = %d, q_e = %d. The problem will be left unsolved.\n\n', e, q_e);
                    
                    quit;
                end
                
                
                %----------------------------------------------------------
                %  Evaluate the basis functions in the physical domain
                %  Matrix: (numDOFsPerNode) x (numNodesPerElement)
                %----------------------------------------------------------
                JacobianMatrix_inv = 1 / JacobianMatrix;
                
                basis_physical_der0 =                      basis_der0(:, q_e);
                basis_physical_der1 = JacobianMatrix_inv * basis_der1(:, q_e);
                
                
                %----------------------------------------------------------
                %  Evaluate the phase field
                %----------------------------------------------------------
                c_der0 = u2_e * basis_physical_der0;
                
                
                %----------------------------------------------------------
                %  Form the element matrix K11
                %----------------------------------------------------------
                % Coefficients for the (regular) phase field theory.
                % The subscripts denote the derivatives of N_A and N_B.
                C11 = constant_stiffness * c_der0^2;
                
                K11_e = K11_e + (w(q_e) * Jacobian * C11) * (basis_physical_der1 * basis_physical_der1');
                
                
                %----------------------------------------------------------
                %  Form the element RHS vector f1
                %----------------------------------------------------------
%               f1_e = f1_e + (w(q_e) * Jacobian * 0) * basis_physical_der0;
            end
            
            
            %--------------------------------------------------------------
            % -------------------------------------------------------------
            %   End: Loop over quadrature points
            % -------------------------------------------------------------
            %--------------------------------------------------------------
            
            
            %--------------------------------------------------------------
            %  Global assembly
            %--------------------------------------------------------------
            % Add the element matrix K11
            index = lastIndex_for_K + indices_for_elementMatrix;
            
            rows_for_K(index)    = kron(vector_of_ones, index_equation1);
            columns_for_K(index) = kron(index_equation1, vector_of_ones);
            values_for_K(index)  = reshape(K11_e, constant_p1p1_sq, 1);
            
            lastIndex_for_K = lastIndex_for_K + constant_p1p1_sq;
            
            
            % Add the element RHS vector f1
%           f1(index_equation1) = f1(index_equation1) + f1_e;
            
        end
        
        
        %------------------------------------------------------------------
        % -----------------------------------------------------------------
        %   End: Loop over elements
        % -----------------------------------------------------------------
        %------------------------------------------------------------------
        
        
        %------------------------------------------------------------------
        %  Solve for the displacement field
        %------------------------------------------------------------------
        % Assemble the stiffness matrix
        K11 = sparse(rows_for_K, columns_for_K, values_for_K, numDOFs, numDOFs);
        
        
        % Apply a row preconditioner
%        precond = spdiags(1./max(K11, [], 2), 0, numDOFs, numDOFs);
%        K11 = precond * K11;
%        f1  = precond * f1;
        
%        clear precond;
        
        
        % Prescribe the known coefficients and solve for the unknown
        u1(BCU_array1(:, 1)) = BCU_array1(:, 2);
        u1(index_u1) = K11(index_u1, index_u1) \ (f1(index_u1) - K11(index_u1, index_f1) * u1(index_f1));
        
        clear K11 f1;
        
        
        fprintf('\n');
        fprintf('  Equation 1 (momentum equation) has been solved.\n');
        
        
        
        %------------------------------------------------------------------
        % -----------------------------------------------------------------
        %   2. Find the phase field (u2)
        % -----------------------------------------------------------------
        %------------------------------------------------------------------
        % Initialize the RHS vector and prescribe the known forces
        f2 = zeros(numDOFs, 1);
        f2(BCF_array2(:, 1)) = BCF_array2(:, 2);
        
        % Index that was last used to set the entry of K
        lastIndex_for_K = 0;
        
        
        
        %------------------------------------------------------------------
        % -----------------------------------------------------------------
        %   Begin: Loop over elements (e = e1)
        % -----------------------------------------------------------------
        %------------------------------------------------------------------
        for e = 1 : numElements1
            % Find the Bezier extraction matrix
            bezierExtractions1_e = bezierExtractions1(:, :, e);
            
            % Evaluate the map derivative dt/dxi (constant)
            dt_dxi = 1 / elementSizes1(e);
            
            
            %--------------------------------------------------------------
            %  Evaluate the basis functions in the parametric domain
            %  Matrix: (numNodesPerElement) x (numQuadraturePointsPerElement)
            %--------------------------------------------------------------
            % Find the positions of the nodes
            nodes_e = nodes(IEN_array(:, e), :)';
            
            % Evaluate the B-splines
            basis_der0 =             bezierExtractions1_e  * Bernstein1_der0;
            basis_der1 = (dt_dxi   * bezierExtractions1_e) * Bernstein1_der1;
            basis_der2 = (dt_dxi^2 * bezierExtractions1_e) * Bernstein1_der2;
            basis_der3 = (dt_dxi^3 * bezierExtractions1_e) * Bernstein1_der3;
            
            
            %--------------------------------------------------------------
            %  Evaluate the map derivatives (x = x1)
            %  Matrix: (numDOFsPerNode) x (numQuadraturePointsPerElement)
            %--------------------------------------------------------------
            dx_dxi = nodes_e * basis_der1;
            
            
            
            %--------------------------------------------------------------
            % -------------------------------------------------------------
            %   Begin: Loop over quadrature points (q_e)
            % -------------------------------------------------------------
            %--------------------------------------------------------------
            % Initialize the element stiffness matrix and the element
            % internal force vector
            K22_e = elementMatrix;
            f2_e  = elementVector;
            
            % Find the equation indices for the element
            index_equation1 = LM_array1(:, e);
            index_equation2 = LM_array2(:, e);
            
            % Find the coefficients of the displacement field
            u1_e = u1(index_equation1)';
            
            
            for q_e = 1 : numQuadraturePointsPerElement
                %----------------------------------------------------------
                %  Form the Jacobian matrix
                %  Matrix: (numDOFsPerNode) x (numDOFsPerNode)
                %----------------------------------------------------------
                JacobianMatrix = dx_dxi(:, q_e);
                
                % Evaluate the Jacobian
                Jacobian = JacobianMatrix / dt_dxi;
                
                if (Jacobian <= 0)
                    fprintf('\n');
                    fprintf('  Error: Jacobian is not positive for e = %d, q_e = %d. The problem will be left unsolved.\n\n', e, q_e);
                    
                    quit;
                end
                
                
                %----------------------------------------------------------
                %  Evaluate the basis functions in the physical domain
                %  Matrix: (numDOFsPerNode) x (numNodesPerElement)
                %----------------------------------------------------------
                JacobianMatrix_inv = 1 / JacobianMatrix;
                
                basis_physical_der0 =                        basis_der0(:, q_e);
                basis_physical_der1 = JacobianMatrix_inv   * basis_der1(:, q_e);
                basis_physical_der2 = JacobianMatrix_inv^2 * basis_der2(:, q_e);
                basis_physical_der3 = JacobianMatrix_inv^3 * basis_der3(:, q_e);
                
                
                %----------------------------------------------------------
                %  Evaluate the displacement field
                %----------------------------------------------------------
                u_der1 = u1_e * basis_physical_der1;
                
                
                %----------------------------------------------------------
                %  Form the element matrix K22
                %----------------------------------------------------------
                % Coefficients for the (regular) phase field theory.
                % The subscripts denote the derivatives of N_A and N_B.
                C00 = constant_stiffness * u_der1^2 + constant_G_c;
                C11 =                                 constant_G_c * (4/3    * constant_ell_0_sq  );
                C22 =                                 constant_G_c * (16/27  * constant_ell_0_sq^2);
                C33 =                                 constant_G_c * (64/729 * constant_ell_0_sq^3);
                
                K22_e = K22_e + (w(q_e) * Jacobian * C00) * (basis_physical_der0 * basis_physical_der0') ...
                              + (w(q_e) * Jacobian * C11) * (basis_physical_der1 * basis_physical_der1') ...
                              + (w(q_e) * Jacobian * C22) * (basis_physical_der2 * basis_physical_der2') ...
                              + (w(q_e) * Jacobian * C33) * (basis_physical_der3 * basis_physical_der3');
                
                
                %----------------------------------------------------------
                %  Form the element RHS vector f2
                %----------------------------------------------------------
                % Coefficients for the (regular) phase field theory.
                % The subscript denotes the derivative of N_A.
                C0 = constant_G_c;
                
                f2_e = f2_e + (w(q_e) * Jacobian * C0) * basis_physical_der0;
            end
            
            
            %--------------------------------------------------------------
            % -------------------------------------------------------------
            %   End: Loop over quadrature points
            % -------------------------------------------------------------
            %--------------------------------------------------------------
            
            
            %--------------------------------------------------------------
            %  Global assembly
            %--------------------------------------------------------------
            % Add the element matrix K22
            index = lastIndex_for_K + indices_for_elementMatrix;
            
            rows_for_K(index)    = kron(vector_of_ones, index_equation2);
            columns_for_K(index) = kron(index_equation2, vector_of_ones);
            values_for_K(index)  = reshape(K22_e, constant_p1p1_sq, 1);
            
            lastIndex_for_K = lastIndex_for_K + constant_p1p1_sq;
            
            
            % Add the element RHS vector f2
            f2(index_equation2) = f2(index_equation2) + f2_e;
            
        end
        
        
        %------------------------------------------------------------------
        % -----------------------------------------------------------------
        %   End: Loop over elements
        % -----------------------------------------------------------------
        %------------------------------------------------------------------
        
        
        %------------------------------------------------------------------
        %  Solve for the phase field
        %------------------------------------------------------------------
        % Assemble the stiffness matrix
        K22 = sparse(rows_for_K, columns_for_K, values_for_K, numDOFs, numDOFs);
        
        
        % Apply a row preconditioner
%        precond = spdiags(1./max(K22, [], 2), 0, numDOFs, numDOFs);
%        K22 = precond * K22;
%        f2  = precond * f2;
        
%        clear precond;
        
        
        % Prescribe the known coefficients and solve for the unknown
        u2(BCU_array2(:, 1)) = BCU_array2(:, 2);
        u2(index_u2) = K22(index_u2, index_u2) \ (f2(index_u2) - K22(index_u2, index_f2) * u2(index_f2));
        
        clear K22 f2;
        
        
        fprintf('\n');
        fprintf('  Equation 2 (phase field equation) has been solved.\n\n');
        
        
        
        %------------------------------------------------------------------
        % -----------------------------------------------------------------
        %   3. Save the results
        % -----------------------------------------------------------------
        %------------------------------------------------------------------
        save(sprintf('%sfile_results_alternation%d', path_to_results_directory, alternation), 'u1', 'u2', '-v6');
    end
    
    clear u1 u2;
    clear rows_for_K columns_for_K values_for_K;
    
    
    %----------------------------------------------------------------------
    % ---------------------------------------------------------------------
    %   End: Loop over alterations
    % ---------------------------------------------------------------------
    %----------------------------------------------------------------------
    
    
    fprintf('\n');
    fprintf('  End of the problem.\n\n');
    fprintf('----------------------------------------------------------------\n');
    fprintf('----------------------------------------------------------------\n\n');
end
