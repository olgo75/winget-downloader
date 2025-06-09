# Script pour rechercher et télécharger des applications via winget
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true, Position=0, ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true)]
    [string]$ApplicationName,
    
    [Parameter(Mandatory=$false)]
    [string]$DownloadPath = "C:\tmp\Packages"
)

# Vérifier si le chemin de téléchargement existe
if (-not (Test-Path $DownloadPath)) {
    Write-Host "Le dossier de téléchargement n'existe pas. Création du dossier..."
    New-Item -ItemType Directory -Path $DownloadPath -Force | Out-Null
}

# Rechercher l'application
Write-Host "Recherche de l'application '$ApplicationName'..." -ForegroundColor Cyan
$searchResults = winget search $ApplicationName | Select-Object -Skip 2

# Afficher les résultats et demander à l'utilisateur de choisir
Write-Host "`nRésultats trouvés :" -ForegroundColor Green
$results = @()
$index = 1
$fl = 0
$lines = $searchResults.Split([Environment]::NewLine)
Try {
    while (-not $lines[$fl].StartsWith("Nom")){$fl++}
    $NameStart = $lines[$fl].IndexOf("Nom")
    $idStart = $lines[$fl].IndexOf("ID")
    $versionStart = $lines[$fl].IndexOf("Version")
    $matchStart = $lines[$fl].IndexOf("Correspondance")
    $sourceStart = $lines[$fl].IndexOf("Source")
} Catch {
    Write-Host "Aucun résultat trouvé pour '$ApplicationName'" -ForegroundColor Red
    exit
}

foreach ($line in $searchResults) {
    # Ignorer la ligne d'en-tête et les lignes de séparation
    if ($line -match "^Nom\s+" -or $line -match "^[\s\-]+$" -or $line -match "^1\s+\.\s+Nom") {
        continue
    }
    
    $name = $line.Substring($NameStart, $idStart - $NameStart).TrimEnd()
    $id = $line.Substring($idStart, $versionStart - $idStart).TrimEnd()
    If ($matchStart -ne -1) {
        $version = $line.Substring($versionStart, $matchStart - $versionStart).TrimEnd()
    } Else {
        $version = $line.Substring($versionStart, $sourceStart - $versionStart).TrimEnd()
    }

    
    # Affichage avec couleurs et alignement
    Write-Host ("{0,-2}. " -f $index) -NoNewline
    Write-Host ("{0,-25}" -f $name) -ForegroundColor Cyan -NoNewline
    Write-Host ("{0,-35}" -f $id) -ForegroundColor Yellow -NoNewline
    Write-Host $version -ForegroundColor Green
    
    $results += @{
        Id = $id
        Version = $version
        Name = $name
    }
    $index++
}

# Fonction pour créer la structure de dossiers
function Create-DownloadStructure {
    param (
        [string]$BasePath,
        [string]$AppName,
        [string]$Version
    )
    
    # Créer le dossier de l'application
    $appFolder = Join-Path $BasePath $AppName
    if (-not (Test-Path $appFolder)) {
        New-Item -ItemType Directory -Path $appFolder -Force | Out-Null
        Write-Host "Création du dossier : $appFolder" -ForegroundColor Yellow
    }
    
    # Créer le dossier de version
    $versionFolder = Join-Path $appFolder $Version
    if (-not (Test-Path $versionFolder)) {
        New-Item -ItemType Directory -Path $versionFolder -Force | Out-Null
        Write-Host "Création du dossier : $versionFolder" -ForegroundColor Yellow
    }
    
    return $versionFolder
}

# Si un seul résultat est trouvé, le télécharger directement
if ($results.Count -eq 1) {
    $selectedApp = $results[0]
    Write-Host "`nUn seul résultat trouvé. Téléchargement de $($selectedApp.Name) (Version: $($selectedApp.Version))..." -ForegroundColor Green
    
    # Créer la structure de dossiers
    $downloadFolder = Create-DownloadStructure -BasePath $DownloadPath -AppName $selectedApp.Name -Version $selectedApp.Version
    
    # Télécharger l'application dans le sous-dossier
    winget download --id $selectedApp.Id --download-directory $downloadFolder
    
    Write-Host "`nTéléchargement terminé. Le fichier se trouve dans : $downloadFolder" -ForegroundColor Green
    exit
}

# Demander à l'utilisateur de choisir si plusieurs résultats
Write-Host "`nEntrez le numéro de l'application à télécharger (1-$($results.Count)) : " -ForegroundColor DarkGray -NoNewline
$choice = Read-Host

# Vérifier si le choix est valide
if ($choice -match "^\d+$" -and [int]$choice -ge 1 -and [int]$choice -le $results.Count) {
    $selectedApp = $results[[int]$choice - 1]
    Write-Host "`nTéléchargement de $($selectedApp.Name) (Version: $($selectedApp.Version))..." -ForegroundColor Green
    
    # Créer la structure de dossiers
    $downloadFolder = Create-DownloadStructure -BasePath $DownloadPath -AppName $selectedApp.Name -Version $selectedApp.Version
    
    # Télécharger l'application dans le sous-dossier
    winget download --id $selectedApp.Id --version $selectedApp.Version --download-directory $downloadFolder --accept-package-agreements --accept-source-agreements
    
    Write-Host "`nTéléchargement terminé. Le fichier se trouve dans : $downloadFolder" -ForegroundColor Green   
} else {
    Write-Host "Choix invalide. Veuillez sélectionner un numéro valide." -ForegroundColor Red
}