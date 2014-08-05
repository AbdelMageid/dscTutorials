function param_vec = Write_Parameter_File(P_Input,BaseFileName,ParamName)

% param_vec = Write_Parameter_File(P_Input,BaseFileName,ParamName)
%
%FUNCTION: 
%
%   This function is used to take a parameter struct and do two things with
%   it. First is to collapse it to a single vector of numbers and second is
%   to write a C++ header file(s) that contain the information about how to
%   extract information about how to unpack those vectors into variables 
%   that mirror the original field names of the struct.
%
%
%INPUT:
%
%   P_Input = a struct of parameters. This can contain fields with numeric
%       matricies or structs of the same.
%   
%   BaseFileName = [LEAVE BLANK - USED RECURSIVELY] tells the program what
%       the base name for the file should be. 
%
%   ParamName = [LEAVE BLANK - USED RECURSIVELY] tells the program what the 
%       input parameter (for the C++ function) should be called.
%
%
%OUTPUT:
%
%   param_vec = is a collapsed list of every numeric value stored in
%       P_Input. Read USAGE to see how substructs are handled
%
%
%  GetParameters.h = a header file that creates a variable with the name
%       and dimensions that match the input struct.
%
%  GetParameters_FieldName.h = if P_Input has a fieldname FieldName, then
%       its contents will go here. This happens recursively. This way, if
%       the structure of FieldNames matches the structure of your C++ code,
%       then this function will write a tree of header files that properly
%       get the data from a single input vector (passed to the MEX file) to
%       named variables in the workspace of each subfunction in C++.
%
%USAGE:
%
%   Create a parameter struct with numeric data and (possibly) substructs
%   in it. It is assumed that you will pass 'param_vec' through a MEX
%   interface, and that it will eventually get to the function of interest
%   with the type and name:
%   
%       void  RHS(... , mxArray* params, ...)
%
%   Inside of this function, write the line:
%
%       #include "GetParameters.h"
%
%   This will define every field in the parameter struct and assign the 
%   appropriate values to it. Then you can use these parameters as normal.
%   For example, if you defined (in matlab) P.a = 4, in the C++ function
%   you could then write the line TEST = a; which would store a value of 4
%   in TEST.
%
%   Note  --  Substructs are treated as vectors, and none of their field
%   names are passed at this level. This is because a seperate header file
%   is written to store this information. The simplest way to deal with
%   this is as follows. Assume that in Matlab you have defined
%   P.Controls.K. To get access to K (by name) you need to enter the
%   following lines of code:
%   
%       #include "GetParameters.h"
%       #include "GetParameters_Controls.h"
%
%       TEST2 = K;   // Stores the matrix K in TEST2  -  assume that TEST2 has been properly initialized
%
%   There is another way to use this, which is a bit more useful. Let's
%   suppose that your function of interest is RHS, which calls a function
%   called Controls inside of it. Example:
%
%       [IN MATLAB]:
%       P.Controls.K = rand(4);
%       P.asdf = 2.34;
%       param_vec = Write_Parameter_File(P);  %Write C++ header files...
%
%       [MEX FUNCTION]
%           --> Read in param_vec from Matlab
%           --> Call RHS with     mxArray* params
%
%       [In C++]
%
%       void Controls(... , double* P_Controls, ...)
%       {  //  This is a sub function
%          #include "GetParameters_Controls.h"
%           // Now all of the fields of P.Controls are available, in this
%           // case that means that K is available for use as a 2D array
%       }
%
%       void  RHS(... , mxArray* params, ...)
%       {
%           #include "GetParameters.h"
%           // Now asdf is available to use (a scalar), and P_Controls is
%           // available to use as an array
%           Controls(... , P_Controls,...);
%       }
%  
%   See also  FLATTEN_PARAM_STRUCT  PARAMSTRUCTDATA  FLATTEN_CPP_PARAMS



%% Check if the function is being called recursively
if nargin == 1
   %Then this function is being called by a different program
   BaseFileName = 'GetParameters';  %This is the name of the file to be written, without the '.h' extension
   ParamName = 'paramsarray';  %Default name for the top level parameters passed through MEX
   BaseLevel = true;      %This tells the code that it is being called by a different program
else 
   BaseLevel = false;   %This means that the function is being called recursivly
end

FID = fopen([BaseFileName '.h'],'w'); %Open the file to write the parameters in




%% This is the block of text for the first few lines of code

