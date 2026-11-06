<#
    AquaOS · lanzador de escritorio (Windows)

    Arranca AquaOS en una maquina virtual de VirtualBox, en una ventana.
    NADA toca tu Windows: ni el disco, ni el arranque, ni el registro.
    Apagas la maquina virtual y vuelves a Windows. Reinicias el PC y arranca Windows.

    Uso:
        .\AquaOS.cmd
        .\AquaOS.cmd -Iso "D:\ruta\aquaos.iso"
        .\AquaOS.cmd -DesdeDisco      (si ya instalaste AquaOS dentro de la VM)

    La primera vez crea la VM "AquaOS" (4 GB de RAM, 4 CPU, disco de 30 GB).
#>

[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string] $Iso = "",
    [switch] $DesdeDisco,
    [switch] $Efi,
    [int]    $MemoriaMB = 4096,
    [int]    $Cpus = 4,
    [switch] $Recrear
)

$ErrorActionPreference = "Stop"

$PlayerDir = $PSScriptRoot
$Root      = Split-Path -Parent $PlayerDir
$VMDir     = Join-Path $PlayerDir "vm"
$VMName    = "AquaOS"

function Info($m) { Write-Host "==> " -ForegroundColor Blue -NoNewline; Write-Host $m }
function Ok($m)   { Write-Host "  ok " -ForegroundColor Green -NoNewline; Write-Host $m }
function Aviso($m){ Write-Host " aviso " -ForegroundColor Yellow -NoNewline; Write-Host $m }
function Morir($m){ Write-Host " error " -ForegroundColor Red -NoNewline; Write-Host $m; exit 1 }

# ---------------------------------------------------------------------------
# Une los trozos de ISO descargados de GitHub Actions (aquaos.iso.part-00, ...)
# ---------------------------------------------------------------------------
function Unir-Partes([System.IO.FileInfo[]] $Partes, [string] $Destino) {
    $orden = $Partes | Sort-Object Name
    $salida = [System.IO.File]::Create($Destino)
    try {
        foreach ($p in $orden) {
            $entrada = [System.IO.File]::OpenRead($p.FullName)
            try {
                $entrada.CopyTo($salida)
            }
            finally {
                $entrada.Dispose()
            }
        }
    }
    finally {
        $salida.Dispose()
    }
}

# ---------------------------------------------------------------------------
# 1. VirtualBox
# ---------------------------------------------------------------------------
$vbm = "C:\Program Files\Oracle\VirtualBox\VBoxManage.exe"
if (-not (Test-Path $vbm)) {
    $cmd = Get-Command VBoxManage -ErrorAction SilentlyContinue
    if ($cmd) { $vbm = $cmd.Source }
}
if (-not (Test-Path $vbm)) {
    Morir "no encuentro VirtualBox. Instalalo con:  winget install -e --id Oracle.VirtualBox"
}
$vboxVersion = (& $vbm --version) 2>$null

# ---------------------------------------------------------------------------
# 2. ISO
# ---------------------------------------------------------------------------
$OutDir = Join-Path $Root "out"

# Si viene de GitHub Actions, la ISO llega troceada (aquaos.iso.part-00, -01...).
# Se une aqui la primera vez.
$partes = @(Get-ChildItem -Path $OutDir -Recurse -File -Filter "*.part-*" -ErrorAction SilentlyContinue)
if ($partes.Count -gt 0) {
    $yaHayIso = @(Get-ChildItem -Path $OutDir -Recurse -File -Filter "*.iso" -ErrorAction SilentlyContinue)
    if ($yaHayIso.Count -eq 0) {
        $destino = Join-Path $OutDir "aquaos.iso"
        $tam = ($partes | Measure-Object Length -Sum).Sum
        $libreGb = [math]::Round((Get-PSDrive -Name ((Split-Path $OutDir -Qualifier).TrimEnd(':'))).Free / 1GB, 1)
        if ($libreGb -lt [math]::Round($tam / 1GB, 1) + 1) {
            Morir "hacen falta ~$([math]::Round($tam/1GB,1)) GB libres para unir la ISO y solo quedan $libreGb GB"
        }
        Info "Uniendo $($partes.Count) trozos descargados ($([math]::Round($tam/1GB,2)) GB)"
        Unir-Partes $partes $destino
        Ok "ISO creada: $destino"

        $sumfile = Get-ChildItem -Path $OutDir -Recurse -File -Filter "SHA256SUMS" -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($sumfile) {
            $esperado = ((Get-Content $sumfile.FullName -TotalCount 1) -split '\s+')[0].ToLower()
            $real = (Get-FileHash $destino -Algorithm SHA256).Hash.ToLower()
            if ($esperado -and $real -ne $esperado) {
                Morir "la ISO unida no coincide con el SHA256 (esperado $esperado, obtenido $real). Vuelve a descargarla."
            }
            Ok "SHA256 verificado"
        }
        $partes | Remove-Item -Force -ErrorAction SilentlyContinue
    }
}

if (-not $Iso) {
    $candidatas = @()
    $candidatas += Get-ChildItem -Path $OutDir     -Recurse -File -Filter *.iso -ErrorAction SilentlyContinue
    $candidatas += Get-ChildItem -Path (Join-Path $PlayerDir "iso") -Recurse -File -Filter *.iso -ErrorAction SilentlyContinue
    $elegida = $candidatas | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if ($elegida) { $Iso = $elegida.FullName }
}

