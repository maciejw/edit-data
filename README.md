# EditData.ps1

  Edits flat object stored in yaml format

## DESCRIPTION

  You can add, edit or remove data from yaml file. 
  Edits and removes are selected using powershell Out-GridView.
  after all edits file is sorted using invariant culture

## EXAMPLES

  Adds some-name: 'some value' entry to data.yml
  
  ```powershell
  EditData.ps1 data.yml -add -name "some-name" -value "some value"
  ```

  Edit entries from data.yml
  
  ```powershell
  EditData.ps1 data.yml -edit
  ```
  
  edits will be prompted by Gridview to select entries to edit, followed by prompts for selected entries
  
  Remove entries from data.yml
  
  ```powershell
  EditData.ps1 data.yml -remove
  ```
  
  removes will be prompted by Gridview to select entries to remove
  
  Sorts entries in data.yml
  
  ```powershell
  EditData.ps1 data.yml -sort
  ```

  sorts a file using ordinal case insensitive comparer
