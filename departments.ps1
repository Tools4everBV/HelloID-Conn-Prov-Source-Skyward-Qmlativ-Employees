#region Initialize default properties
$config = ConvertFrom-Json $configuration;
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12; 
#endregion Initialize default properties


function get_oauth_access_token {
    [cmdletbinding()]
    Param (
        [string]$BaseURI,
        [string]$ClientKey,
        [string]$ClientSecret
    )
    Process {
        $pair = [System.Web.HTTPUtility]::UrlEncode($ClientKey) + ":" + [System.Web.HTTPUtility]::UrlEncode($ClientSecret)
        $bytes = [System.Text.Encoding]::ASCII.GetBytes($pair);
        $bear_token = [System.Convert]::ToBase64String($bytes);
        $auth_headers = @{ Authorization = "Basic " + $bear_token };
          
        $uri = "$($BaseURI)/oauth/token?grant_type=client_credentials";
        $result = Invoke-RestMethod -Method GET -Headers $auth_headers -Uri $uri -UseBasicParsing;
        @($result);
    }
}

function get_system_metadata {
    #######ACCESS TOKEN##########
        Write-Verbose -Verbose "Retrieving Access Token";
           
        $AccessToken = (get_oauth_access_token `
                -BaseURI $config.BaseURI `
                -ClientKey $config.ClientKey `
                -ClientSecret $config.ClientSecret).access_token
           
        $headers = @{ Authorization = "Bearer $($AccessToken)" };
    
    #####GET DATA########
        Write-Verbose -Verbose "Getting System Metadata )";
        $result = [System.Collections.ArrayList]@();
        $uri = "$($config.BaseURI)/Generic/GetSystemMetadata";

        $result = $null;
        $result = Invoke-RestMethod -Method GET -Uri $uri -Headers $headers -UseBasicParsing;

        @($result.System);          
}

function get_data_objects {
    [cmdletbinding()]
    Param (
        [string]$ModuleName,
        [string]$ObjectName,
        [array]$SearchFields,
        [boolean]$ReturnHashTable,
        [string]$HashTableKey
    )
    Process {
           
        #######ACCESS TOKEN##########
        Write-Verbose -Verbose "Retrieving Access Token";
           
        $AccessToken = (get_oauth_access_token `
                -BaseURI $config.BaseURI `
                -ClientKey $config.ClientKey `
                -ClientSecret $config.ClientSecret).access_token
           
        $headers = @{ Authorization = "Bearer $($AccessToken)" };
   
        #####GET DATA########
        Write-Verbose -Verbose "Getting Data Objects for ( $($ModuleName) : $($ObjectName) )";
        Write-Verbose -Verbose "Search Fields: $($SearchFields)";
        $result = [System.Collections.ArrayList]@();
        $object_uri = "$($config.BaseURI)/Generic/$($config.EntityId)/$($ModuleName)/$($ObjectName)";
        $page_uri = "$($object_uri)/1/$($config.PageSize)";
        $request_params = @{};
   
        #--SCHOOL YEAR--#
        if ($config.SchoolYearId.Length -gt 0) {
            $request_params['SchoolYearID'] = "$($config.SchoolYearId)";
            Write-Verbose -Verbose "Enforcing SchoolYearID $($config.SchoolYearId)";
        }
   
        #--FISCAL YEAR--#
        if ($config.FiscalYearId.Length -gt 0) {
            $request_params['FiscalYearID'] = "$($config.FiscalYearId)";
            Write-Verbose -Verbose "Enforcing FiscalYearID $($config.FiscalYearId)";
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
            Write-Verbose -Verbose "1 Record returned"
            $result.Add($page_result);
        }
        else {
            Write-Verbose -Verbose "$($page_result.Objects.Count) Record(s) returned"
            $result.AddRange($page_result.Objects);
   
            while ($next_page_uri -ne $config.BaseURI -and $next_page_uri -ne $previous_page_uri) {
                $next_page_uri = "$($next_page_uri)";
                Write-Verbose -Verbose "$next_page_uri";
                $page_result = $null;
                $page_result = Invoke-RestMethod -Method GET -Uri $next_page_uri -Body $request_params -Headers $headers -UseBasicParsing
               
                $previous_page_uri = $next_page_uri;
                $next_page_uri = "$($config.BaseURI)$($page_result.Paging.Next)";
               
                Write-Verbose -Verbose  "$($page_result.Objects.Count) Record(s) returned"
                $result.AddRange($page_result.Objects);
            }
        }
           
        Remove-Variable -Name "SearchFields" -ErrorAction SilentlyContinue
           
        Write-Verbose -Verbose "Total of $($result.Count) Record(s) returned"                
        
        # Check if HashTable
        if($ReturnHashTable)
        {
            $htResult = @{};

            foreach($key in $result | Select -ExpandProperty $HashTableKey)
            {
                $htResult[$key.ToString()] = [System.Collections.ArrayList]@();
            }
            
            foreach($row in $result)
            {
                try { [void]$htResult[($row | Select -ExpandProperty $HashTableKey).ToString()].Add($row) } catch { Write-Warning "( $($ModuleName) : $($ObjectName) ) - Skipped Null Key Value" }
            }
            return $htResult
        }
        
        return $result;
        
        
    }
}
#endregion Support Functions

 
try{
    $items = get_data_objects `
        -ModuleName "District" `
        -ObjectName "Building" `
        -SearchFields ( ("BuildingID,AddressID,Code,CodeDescription,Description,DistrictID") -split ",") `
		-ReturnHashTable $false

 
foreach($item in $items)
{
    $row = @{
              ExternalId = $item.BuildingID
              DisplayName = $item.CodeDescription
    }
 
    $row | ConvertTo-Json -Depth 10
}
 
}catch
{
    Write-Error $_
	throw $_
}