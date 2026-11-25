# Aplica a marca RP Remoto no submodulo libs/hbb_common (que nao vai para o fork).
# Rodar na raiz do repositorio. Sai com codigo 1 se algum alvo nao for encontrado.
$ErrorActionPreference = 'Stop'

$file = Join-Path (Get-Location) 'libs/hbb_common/src/config.rs'
if (-not (Test-Path $file)) {
    Write-Error "Arquivo nao encontrado: $file (rode na raiz do repo, com submodulos baixados)"
    exit 1
}

$utf8 = New-Object System.Text.UTF8Encoding($false)
$text = [System.IO.File]::ReadAllText($file, $utf8)

$rules = @(
    @{ Name = 'APP_NAME';           Pattern = '(?m)(pub static ref APP_NAME: RwLock<String> = RwLock::new\()"RustDesk"(\.to_owned\(\)\);)'; Replace = '${1}"RP-Remoto"${2}' },
    @{ Name = 'RENDEZVOUS_SERVERS'; Pattern = '(?m)(pub const RENDEZVOUS_SERVERS: &\[&str\] = )&\[[^\]]*\];';                                   Replace = '${1}&["159.112.188.37"];' },
    @{ Name = 'RS_PUB_KEY';         Pattern = '(?m)(pub const RS_PUB_KEY: &str = )"[^"]*";';                                                       Replace = '${1}"xX3taUdvSXafNLLBzCA568xCxayyUEnWUPESmkm8tLY=";' }
)

foreach ($r in $rules) {
    if (-not [regex]::IsMatch($text, $r.Pattern)) {
        Write-Error "Alvo nao encontrado: $($r.Name)"
        exit 1
    }
    $text = [regex]::Replace($text, $r.Pattern, $r.Replace)
    Write-Host "OK: $($r.Name)"
}

# Senha padrao permanente: entra so o hash com sal (vem de secrets do GitHub, nunca do repo).
$storage = $env:RP_PASSWORD_STORAGE
$salt = $env:RP_PASSWORD_SALT
if ([string]::IsNullOrEmpty($storage) -or [string]::IsNullOrEmpty($salt)) {
    Write-Error 'RP_PASSWORD_STORAGE e RP_PASSWORD_SALT precisam estar definidos (secrets do GitHub)'
    exit 1
}
if ($storage -notmatch '^[A-Za-z0-9+/=]+$' -or $salt -notmatch '^[A-Za-z0-9]+$') {
    Write-Error 'Formato invalido do hash ou do sal'
    exit 1
}
$hard = '(?m)(pub static ref HARD_SETTINGS: RwLock<HashMap<String, String>> = )Default::default\(\);'
$def  = '(?m)(pub static ref DEFAULT_SETTINGS: RwLock<HashMap<String, String>> = )Default::default\(\);'
foreach ($p in @($hard, $def)) {
    if (-not [regex]::IsMatch($text, $p)) { Write-Error "Alvo nao encontrado: $p"; exit 1 }
}
$text = [regex]::Replace($text, $hard, ('${1}RwLock::new(HashMap::from([("password".to_owned(), "' + $storage + '".to_owned()), ("salt".to_owned(), "' + $salt + '".to_owned())]));'))
$text = [regex]::Replace($text, $def, '${1}RwLock::new(HashMap::from([("verification-method".to_owned(), "use-permanent-password".to_owned()), ("approve-mode".to_owned(), "password".to_owned())]));')
Write-Host 'OK: senha padrao (hash) e modo de aprovacao por senha'

[System.IO.File]::WriteAllText($file, $text, $utf8)
Write-Host 'Marca RP Remoto aplicada em libs/hbb_common/src/config.rs'