if (-not $DesdeDisco) {
    if (-not $Iso -or -not (Test-Path $Iso)) {
        Write-Host ""
        Morir @"
no hay ninguna ISO de AquaOS.

  La ISO todavia no se ha compilado. Opciones:
    A) GitHub Actions (sin permisos de administrador):
       abre EMPIEZA-AQUI.txt y sigue los 6 pasos.
    B) Docker Desktop:   .\scripts\build-in-docker.ps1
    C) En una VM Arch:   sudo ./build.sh

  Cuando exista, quedara en:  $OutDir\aquaos-0.1.*-x86_64.iso
"@
    }
}
elseif ($Iso -and -not (Test-Path $Iso)) {
    Morir "la ISO indicada no existe: $Iso"
}

# ---------------------------------------------------------------------------
# 3. Crear la VM si no existe
# ---------------------------------------------------------------------------
$existe = (& $vbm list vms) -match "`"$VMName`""
if ($Recrear -and $existe) {
    Info "Borrando la VM anterior '$VMName'"
    & $vbm controlvm $VMName poweroff 2>$null | Out-Null
    Start-Sleep -Seconds 1
    & $vbm unregistervm $VMName --delete 2>$null | Out-Null
    $existe = $false
}

if (-not $existe) {
    if (-not (Test-Path $VMDir)) { New-Item -ItemType Directory -Path $VMDir | Out-Null }

    $hostCpus = (Get-CimInstance Win32_ComputerSystem).NumberOfLogicalProcessors
    if ($Cpus -gt $hostCpus) { $Cpus = $hostCpus }
    $hostRamGB = [math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB)
    if ($hostRamGB -lt 8 -and $MemoriaMB -gt 3072) { $MemoriaMB = 3072 }

    Info "Creando la maquina virtual '$VMName' ($MemoriaMB MB, $Cpus CPU)"
    & $vbm createvm --name $VMName --ostype ArchLinux_64 --register --basefolder $VMDir | Out-Null
    & $vbm modifyvm $VMName `
        --memory $MemoriaMB --cpus $Cpus --vram 128 `
        --graphicscontroller vmsvga --accelerate3d on `
        --audio-enabled on --nic1 nat --ioapic on --rtcuseutc on | Out-Null
    # Portapapeles y arrastrar-y-soltar (no existe en versiones antiguas: se ignora el fallo)
    & $vbm modifyvm $VMName --clipboard-mode bidirectional --draganddrop bidirectional 2>$null | Out-Null
    if ($Efi) { & $vbm modifyvm $VMName --firmware efi | Out-Null }

    & $vbm storagectl $VMName --name SATA --add sata --controller IntelAhci --portcount 2 --bootable on | Out-Null
    $vdi = Join-Path $VMDir "$VMName.vdi"
    & $vbm createmedium disk --filename $vdi --size 30720 --format VDI --variant Standard | Out-Null
    & $vbm storageattach $VMName --storagectl SATA --port 1 --device 0 --type hdd --medium $vdi | Out-Null
    Ok "VM creada (disco de 30 GB, crece segun se usa)"
}

# ---------------------------------------------------------------------------
# 4. Conectar la ISO y arrancar
# ---------------------------------------------------------------------------
$enMarcha = (& $vbm list runningvms) -match "`"$VMName`""
if ($enMarcha) {
    Morir "la maquina '$VMName' ya esta encendida. Cierra esa ventana primero."
}

if ($DesdeDisco) {
    Info "Arrancando desde el disco virtual (modo instalado)"
    & $vbm storageattach $VMName --storagectl SATA --port 0 --device 0 --type dvddrive --medium none | Out-Null
    & $vbm modifyvm $VMName --boot1 disk --boot2 none --boot3 none --boot4 none | Out-Null
} else {
    Info ("Arrancando la ISO: " + (Split-Path $Iso -Leaf))
    & $vbm storageattach $VMName --storagectl SATA --port 0 --device 0 --type dvddrive --medium $Iso | Out-Null
    & $vbm modifyvm $VMName --boot1 dvd --boot2 disk --boot3 none --boot4 none | Out-Null
    Ok "la ISO se arranca en cada inicio (modo live)"
}

Write-Host ""
Write-Host "  AquaOS se abre en una ventana. Tu Windows sigue intacto detras." -ForegroundColor Cyan
Write-Host "  Usuario: aqua    Contrasena: aqua"
Write-Host ""
Write-Host "  Para salir: menu de AquaOS > Apagar, y luego cierra la ventana."
Write-Host "  Para reiniciar el PC y volver a Windows: simplemente reinicia."
Write-Host ""

& $vbm startvm $VMName --type gui
if ($LASTEXITCODE -ne 0) {
    Morir @"
VirtualBox no pudo arrancar la VM.

  Causa habitual: Hyper-V esta activo y VirtualBox 7.0.6 va lento o falla con 3D.
  Prueba:   VBoxManage modifyvm $VMName --accelerate3d off

  Otra opcion: crea la VM a mano en la interfaz grafica de VirtualBox
  (tipo Arch Linux 64-bit, EFI, 4 GB, y la ISO como disco optico).
"@
}
