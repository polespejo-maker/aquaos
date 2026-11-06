<#
    AquaOS · compila la ISO dentro de Docker (Windows)

    Requisitos:
      - Docker Desktop con backend WSL2 (o Hyper-V) y virtualización activada en la BIOS.
      - ~15 GB libres en el disco donde vive la carpeta del proyecto.

    Uso (PowerShell, desde la carpeta aquaos):
      .\scripts\build-in-docker.ps1
      .\scripts\build-in-docker.ps1 --no-aur --no-offline-repo

    Por qué copia el proyecto a un volumen en vez de compilar sobre C:\:
    los bind mounts de Windows son lentos y no conservan bien los permisos
    (mkarchiso necesita dueños y modos exactos). Se compila en el volumen y
    al final solo se copia la ISO a out\.
#>

[CmdletBinding()]
param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]] $BuildArgs = @(),
    [string]   $Image = "aquaos-builder",
    [string]   $Volume = "aquaos-work"
)

$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$Dockerfile = Join-Path $Root "docker\Dockerfile"
$OutDir = Join-Path $Root "out"

function Fallo($msg) { Write-Host " error " -ForegroundColor Red -NoNewline; Write-Host $msg; exit 1 }
function Info($msg)  { Write-Host "==> " -ForegroundColor Blue -NoNewline; Write-Host $msg }

if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    Write-Host ""
    Write-Host " Docker Desktop no esta instalado. Pasos (una sola vez):" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "   1. Abre PowerShell COMO ADMINISTRADOR y ejecuta:   wsl --install"
    Write-Host "   2. Reinicia el PC."
    Write-Host "   3. Instala Docker Desktop:  https://www.docker.com/products/docker-desktop/"
    Write-Host "   4. Abre Docker Desktop y espera a 'Engine running'."
    Write-Host "   5. Vuelve a lanzar este script."
    Write-Host ""
    $r = Read-Host " ¿Abrir la pagina de descarga ahora? (s/N)"
    if ($r -match '^(s|si|y|yes)$') { Start-Process "https://www.docker.com/products/docker-desktop/" }
    exit 1
}

docker info *> $null
if ($LASTEXITCODE -ne 0) {
    Fallo "Docker está instalado pero el motor no responde. Abre Docker Desktop y espera a que diga 'Engine running'."
}

# Docker Desktop en Windows solo ejecuta contenedores Linux, que es justo lo que necesitamos.
$osType = (docker info --format '{{.OSType}}') 2>$null
if ($osType -and $osType.Trim() -ne "linux") {
    Fallo "Docker está en modo '$osType'. Cambia a contenedores Linux en Docker Desktop."
}

$libreGb = [math]::Round((Get-PSDrive -Name ((Split-Path $Root -Qualifier).TrimEnd(':'))).Free / 1GB, 1)
if ($libreGb -lt 15) {
    Write-Host " aviso  " -ForegroundColor Yellow -NoNewline
    Write-Host "solo quedan $libreGb GB libres; el build necesita ~14 GB (más el volumen de Docker)."
}

if (-not (Test-Path $OutDir)) { New-Item -ItemType Directory -Path $OutDir | Out-Null }

Info "Construyendo la imagen $Image (la primera vez descarga Arch Linux, ~500 MB)"
docker build -t $Image (Split-Path -Parent $Dockerfile)
if ($LASTEXITCODE -ne 0) { Fallo "docker build ha fallado" }

$extra = ($BuildArgs -join " ")
# Se limpia el volumen en cada build para que no queden restos de ejecuciones
# anteriores; se conserva el código de salida de build.sh (el `|| true` final
# solo afecta a la copia de la ISO).
$comando = @"
rm -rf /work/* /work/.[!.]* 2>/dev/null
cp -a /src/. /work/
./build.sh $extra
rc=`$?
cp -v /work/out/* /out/ 2>/dev/null
exit `$rc
"@

Info "Compilando la ISO dentro del contenedor (20-60 min)"
Write-Host "      argumentos para build.sh: '$extra'"

docker run --rm -it --privileged `
    --name aquaos-build `
    -e TERM=xterm-256color `
    -v "${Volume}:/work" `
    -v "${Root}:/src:ro" `
    -v "${OutDir}:/out" `
    $Image `
    bash -lc $comando

if ($LASTEXITCODE -ne 0) {
    Fallo "el build ha fallado. Revisa el mensaje de arriba."
}

$iso = Get-ChildItem $OutDir -Filter *.iso -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $iso) {
    Fallo "el contenedor terminó pero no hay ninguna ISO en $OutDir"
}

Write-Host ""
Write-Host "  ISO lista: " -NoNewline
Write-Host $iso.FullName -ForegroundColor Green
Write-Host ("  tamaño:    {0:N2} GB" -f ($iso.Length / 1GB))
Write-Host ""
Write-Host "  Para probarla necesitas una máquina virtual (Docker no muestra escritorio):"
Write-Host "    - VirtualBox: VM tipo Arch/Other Linux 64-bit, 4 GB RAM, 25 GB disco, EFI activado,"
Write-Host "      y monta esta ISO como disco óptico."
Write-Host "    - O graba un USB con Rufus/balenaEtcher (borra el USB)."
Write-Host ""
Write-Host "  Usuario: aqua   Contraseña: aqua"
