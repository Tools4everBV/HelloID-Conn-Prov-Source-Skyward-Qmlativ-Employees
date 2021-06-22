$config = ConvertFrom-Json $configuration;
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12; 
function get_oauth_access_token {
    [cmdletbinding()]
    Param (
        [string]$BaseURI,
        [string]$ClientKey,
        [string]$ClientSecret
    )
    Process {
        $pair = $ClientKey + ":" + $ClientSecret;
        $bytes = [System.Text.Encoding]::ASCII.GetBytes($pair);
        $bear_token = [System.Convert]::ToBase64String($bytes);
        $auth_headers = @{ Authorization = "Basic " + $bear_token };
          
        $uri = "$($BaseURI)/oauth/token?grant_type=client_credentials";
        $result = Invoke-RestMethod -Method GET -Headers $auth_headers -Uri $uri -UseBasicParsing;
        @($result);
    }
}
function get_data_objects {
    [cmdletbinding()]
    Param (
        [string]$ModuleName,
        [string]$ObjectName,
        [array]$SearchFields
    )
    Process {
           
        #######ACCESS TOKEN##########
        Write-Information "Retrieving Access Token";
           
        $AccessToken = (get_oauth_access_token `
                -BaseURI $config.BaseURI `
                -ClientKey $config.ClientKey `
                -ClientSecret $config.ClientSecret).access_token
           
        $headers = @{ Authorization = "Bearer $($AccessToken)" };
   
        #####GET DATA########
        Write-Information "Getting Data Objects for ( $($ModuleName) : $($ObjectName) )";
        Write-Information "Search Fields: $($SearchFields)";
        $result = [System.Collections.ArrayList]@();
        $object_uri = "$($config.BaseURI)/Generic/$($config.EntityId)/$($ModuleName)/$($ObjectName)";
        $page_uri = "$($object_uri)/1/$($config.PageSize)";
        $request_params = @{};
   
        #--SCHOOL YEAR--#
        if ($config.SchoolYearId.Length -gt 0) {
            $request_params['SchoolYearID'] = "$($config.SchoolYearId)";
            Write-Information "Enforcing SchoolYearID $($config.SchoolYearId)";
        }
   
        #--FISCAL YEAR--#
        if ($config.FiscalYearId.Length -gt 0) {
            $request_params['FiscalYearID'] = "$($config.FiscalYearId)";
            Write-Information "Enforcing FiscalYearID $($config.FiscalYearId)";
        }
   
        #--SEARCH FIELDS--#                
        if ($SearchFields.Length -gt 0) {
            $i = 0
            foreach ($field in $SearchFields) {
                $request_params["searchFields[$($i)]"] = "$($field)";
                $i++;
            }
        }
           
        $page_result = $null;
        $page_result = Invoke-RestMethod -Method GET -Uri $page_uri -body $request_params -Headers $headers -UseBasicParsing;
           
        $previous_page_uri = $page_uri;
        $next_page_uri = "$($config.BaseURI)$($page_result.Paging.Next)";
  
        if ($page_result.Objects.Count -eq 0) {
            Write-Information "1 Record returned"
            $result.Add($page_result);
        }
        else {
            Write-Information "$($page_result.Objects.Count) Record(s) returned"
            $result.AddRange($page_result.Objects);
   
            while ($next_page_uri -ne $config.BaseURI -and $next_page_uri -ne $previous_page_uri) {
                $next_page_uri = "$($next_page_uri)";
                Write-Information "$next_page_uri";
                $page_result = $null;
                $page_result = Invoke-RestMethod -Method GET -Uri $next_page_uri -Body $request_params -Headers $headers -UseBasicParsing
               
                $previous_page_uri = $next_page_uri;
                $next_page_uri = "$($config.BaseURI)$($page_result.Paging.Next)";
               
                Write-Information  "$($page_result.Objects.Count) Record(s) returned"
                $result.AddRange($page_result.Objects);
            }
        }
           
        Remove-Variable -Name "SearchFields" -ErrorAction SilentlyContinue
           
        Write-Information "Total of $($result.Count) Record(s) returned"                
        @($result);
    }
}
  
try {

    $DemographicsName = get_data_objects `
        -ModuleName "Demographics" `
        -ObjectName "Name" `
        -SearchFields ( ("NameID,Age,BirthDate,BirthMonthDay,BirthYear,Ethnicity,EthnicityAndRace,FirstName,Gender,Initials,IsCurrentStudent,IsEmployeeName,IsEmployeeNameForDistrict,IsGuardianName,LastName,MiddleName,NameKey,NameSuffixID,NameSuffixIDLegal,NameTitleID,NameTitleIDLegal,OccupationID,Race,SkywardID,TitledName") -split ",")
        
    $DemographicsNameAlias = get_data_objects `
        -ModuleName "Demographics" `
        -ObjectName "NameAlias" `
        -SearchFields ( ("NameAliasID,FirstName,FullNameFL,IsLegalName,LastName,MiddleName,NameID,NameSuffixID,NameTitleID,Rank") -split ",")

    $DemographicsNameEmail = get_data_objects `
        -ModuleName "Demographics" `
        -ObjectName "NameEmail" `
        -SearchFields ( ("NameEmailID,EmailAddress,EmailTypeID,NameID,Rank") -split ",")

    $DemographicsNamePhone = get_data_objects `
        -ModuleName "Demographics" `
        -ObjectName "NamePhone" `
        -SearchFields ( ("NamePhoneID,Extension,FormattedPhoneNumber,FullPhoneNumber,NameID,PhoneNumber,PhoneTypeID,Rank") -split ",")

    $DemographicsNamePhone = get_data_objects `
        -ModuleName "Demographics" `
        -ObjectName "Zip" `
        -SearchFields ( ("ZipID,City,CityState,CityStateCode,CityStateZip,CityZipCode,CountryCode,StateID,ZipCode") -split ",")

    $DemographicsNamePhone = get_data_objects `
        -ModuleName "Demographics" `
        -ObjectName "Street" `
        -SearchFields ( ("StreetID,DirectionalID,FormattedStreet,Name,StreetNameWithDirectionCode,ZipID") -split ",")

    $DemographicsNamePhone = get_data_objects `
        -ModuleName "Demographics" `
        -ObjectName "PhoneType" `
        -SearchFields ( ("PhoneTypeID,Code,CodeDescription,Description") -split ",")

    $EmployeeEmployee = get_data_objects `
        -ModuleName "Employee" `
        -ObjectName "Employee" `
        -SearchFields @( ("EmployeeID,EmployeeNumber,EmployeeThirdPartyImportID,FullNameFL,FullNameFML,NameID") -split ",") 

    $EmployeeEmployeeDistrict = get_data_objects `
        -ModuleName "Employee" `
        -ObjectName "EmployeeDistrict" `
        -SearchFields @( ("EmployeeDistrictID,CheckLocationID,DistrictID,EmployeeID,HireDateOriginal,IsActive,StartDateOriginal,IsActive") -split ",") 


    $EmployeeEmployment = get_data_objects `
        -ModuleName "Employee" `
        -ObjectName "Employment" `
        -SearchFields @( ("EmploymentID,Comment,DistrictID,EmployeeID,EmploymentStatusID,EmploymentYears,EndDate,HireDate,IsTerminated,StartDate,TerminationID") -split ",") 

    $EmployeeEmploymentStatus = get_data_objects `
        -ModuleName "Employee" `
        -ObjectName "EmploymentStatus" `
        -SearchFields @( ("EmploymentStatusID,Code,CodeDescription,Description,DistrictID") -split ",") 

    $Position = get_data_objects `
        -ModuleName "Position" `
        -ObjectName "Position" `
        -SearchFields ( ("PositionID,BudgetedFTE,CalendarID,CurrentAssignmentFTE,DistrictID,EndDate,FiscalYearID,JobTypeID,PositionCodeIdentifier,PositionGroupID,PositionNumberID,PositionTypeID,StartDate") -split ",")
   
    $PositionAssignment = get_data_objects `
        -ModuleName "Position" `
        -ObjectName "Assignment" `
        -SearchFields ( ("AssignmentID,EmployeeID,EmployeePlacementID,EndDate,EntitlementID,PercentEmployed,PositionID,PositionTypeEmployeeIdentifier,StartDate") -split ",")
   
    $PositionAssignmentDetail = get_data_objects `
        -ModuleName "Position" `
        -ObjectName "AssignmentDetail" `
        -SearchFields ( ("AssignmentDetailID,AssignmentID,Comment,EmployeePlacementDetailID,EmployeePlacementIDBase,EndDate,EnteredFTE,IsPrimary,StartDate") -split ",")

    $PositionPositionType = get_data_objects `
        -ModuleName "Position" `
        -ObjectName "PositionType" `
        -SearchFields ( ("PositionTypeID,BudgetedFTE,Code,CodeDescription,Description,DistrictID,EntitlementID,FiscalYearID,PlanPositionDistributionsForPlanGroupFTE") -split ",")
   

    $SecurityUser = get_data_objects `
        -ModuleName "Security" `
        -ObjectName "User" `
        -SearchFields ( ("UserID,EntityIDCurrent,FullNameFL,FullNameFML,FullNameLFM,IsActive,IsDeleted,NameID,Username") -split ",")
   
   $PositionAssignmentType = get_data_objects `
        -ModuleName "Position" `
        -ObjectName "AssignmentType" `
        -SearchFields ( ("AssignmentTypeID,Code,CodeDescription,Description,DistrictID,FiscalYearID") -split ",")

   $PositionPositionDistribution = get_data_objects `
        -ModuleName "Position" `
        -ObjectName "PositionDistribution" `
        -SearchFields ( ("PositionDistributionID,AssignmentTypeID,BuildingID,DepartmentID,PositionID") -split ",")

   $PositionPosition = get_data_objects `
        -ModuleName "Position" `
        -ObjectName "Position" `
        -SearchFields ( ("PositionID,EndDate,JobTypeID,PositionGroupID,PositionTypeID,StartDate") -split ",")

    <#
        Additional Data but not used in standard mapping
      
    $DemographicsNameAddress = get_data_objects `
        -ModuleName "Demographics" `
        -ObjectName "NameAddress" `
        -SearchFields ( ("NameAddressID,AddressID,IsMailing,NameID") -split ",")
        
    $District = get_data_objects `
        -ModuleName "District" `
        -ObjectName "District" `
        -SearchFields ( ("DistrictID,BuildingID,DistrictCodeBySchoolYear,DistrictGroupID,FaxNumber,FormattedPhoneNumber,Name,PhoneNumber") -split ",")
   
    $DistrictBuilding = get_data_objects `
        -ModuleName "District" `
        -ObjectName "Building" `
        -SearchFields ( ("BuildingID,AddressID,Code,CodeDescription,Description,DistrictID") -split ",")

    $DistrictEntity = get_data_objects `
        -ModuleName "District" `
        -ObjectName "Entity" `
        -SearchFields ( ("EntityID,Code,CodeName,DistrictID,Name,SchoolYearIDCurrent") -split ",")
 
    $EmployeeCalendar = get_data_objects `
        -ModuleName "Employee" `
        -ObjectName "Calendar" `
        -SearchFields @( ("CalendarID,Code,CodeDescription,Description,DistrictID,EndDate,FiscalYearID,StartDate") -split ",") 

    $EmployeeCheckLocation = get_data_objects `
        -ModuleName "Employee" `
        -ObjectName "CheckLocation" `
        -SearchFields @( ("CheckLocationID,Code,CodeDescription,Description,DistrictID") -split ",") 
   
    
 
    $EmployeeTermination = get_data_objects `
        -ModuleName "Employee" `
        -ObjectName "Termination" `
        -SearchFields @( ("TerminationID,Code,CodeDescription,Description,DistrictID") -split ",") 

    $SecurityGroup = get_data_objects `
        -ModuleName "Security" `
        -ObjectName "Group" `
        -SearchFields ( ("GroupID,Description,IsActive,Name,NameDescription") -split ",")
   
    $SecurityGroupMembership = get_data_objects `
        -ModuleName "Security" `
        -ObjectName "GroupMembership" `
        -SearchFields ( ("GroupMembershipID,EntityID,ExternalUniqueIdentifier,GroupIDParent") -split ",")
   
    $SecurityGroupRole = get_data_objects `
        -ModuleName "Security" `
        -ObjectName "GroupRole" `
        -SearchFields ( ("GroupRoleID,GroupID,RoleID") -split ",")
   
    $SecurityRole = get_data_objects `
        -ModuleName "Security" `
        -ObjectName "Role" `
        -SearchFields ( ("RoleID,Description,IsActive,Name") -split ",")
   
   
    
   
    $PositionDepartment = get_data_objects `
        -ModuleName "Position" `
        -ObjectName "Department" `
        -SearchFields ( ("DepartmentID,Code,CodeDescription,Description,DistrictID,FiscalYearID") -split ",")
   
    $PositionFTEGroup = get_data_objects `
        -ModuleName "Position" `
        -ObjectName "FTEGroup" `
        -SearchFields ( ("FTEGroupID,Code,CodeDescription,Description,DistrictID,FiscalYearID,TotalPositionFTE") -split ",")
   
    $PositionJobType = get_data_objects `
        -ModuleName "Position" `
        -ObjectName "JobType" `
        -SearchFields ( ("JobTypeID,Code,CodeDescription,Description,DistrictID,FiscalYearID") -split ",")
   
    $PositionOrganizationChart = get_data_objects `
        -ModuleName "Position" `
        -ObjectName "OrganizationChart" `
        -SearchFields ( ("OrganizationChartID,Code,CodeDescription,Description,DistrictID,FiscalYearID") -split ",")
   
    $PositionOrganizationChartRelationship = get_data_objects `
        -ModuleName "Position" `
        -ObjectName "OrganizationChartRelationship" `
        -SearchFields ( ("OrganizationChartRelationshipID,OrganizationChartID,PositionID,PositionIDSupervisor,RelationshipIdentifier") -split ",")
   
    $PositionOrganizationChartRelationshipBridge = get_data_objects `
        -ModuleName "Position" `
        -ObjectName "OrganizationChartRelationshipBridge" `
        -SearchFields ( ("OrganizationChartRelationshipBridgeID,LevelsBelowSupervisor,OrganizationChartID,PositionIDEmployee,PositionIDSupervisor") -split ",")
   
    $PositionPositionDistribution = get_data_objects `
        -ModuleName "Position" `
        -ObjectName "PositionDistribution" `
        -SearchFields ( ("PositionDistributionID,AssignmentTypeID,BudgetedFTE,BuildingID,DepartmentID,FTEGroupID,PositionID") -split ",")
   
    $PositionPositionGroup = get_data_objects `
        -ModuleName "Position" `
        -ObjectName "PositionGroup" `
        -SearchFields ( ("PositionGroupID,Code,CodeDescription,Description,DistrictID,FiscalYearID") -split ",")
   
    $PositionPositionNumber = get_data_objects `
        -ModuleName "Position" `
        -ObjectName "PositionNumber" `
        -SearchFields ( ("PositionNumberID,Code,DistrictID,FullPositionNumber") -split ",")
   
    #>




    foreach ($emp in $EmployeeEmployee) {
        $person = @{};
        $person["ExternalId"] = $emp.NameID;
        $person["DisplayName"] = "$($emp.FullNameFL)"
        $person["Role"] = "Employee"
    
        foreach ($prop in $emp.PSObject.properties) {
            $person[$prop.Name] = "$($prop.Value)";
        }
        
        #Demographics.Name
        foreach ($row in $DemographicsName) {
            if ($row.NameID -eq $emp.NameID) {
                $person["DemographicName"] = $row;
                break;
            }
        }

        #Demographics.NameAlias
        foreach ($row in $DemographicsNameAlias) {
            if ($row.NameID -eq $emp.NameID) {
                $person["DemographicNameAlias"] = $row;
                break;
            }
        }

        #Demographics.NameEmail
        foreach ($row in $DemographicsNameEmail) {
            if ($row.NameID -eq $emp.NameEmail) {
                $person["DemographicNameEmail"] = $row;
                break;
            }
        }

        #Demographics.NamePhone
        foreach ($row in $DemographicsNamePhone) {
            if ($row.NameID -eq $emp.NameID) {
                $person["DemographicNamePhone"] = $row;
                break;
            }
        }

        #Security.User
        foreach ($row in $SecurityUser) {
            if ($row.NameID -eq $emp.NameID) {
                $person["SecurityUser"] = $row;
                break;
            }
        }

    
    
        $person["Contracts"] = [System.Collections.ArrayList]@();
        
        #Employments
        foreach ($employment in $EmployeeEmployment) {
            if ($employment.EmployeeID -eq $emp.EmployeeID) {
                $contract = @{};
                $contract["ExternalID"] = "EMPLOYMENT.$($employment.EmploymentID)"
                
                foreach ($prop in $employment.PSObject.properties) {
                    $contract[$prop.Name] = "$($prop.Value)";
                }

                foreach($row in $EmployeeEmploymentStatus)
                {
                    if ($row.EmploymentStatusID -eq $employment.EmploymentStatusID) {
                        $contract["EmploymentStatus"] = $row;
                        break;
                    }
                }

                #Employee.EmployeeDistrict
                foreach ($row in $EmployeeEmployeeDistrict) {
                    if ($row.EmployeeID -eq $employment.EmployeeID) {
                        $person["IsActive"] = $row.IsActive
						$contract["EmployeeDistrict"] = $row;
                        break;
                    }
                }

                [void]$person.Contracts.Add($contract);
            }
        }

        #Positions
        foreach ($position in $PositionAssignment) {
            if ($position.EmployeeID -eq $emp.EmployeeID) {
                $contract = @{};
                $contract["ExternalID"] = "POSITION.$($position.AssignmentID)"
                
                foreach ($prop in $position.PSObject.properties) {
                    $contract[$prop.Name] = "$($prop.Value)";
                }

                foreach($row in $PositionPositionDistribution)
                {
                    if ($row.PositionID -eq $position.PositionID) {
                        $obj = @{};
                        $obj['DepartmentID'] = $row.DepartmentID;
                        $obj['BuildingID'] = $row.BuildingID;

                        foreach($subRow in $PositionAssignmentType)
                        {
                            if($subRow.AssignmentTypeID -eq $row.AssignmentTypeID)
                            {
                                foreach ($prop in $subRow.PSObject.properties) {
                                    $obj[$prop.Name] = "$($prop.Value)";
                                }
                            }
                        }


                        $contract["PositionDistribution"] = $obj;
                        
                        break;
                    }
                }
                
                foreach($row in $PositionAssignmentDetail)
                {
                    if ($row.AssignmentID -eq $position.AssignmentID) {
                        $obj = @{};
                        foreach ($prop in $row.PSObject.properties) {
                            $obj[$prop.Name] = "$($prop.Value)";
                        }

                        $contract["Detail"] = $obj;
                        break;
                    }
                }

                foreach($row in $PositionPosition)
                {
                    if ($row.PositionID -eq $position.PositionID) {
                        $obj = @{}
                        foreach ($prop in $position.PSObject.properties) {
                            $obj[$prop.Name] = "$($prop.Value)";
                        }
                        
                        $contract["Position"] = $obj;

                        foreach($rowType in $PositionPositionType)
                        {
                            if($rowType.PositionTypeID -eq $row.PositionTypeID)
                            {
                                $obj = @{}
                                foreach ($prop in $rowType.PSObject.properties) {
                                    $obj[$prop.Name] = "$($prop.Value)";
                                }
                        
                                $contract["PositionType"] = $obj;
                                break
                            }

                        }
                        break;
                    }
                }

                [void]$person.Contracts.Add($contract);
            }
        }

        if($person['IsActive'] -eq $true)
        {
            Write-Output ($person | ConvertTo-Json -Depth 20);
        }
    }

}
catch {
    Write-Error -Verbose $_;
    throw $_;   
}