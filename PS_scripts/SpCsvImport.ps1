function Set-LookupField {
    param (
        $web,
        $list,
        $item,
        [string]$fieldName,
        [Parameter(Mandatory=$false)]
        $lookupId,
        [Parameter(Mandatory=$false)]
        $lookupFieldValue
    )

    $lookupfield = $list.Fields.GetField($fieldName) -as [Microsoft.SharePoint.SPFieldLookup];
    $lookuplist = $web.Lists[[Guid]$lookupfield.LookupList];

    If ($lookupId -ne $null) {
        $lookupitem = $lookuplist.GetItemById($lookupId);
    } elseIf ($lookupFieldValue -ne $null) {

        if ($lookuplist.Fields.GetField([string]$lookupfield.LookupField).TypeAsString -eq "Calculated") {
            $lookupitem = @($lookuplist.Items | where {($_.Fields.GetField([string]$lookupfield.LookupField) -as [Microsoft.SharePoint.SPFieldCalculated]).GetFieldValueAsText($_[[string]$lookupfield.LookupField]) -eq $lookupFieldValue}) | Select-Object -first 1
        } else {            
            $lookupitem = @($lookuplist.Items | where {$_[[string]$lookupfield.LookupField] -eq $lookupFieldValue}) | Select-Object -first 1
        }
         
    } else {
        throw "Incorrect parameters supplied to Set-LookupField function"
    }

    try{
        $lookupvalue = New-Object Microsoft.SharePoint.SPFieldLookupValue($lookupitem.ID,$lookupitem.ID.ToString());
        $item[$fieldName] = $lookupvalue;
        $item.Update();
    } catch {
        Write-Host "lookup field update error, please check if supplied value exists (value: $lookupFieldValue, id: $lookupId)"
    }
}

Add-PSSnapin Microsoft.SharePoint.PowerShell -EA SilentlyContinue

$webUrl = Read-Host 'Web url'
$listUrl = Read-Host 'List url'
$filePath = Read-Host 'File path'

$web = Get-SPWeb $webUrl

$dataList = import-csv -Path "$filePath"
$spList = $web.GetList($web.Url + "/Lists/" + $listUrl)

$r = 1;
$itemCount = $dataList.Count;
$currentItemCount = 1;
foreach($dataItem in $dataList) {
    Write-Progress -Id 1 -ParentId 0 -Activity "Importing Data From CSV into SharePoint" -PercentComplete (($currentItemCount/$itemCount)*100) -Status "Adding item $currentItemCount or $itemCount";
    $currentItemCount++;
    $item = $spList.items.Add();

    $csvProperties = @($dataItem | Get-Member -MemberType Properties | Select-Object -ExpandProperty Name | Select-Object -Unique)

    foreach ($fieldName in $csvProperties){
        if ($spList.Fields.ContainsField($fieldName)) {
            $fieldValue = $dataItem | Select -ExpandProperty $fieldName;

            if ($fieldValue -ne $null -and $fieldValue -ne "") {
                if ($spList.Fields.GetField($fieldName).TypeAsString -eq "Lookup") {
                    Set-LookupField -web $web -list $spList -item $item -fieldName $fieldName -lookupFieldValue $fieldValue
                } else {
                    $item[$fieldName] = $fieldValue;
                }
            }
        }
    }

    $item.Update()
    Write-Host ([String]::Format("Added record:{0}",$r));
    $r++;
}
