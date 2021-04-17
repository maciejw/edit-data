[CmdletBinding(DefaultParameterSetName = "SortSet")]
<#
.SYNOPSIS
  Edits flat object stored in flat yaml mapping format
.DESCRIPTION
  You can add, edit or remove data from flat yaml mapping file. 
  Edits and removes are selected using powershells Out-GridView.
  after all edits file is sorted using invariant culture

  Format:
  key1: value
  key2: other value
.EXAMPLE
  Adds some-name: 'some value' entry to data.yml
  PS C:\> EditData.ps1 data.yml -add -name "some-name" -value "some value"
  
  Edit entries from data.yml
  PS C:\> EditData.ps1 data.yml -edit
  edits will be prompted by Gridview to select entries to edit, followed by prompts for selected entries
  
  Remove entries from data.yml
  PS C:\> EditData.ps1 data.yml -remove
  removes will be prompted by Gridview to select entries to remove
  
  Sorts entries in data.yml
  PS C:\> EditData.ps1 data.yml -sort
  sorts a file
#>
param (
  [Parameter(Mandatory, Position = 0, ParameterSetName = "AddSet")]
  [Parameter(Mandatory, Position = 0, ParameterSetName = "EditSet")]
  [Parameter(Mandatory, Position = 0, ParameterSetName = "RemoveSet")]
  [Parameter(Mandatory, Position = 0, ParameterSetName = "SortSet")]
  [string]$yamlFile,
  [Parameter(Mandatory, ParameterSetName = "AddSet")]
  [switch]$add,
  [Parameter(Mandatory, ParameterSetName = "AddSet")]
  [string]$name,
  [Parameter(Mandatory, ParameterSetName = "AddSet")]
  [string]$value,

  [Parameter(Mandatory, ParameterSetName = "EditSet")]
  [switch]$edit,

  [Parameter(Mandatory, ParameterSetName = "RemoveSet")]
  [switch]$remove,

  [Parameter(Mandatory, ParameterSetName = "SortSet")]
  [switch]$sort,

  [Parameter(Mandatory, ParameterSetName = "TestSet")]
  [switch]$test
)

function AddEntry {
  param (
    [Parameter(Mandatory, ValueFromPipeline)]
    [hashtable]$data,
    [Parameter(Mandatory)]
    [string]$name,
    [Parameter(Mandatory)]
    [string]$value
  )
  
  if ($null -eq $data ) {
    $data = @{}
  }
  
  if ($data.ContainsKey($name)) {
    $errorMessage = "Property '$name' already exists in data"
    throw $errorMessage
  }
  
  $data.GetEnumerator() | ForEach-Object -Begin { 
    $results = @{} 
    $results | Out-Null
  } {
    $results.Add($_.Key, $_.Value)
  } -End {
    $results.Add($name, $value)
    $results 
  } 
}

function PromptNewValue {
  param (
    $name, 
    $value
  )
  Write-Host "Edit entry " -NoNewline
  Write-Host "'$name'" -ForegroundColor Green
  Write-Host "Current value is " -NoNewline
  Write-Host "'$value'" -ForegroundColor Green
  Read-Host -Prompt "'$name': enter new value, hit [Enter] to accept (empty value skips edit)"
}

function EditData {
  param (
    [Parameter(Mandatory, ValueFromPipeline)]
    [hashtable]$data
  )
  $editedValues = $data | Out-GridView -OutputMode Multiple -Title "Select entries to edit values" | ForEach-Object -Begin {
    $results = @{}
    $results | Out-Null
  } {
    $result = PromptNewValue -name $_.Key -value $_.Value
    if ($result -ne "") {
      $results.Add($_.Key, $result)
    }
  } -End { $results }
  
  $data.GetEnumerator() | ForEach-Object -Begin { 
    $results = @{} 
    $results | Out-Null 
  } {
    $currentKey = $_.Name
    $currentValue = $_.Value
    if ($editedValues.ContainsKey($currentKey)) {
      $currentValue = $editedValues[$currentKey]
    }
    $results.Add($currentKey, $currentValue)
  } -End { $results } 
}

function RemoveData {
  param (
    [Parameter(Mandatory, ValueFromPipeline)]
    [hashtable]$data
  )
  $valuesToRemove = $data | Out-GridView -OutputMode Multiple -Title "Select entries to remove" | ForEach-Object -Begin {
    $results = @{}
    $results | Out-Null
  } {
    $results.Add($_.Key, $result)
  } -End { $results }

  $data.GetEnumerator() | ForEach-Object -Begin {
    $results = @{} 
    $results | Out-Null 
  } {
    $currentKey = $_.Name
    $currentValue = $_.Value
    if (-not $valuesToRemove.ContainsKey($currentKey)) {
      $results.Add($currentKey, $currentValue)
    }
  } -End { $results } 
}

$comparer = [System.StringComparer]::OrdinalIgnoreCase
function SortLines {
  param (
    [Parameter(Position = 0, ValueFromPipeline)]
    [string]$line
  )
  begin {
    $lines = [System.Collections.ArrayList]::new();
  }
  process {
    $lines.Add($line) | Out-Null
  }
  end {
    $result = [string[]]$lines.ToArray()
    [array]::Sort($result, $comparer)
    return $result
  }
}

function ConvertFrom-KeyValue {
  [CmdletBinding()]
  param(
    [Parameter(ValueFromPipeline)]
    [string]
    $line
  )
  begin {
    $results = [ordered]@{}
    $lineNumber = 0;
  }
  process {
    if ("" -eq "$line" ) {
      return
    }
    $result = $line | Select-String -Pattern "^(?<Key>.+?)\s*:\s*(?<Value>.*?)\s*$"
    if ($result.Matches.Count -eq 1 -and $result.Matches[0].Success) {
      $Key, $Value = $result.Matches[0].Groups['Key', 'Value'].Value
      $results[$Key] = "$Value"
    }
    else {
      Write-Error "Line number $lineNumber has invalid format. Expected format is 'key:value', line is '$line'"
    }
    $lineNumber = $lineNumber + 1
  
  }
  end {
    if ($results.Count -eq 0) {
      return
    }
    $results
  }
}
function ConvertTo-KeyValue {
  [CmdletBinding()]
  param(
    [Parameter(ValueFromPipeline)]
    $item
  )
  process {
    if ($null -eq $item) {
      return
    }
    $format = {
      "$($_.Key): $($_.Value)"
    }
    if ($item -is [System.Collections.IDictionary]) {
      $item.GetEnumerator() | ForEach-Object $format
      return
    }
    if ($item -is [System.Collections.DictionaryEntry]) {
      $item | ForEach-Object $format
      return
    }

    Write-Error "Only IDictionary or DirectoryEntry is supported here, item reveived $($item.GetType())"
  }
}
  
if ($test) {
  return
}

$data = Get-Content $yamlFile -ErrorAction SilentlyContinue | ConvertFrom-KeyValue

if ($add) {
  $newData = $data | AddEntry -name $name -value $value
}
if ($null -ne $data -and $edit) {
  $newData = $data | EditData 
}
if ($null -ne $data -and $remove) {
  $newData = $data | RemoveData
}
if ($null -ne $data -and $sort) {
  $newData = $data 
}
if ($null -ne $newData -and $newData.Count -eq 0) {
  Set-Content $yamlFile -Value "" -NoNewline
}

$newData | ConvertTo-KeyValue | SortLines | Set-Content $yamlFile
