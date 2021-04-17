BeforeAll {
  . .\EditData.ps1 -test
}

Describe "EditData" {
  Context "Add" {
    It "Should add new entry to new file" {
      $file = "TestDrive:/non-existent-file"

      .\EditData.ps1 $file -add -Name "some-value" -value "some data"
      
      $file | Should -Exist
      $data = Get-Content $file | ConvertFrom-KeyValue
      
      $data | Should -Not -BeNullOrEmpty -ErrorAction Stop
      $data.Keys.Count | Should -Be 1
      $data["some-value"] | Should -Be "some data"
    }
    It "Should not add existing entry again" {
      $file = "TestDrive:/existent-file"

      @{"some-value" = "some data" } | ConvertTo-KeyValue | Set-Content $file
      
      { .\EditData.ps1 $file -add -Name "some-value" -value "some data" } `
      | Should -Throw "Property 'some-value' already exists in data"
    }
  }

  Context "Edit" {
    It "Should edit selected entries" {
      Mock PromptNewValue { "new value" } -Verifiable -ParameterFilter { $name -eq "some-value" }
      Mock Out-GridView { [System.Collections.DictionaryEntry]::new("some-value", "some value") } -Verifiable -ParameterFilter { $OutputMode -eq "Multiple" }
  
      $file = "TestDrive:/existent-file"
      @{"some-value" = "some value"; "some-other-value" = "some other value" } | ConvertTo-KeyValue | Set-Content $file
      .\EditData.ps1 $file -edit

      Should -InvokeVerifiable
      $data = Get-Content $file | ConvertFrom-KeyValue 
      
      $data | Should -Not -BeNullOrEmpty
      $data.Keys.Count | Should -Be 2
      $data.Keys | Should -Contain "some-value"
      $data["some-value"] | Should -Be "new value" 
      $data.Keys | Should -Contain "some-other-value"
      $data["some-other-value"] | Should -Be "some other value" 
    }
    It "Should skip edit selected entries" {
      Mock PromptNewValue { "" } -Verifiable -ParameterFilter { $name -eq "some-value" }
      Mock Out-GridView { [System.Collections.DictionaryEntry]::new("some-value", "some value") } -Verifiable -ParameterFilter { $OutputMode -eq "Multiple" }
  
      $file = "TestDrive:/existent-file"
      @{"some-value" = "some value"; "some-other-value" = "some other value" } | ConvertTo-KeyValue | Set-Content $file
      .\EditData.ps1 $file -edit

      Should -InvokeVerifiable
      $data = Get-Content $file | ConvertFrom-KeyValue 
      
      $data | Should -Not -BeNullOrEmpty
      $data.Keys.Count | Should -Be 2
      $data.Keys | Should -Contain "some-value"
      $data["some-value"] | Should -Be "some value" 
      $data.Keys | Should -Contain "some-other-value"
      $data["some-other-value"] | Should -Be "some other value" 
    }
    It "Should do nothing when file does not exits" {
      $file = "TestDrive:/non-existent-file"
      .\EditData.ps1 $file -edit
      
      $file | Should -Not -Exist 
    }
    It "Should do nothing when file is empty" {
      Mock Out-GridView
      Mock PromptNewValue
      $file = "TestDrive:/existent-file"
      "" | Set-Content $file -NoNewline
      $expectedLength = (Get-Item $file).Length
      
      .\EditData.ps1 $file -edit

      Should -Not -Invoke Out-GridView
      Should -Not -Invoke PromptNewValue
      (Get-Item $file).Length | Should -Be $expectedLength
    }
  }

  Context "Remove" {
    It "Should remove selected entries" {
      Mock Out-GridView { 
        return @(
          [System.Collections.DictionaryEntry]::new("some-value", "some value"),
          [System.Collections.DictionaryEntry]::new("some-other-value", "some other value")
        ) } -Verifiable -ParameterFilter { $OutputMode -eq "Multiple" }
  
      $file = "TestDrive:/existent-file"
      @{"some-value" = "some value"; "some-other-value" = "some other value" } | ConvertTo-KeyValue | Set-Content $file
      .\EditData.ps1 $file -remove

      Should -InvokeVerifiable
      
      Get-Content $file -Raw | Should -Be $null
    }
  }
  Context "Sort" {
    It "Should sort a file using ordinal case insensitive comparer" {
      $file = "TestDrive:/existent-file"
      @'
SOMEOTHERVALUE2: some other value
someothervalue1: some other value
some_value_DB10: some value
SOME_VALUE_DB2: some value
some_value_DB11: some value
some_value_DB3: some value
some_value_DB0: some value
some_value_DB12: some value
some_value_DB13: some value
some_value_DB14: some value
some_value_DB1: some value
some_value_DB4: some value
'@ | Set-Content $file

      .\EditData.ps1 $file -sort

      $data = Get-Content $file -Raw
      $data | Should -Be @'
someothervalue1: some other value
SOMEOTHERVALUE2: some other value
some_value_DB0: some value
some_value_DB10: some value
some_value_DB11: some value
some_value_DB12: some value
some_value_DB13: some value
some_value_DB14: some value
some_value_DB1: some value
SOME_VALUE_DB2: some value
some_value_DB3: some value
some_value_DB4: some value

'@
    }
  }
  Context "Parsing" {
    It "Should deserialize key value data" {
      $data = "key1:value1", "key2 : value2", "key3 :value3", "key4:" | ConvertFrom-KeyValue

      $data["key1"] | Should -Be "value1"
      $data["key2"] | Should -Be "value2"
      $data["key3"] | Should -Be "value3"
      $data["key4"] | Should -Be ""
    }
    It "Should not process empty lines" {
      Mock Write-Error -Verifiable -ParameterFilter { $Message -match "Line number 0 has invalid format. Expected format is 'key:value', line is ''" }
      $data = "" | ConvertFrom-KeyValue

      $data | Should -Be $null
      Should -Not -Invoke Write-Error
    }
    It "Should not process null lines" {
      Mock Write-Error -Verifiable -ParameterFilter { $Message -match "Line number 0 has invalid format. Expected format is 'key:value', line is ''" }
      $data = $null | ConvertFrom-KeyValue

      $data | Should -Be $null
      Should -Not -Invoke Write-Error
    }
    It "Should not deserialize invalid lines" {
      Mock Write-Error -Verifiable -ParameterFilter { $Message -match "Line number 0 has invalid format. Expected format is 'key:value', line is 'key1value1'" }
      $data = "key1value1" | ConvertFrom-KeyValue

      $data | Should -Be $null
      Should -InvokeVerifiable
    }
    It "Should serialize ordered dictionary" {
      $data = [ordered]@{"key2" = "2"; "key1" = "1"; "key3" = "" } | ConvertTo-KeyValue

      $data | Should -Contain "key1: 1"
      $data | Should -Contain "key2: 2"
      $data | Should -Contain "key3: "
      
    }
    It "Should serialize hashtable" {
      $data = @{"key2" = "2"; "key1" = "1" } | ConvertTo-KeyValue

      $data | Should -Contain "key1: 1"
      $data | Should -Contain "key2: 2"
    }
    
    It "Should serialize dictionary entries" {
      $data = @{"key2" = "2"; "key1" = "1" }.GetEnumerator() | ConvertTo-KeyValue

      $data | Should -Contain "key1: 1"
      $data | Should -Contain "key2: 2"
    }
  }
}
