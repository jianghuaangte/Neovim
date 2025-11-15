# Use GH_PROXY environment variable if set, otherwise default to empty
if (-not $env:GH_PROXY) {
    $GH_PROXY = ""
} else {
    $GH_PROXY = $env:GH_PROXY
}

function Test-Url {
    param([string]$Url)
    try {
        $response = Invoke-WebRequest -Uri $Url -Method Head -UseBasicParsing -TimeoutSec 5
        return $true
    } catch {
        return $false
    }
}

try {
    Write-Host "Fetching latest Neovim release..."

    $repo = "neovim/neovim"
    $apiUrl  = "https://api.github.com/repos/$repo/releases/latest"
    $headers = @{ "User-Agent" = "PowerShellScript" }

    # Fetch release JSON
    $json = Invoke-RestMethod -Uri $apiUrl -Headers $headers

    # Detect system architecture
    if ([Environment]::Is64BitOperatingSystem) {
        $fileNamePattern = "nvim-win64.msi"
    } else {
        $fileNamePattern = "nvim-win-arm64.msi"
    }

    $asset = $json.assets |
             Where-Object { $_.name -eq $fileNamePattern } |
             Select-Object -First 1

    if (-not $asset) { throw "MSI file not found: $fileNamePattern" }

    $downloadUrl = $asset.browser_download_url

    # Apply GH_PROXY if set and reachable
    if ($GH_PROXY -ne "") {
        $proxiedUrl = "$GH_PROXY$downloadUrl"
        if (Test-Url $proxiedUrl) {
            $downloadUrl = $proxiedUrl
            Write-Host "Using GH_PROXY for download: $GH_PROXY"
        } else {
            Write-Host "GH_PROXY is set but unreachable, using original URL"
        }
    }

    Write-Host "Found MSI: $($asset.name)"
    Write-Host "Download URL: $downloadUrl"

    $tmpDir = [System.IO.Path]::GetTempPath()
    $localFile = Join-Path -Path $tmpDir -ChildPath $asset.name

    Write-Host "Downloading to $localFile..."
    Invoke-WebRequest -Uri $downloadUrl -OutFile $localFile

    if (-not (Test-Path $localFile)) { throw "Download failed: $localFile does not exist" }

    Write-Host "Installing Neovim silently..."
    $installArgs = "/i `"$localFile`" /quiet /norestart"
    Start-Process -FilePath "msiexec.exe" -ArgumentList $installArgs -Wait -NoNewWindow

    # Update PATH for current PowerShell session
    $defaultInstallPath = "C:\Program Files\Neovim\bin"
    if (Test-Path $defaultInstallPath) {
        if (-not ($env:Path -split ";" | Where-Object { $_ -eq $defaultInstallPath })) {
            $env:Path += ";$defaultInstallPath"
            Write-Host "Updated PATH for current session: $defaultInstallPath"
        }
    }

    Write-Host "Writing Neovim init.lua configuration..."

    # Target directory: %USERPROFILE%\AppData\Local\nvim
    $NVIM_CONFIG_DIR = Join-Path $env:LOCALAPPDATA "nvim"
    $NVIM_CONFIG_FILE = Join-Path $NVIM_CONFIG_DIR "init.lua"

    # Ensure directory exists
    if (-not (Test-Path $NVIM_CONFIG_DIR)) {
        New-Item -Path $NVIM_CONFIG_DIR -ItemType Directory -Force | Out-Null
    }

    # init.lua content
    $initLuaContent = @"
-- Enable line numbers
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.termguicolors = true

-- Tab settings
vim.opt.tabstop = 4
vim.opt.shiftwidth = 4
vim.opt.expandtab = true

-- Enable gj/gk movement
vim.api.nvim_set_keymap('n', 'j', 'gj', { noremap = true, silent = true })
vim.api.nvim_set_keymap('n', 'k', 'gk', { noremap = true, silent = true })
vim.api.nvim_set_keymap('v', 'j', 'gj', { noremap = true, silent = true })
vim.api.nvim_set_keymap('v', 'k', 'gk', { noremap = true, silent = true })

-- Clipboard setup (requires nvim 0.11+ and proper plugin)
vim.g.clipboard = {
  name = 'OSC 52',
  copy = {
    ['+'] = require('vim.ui.clipboard.osc52').copy('+'),
    ['*'] = require('vim.ui.clipboard.osc52').copy('*'),
  },
  paste = {
    ['+'] = require('vim.ui.clipboard.osc52').paste('+'),
    ['*'] = require('vim.ui.clipboard.osc52').paste('*'),
  },
}

-- Define helper function for key mapping
local function map(mode, lhs, rhs, opts)
  local options = { noremap = true }
  if opts then
    options = vim.tbl_extend("force", options, opts)
  end
  vim.keymap.set(mode, lhs, rhs, options)
end

-- Search functionality
map('n', ',s', function()
  local word = vim.fn.input("Search text > ")
  if word == nil or #word == 0 then
    vim.cmd('nohlsearch')
    return
  end

  local escaped_word = string.gsub(word, "\\", "\\\\")
  local literal_pattern = "\\V" .. string.gsub(escaped_word, "\n", "\\n")
  vim.fn.setreg('/', literal_pattern)
  vim.cmd('set hlsearch')

  local success, err = pcall(function()
    vim.cmd('normal! n')
  end)

  if not success then
    print("Pattern not found: " .. word)
    vim.cmd('nohlsearch')
  end
end, { noremap = true, silent = false })
"@

    # Write to init.lua
    $initLuaContent | Set-Content -Path $NVIM_CONFIG_FILE -Encoding UTF8

    Write-Host "Cleaning up downloaded MSI..."
    Remove-Item -Path $localFile -Force

    Write-Host "Neovim installed successfully and init.lua configuration written to $NVIM_CONFIG_FILE."
}
catch {
    Write-Error "Error: $($_.Exception.Message)"
    exit 1
}