fprintf(FID, '////////////////////////////////////////////////////////// \n');
fprintf(FID, '// DO NOT EDIT THIS FILE								// \n');
fprintf(FID, '//														// \n');
fprintf(FID, '// It has been automatically generated by:				// \n');
fprintf(FID, '//     Write_Parameters_File.m							// \n');
fprintf(FID, '//														// \n');
fprintf(FID, '// The data and names for the class variables come from // \n');
fprintf(FID, '// the file Set_Parameters.m and comments can be found  // \n');
fprintf(FID, '// there.												// \n');
fprintf(FID, '//														// \n');
fprintf(FID, '// Written by Matthew Kelly								// \n');
fprintf(FID, '// matthew.kelly2@gmail.com								// \n');
fprintf(FID, '////////////////////////////////////////////////////////// \n');
fprintf(FID, '                                                         \n');




%% Format the input parameter struct: 
P = [];  %This is where the parameters go after error checking and formatting

%Check the data type for each field
Names = sort(fieldnames(P_Input));   %Get the names of each field, and put them in order for repeatability
DataType = cell(length(Names),1);

%Loop through each field
for i=1:length(Names)   
    
    
    %Check to make sure that the field names are not reserved C++ words
    if isreserved(Names{i})
        %This triggers an error, forcing the user to change the field name
        fclose(FID);   %Make sure to close the file first, to prevent it from being open after execution completes
        error(['Field name: ' Names{i} ' is a reserved word in C++. Change it.']);   %Print error message and terminate program
    end
   
    
   if isnumeric(P_Input.(Names{i}))   %Then the field is purely numeric. Woo!
       [N,M] = size(P_Input.(Names{i})); %Check the size
       if N*M == 1;
           %Then it is a single number
           DataType{i} = 'Scalar';
       else
           %Then it is a matrix
           DataType{i} = 'Matrix';
       end
       P.(Names{i}) = P_Input.(Names{i});   %This is a numeric valued field - OK to pass to C++
   
   
   elseif isstruct(P_Input.(Names{i}))   %Now things get complicated
        
       %Then it is a struct - recursively call this function
            NewFileName = [BaseFileName '_' Names{i}];
            if BaseLevel
                NewParamName = ['P_' Names{i}];
            else
                NewParamName = [ParamName '_' Names{i}];
            end
        %Then write a new field that represents that flattened struct --
        Flattened_Struct = Write_Parameter_File(P_Input.(Names{i}),NewFileName,NewParamName );   %RECURSION
          
        %Then tell the program that it is a matrix
            DataType{i} = 'Matrix';
            if BaseLevel
                New_Name = ['P_' Names{i}];  %Then it gets a special name
            else
                New_Name = [ParamName '_' Names{i}];   %Already named, just append the new subfield to the end
            end
            Names{i} = New_Name;  %Rename the field for consistency
        %Now store the result as a vector
        P.(New_Name) = Flattened_Struct;   %Now it is stored as a matrix
    
   
   else
       %Not a numeric value or a struct - not supported - Display a warning
       DataType{i} = 'Unsupported';   %Error code
       disp(' ')
       disp('~~~~ WARNING -- Write_Parameter_File.m')
       disp(['~~~~    P.' Names{i} ' is not supported. This may cause an error.'])
       
       %Write a warning in the C++ file as well:
       boundaryText = '//#######################################################################\n';
       messageText = ['// Warning: Data type for field: ' Names{i} '  is an unsupported data type and was ignored.       \n'];
       fprintf(FID, '                                                         \n');
       fprintf(FID, [boundaryText messageText boundaryText]);  
       fprintf(FID, '                                                         \n');
   
   
   end
end




%% Take the formated struct and collapse it to a vector
%IMPORTANT TWO LINES!!!

%This stores the information about each field so that it can be used later
%to assign names to each element of the parameter struct
Data = ParamStructData(P);  %used in later sections as well

%This function takes the information in Data and uses it to collapse the
%struct into a single vector
param_vec = Flatten_Cpp_Params(P,Data);



%% Write the declarations:
fprintf(FID, '\n');
fprintf(FID, '\n');
fprintf(FID, '////~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~////\n');
fprintf(FID, '////  Declare each parameter variable                 ////\n');
fprintf(FID, '\n');
fprintf(FID, '//Scalar Variables:\n');

%First, print out all of the scalar parameter declarations
for i=1:length(Names)  
    if strcmp(DataType{i},'Scalar')
        fprintf(FID,['    static double ' Names{i} ';\n']); 
    end
end
fprintf(FID, '\n');

