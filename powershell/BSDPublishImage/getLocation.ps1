$locJson = azure location list --json|ConvertFrom-Json

foreach($loc in $locJson) {
  echo $loc.displayName
}
