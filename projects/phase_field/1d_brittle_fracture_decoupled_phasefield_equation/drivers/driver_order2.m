function driver_order2()
    % Set path to the IGA routines directory
    directory_IGARoutines = '../../../../routines_for_iga/';
    
    % Set path to the model directory
    directory_model = '../../../../models/phase_field/1d_brittle_fracture_decoupled_phasefield_equation/';
    
    % Add paths
    addpath(directory_IGARoutines);
    addpath(directory_model);
    
    
    % Parameters for simulation
    numRefinements = [0; 1; 2; 3; 4];
    
    
    for i = 1 : size(numRefinements, 1)
        % Set path to the assembly directory
        path_to_assembly_directory = sprintf('../assembly_files/order2/numRefinements%d/', numRefinements(i));
        
        % Set path to the results directory
        path_to_results_directory = sprintf('../results/order2/numRefinements%d/', numRefinements(i));
        
        % Create the results directory if it does not exist
        if ~exist(path_to_results_directory, 'dir')
            mkdir(path_to_results_directory);
        end
        
        
        % Run the constitutive model
        model_1d_order2(path_to_assembly_directory, path_to_results_directory);
    end
    
    
    % Remove paths
    rmpath(directory_IGARoutines);
    rmpath(directory_model);
end