%Now, print out all of the array variables
fprintf(FID, '//Array Variables:\n');
for i=1:length(Names)
    if strcmp(DataType{i},'Matrix')
        [N,M] = size(P.(Names{i}));
        fprintf(FID,['    static double ' Names{i} ]);
        %Now add the matrix size identifiers:
        %If N==1 OR M==1 then only a single dimension is printed
        %Otherwise, both are printed and a 2D matrix is defined
        if (N==1) && (M==1)
            %Then it's a scalar pretending to be a matrix - this is useful
            %for structs to be properly handled in C++
            fprintf(FID,'[1]');
        else
            if N>1
                fprintf(FID,'['); 
                fprintf(FID,'%u',N);
                fprintf(FID,']');
            end
            if M>1
                fprintf(FID,'['); 
                fprintf(FID,'%u',M);
                fprintf(FID,']');
            end
        end
        fprintf(FID, ';\n');
    end
end
fprintf(FID, '\n');




%% A block of text between the two useful bits of code:

fprintf(FID, '////                                                  ////\n');
fprintf(FID, '////~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~////\n');
fprintf(FID, '\n');
fprintf(FID, '\n');

%This line is ONLY called for the top level parameter function.
%Because this one needs to translate MEX stuff. 
%All of the sub functions only need to decode C++ stuff, and can skip this
%step.
if strcmp(ParamName, 'paramsarray');
    %Then top level function - convert out of MEX array format
    fprintf(FID, '\n');
    fprintf(FID, '//Get the pointer to the parameters:\n');
    fprintf(FID,'double *paramsarray = mxGetPr(params);\n');  %This step is only used for the MEX conversion...
    fprintf(FID, '\n');
end

fprintf(FID, '\n');
fprintf(FID, '\n');
fprintf(FID, '////~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~////\n');
fprintf(FID, '////  Assign values to each new parameter variable    ////\n');
fprintf(FID, '\n');
fprintf(FID,'//Scalar parameters initialized here\n');




%% Initialize the scalar parameters
%These next two sections are the most important part of the code. They
%assign names to each element in the input parameter vector.

%Loop through each field
for field=1:length(Data.Names)
    if strcmp(DataType{field},'Scalar')
        fprintf(FID,['    ' Data.Names{field} ' = ' ParamName '[']);     %Assign a name to an element
        fprintf(FID,'%u',Data.Idx(field,1)-1);  %C++ is zero indexed...
        fprintf(FID,'];\n');
    end
end
 fprintf(FID, '\n'); 

 
 
 
 
%% Initialize the matrix parameters here:
%This one works just like for scalar parameters, but it works in groups in
%order to support matricies.

fprintf(FID,'//Array initialization goes here\n');
for field=1:length(Data.Names)
    
    if strcmp(DataType{field},'Matrix')
        N = Data.Sizes(field,1);
        M = Data.Sizes(field,2);
        
        %Formatting for a ROW VECTOR
        if N==1;  %Row Vector
            StartIdx = Data.Idx(field,1)-1;   %C++ is zero indexed  --  This is the index of the first element of the array in the param_vec
            for j=0:(M-1) %Loop through each element of the matrix
                fprintf(FID,['    ' Data.Names{field} '[']);
                fprintf(FID,'%u',j);
                fprintf(FID,['] = ' ParamName '[']);
                fprintf(FID,'%u',StartIdx + j);
                fprintf(FID,'];\n');
            end
            
            
        %Formatting for a COLUMN VECTOR    
        elseif M==1;  %Column Vector
            StartIdx = Data.Idx(field,1)-1;   %C++ is zero indexed  --  This is the index of the first element of the array in the param_vec
            for i=0:(N-1)  %Loop through each element of the matrix
                fprintf(FID,['    ' Data.Names{field} '[']);
                fprintf(FID,'%u',i);
                fprintf(FID,['] = ' ParamName '[']);
                fprintf(FID,'%u',StartIdx + i);
                fprintf(FID,'];\n');
            end
            
            
        %Formatting for a MATRIX  
        else    %2D array
            StartIdx = Data.Idx(field,1)-1;   %C++ is zero indexed  --  This is the index of the first element of the array in the param_vec
            counter = 0;
            for i=0:(N-1)   %Loop through each row
                for j=0:(M-1)   %and each column
                    fprintf(FID,['    ' Data.Names{field} '[']);
                    fprintf(FID,'%u',i);
                    fprintf(FID,'][');
                    fprintf(FID,'%u',j);
                    fprintf(FID,['] = ' ParamName '[']);
                    fprintf(FID,'%u',StartIdx + counter);
                    fprintf(FID,'];\n');
                    counter = counter + 1;
                end
            end
        end
        
        
        fprintf(FID, '\n'); 
    end
end           
        




%% This is the block of text for the end of the file
fprintf(FID, '////                                                  ////\n');
fprintf(FID, '////~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~////\n');
fprintf(FID, '\n');


fclose(FID);

end
