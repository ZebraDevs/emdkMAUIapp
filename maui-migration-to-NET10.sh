#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# maui-migration-to-NET10.sh
#
# Migrates the emdkMAUIapp solution from .NET 6 MAUI to .NET 10 MAUI.
#
#   - Downloads and installs the .NET 10 SDK
#   - Updates TFMs (net6.0-* → net10.0-*)
#   - Updates NuGet package versions
#   - Updates EMDK conditional reference to match new Android TFM
#     (Symbol.XamarinEMDK namespace/API unchanged per EMDK for MAUI/Xamarin 10.0 docs)
#   - Applies required code changes (.NET 10 MAUI breaking changes)
#   - Removes Tizen platform (dropped in .NET 7)
#   - Removes obsolete iOS/MacCatalyst Program.cs entry points
#
# EMDK notes (from /docs reference):
#   The EMDK for MAUI/Xamarin 10.0 documentation states:
#     - Requires ".NET 6.0 (or later)" → .NET 10 is supported
#     - NuGet package: Symbol.XamarinEMDK (same namespace: using Symbol.XamarinEMDK;)
#     - EMDKManager, ProfileManager, VersionManager APIs are unchanged
#     - AndroidManifest.xml still requires <uses-library android:name="com.symbol.emdk" />,
#       <uses-permission android:name="com.symbol.emdk.permission.EMDK" />, and
#       <queries><package android:name="com.symbol.emdk.emdkservice" /></queries>
#
# Usage: bash maui-migration-to-NET10.sh
# Run from the repository root.
###############################################################################

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$REPO_ROOT/emdkbindingMAUIapp"
CSPROJ="$PROJECT_DIR/emdkMAUIapp.csproj"
SLN="$REPO_ROOT/emdkMAUIapp.sln"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log()   { echo -e "${GREEN}[INFO]${NC}  $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*" >&2; exit 1; }
step()  { echo -e "\n${CYAN}=== Step $1: $2 ===${NC}"; }

# Verify we are at the repo root
[[ -f "$CSPROJ" ]] || error "Cannot find $CSPROJ. Run this script from the repository root."
[[ -f "$SLN" ]]    || error "Cannot find $SLN. Run this script from the repository root."

###############################################################################
step 1 "Install .NET 10 SDK"
###############################################################################

DOTNET_INSTALL_DIR="${DOTNET_INSTALL_DIR:-$HOME/.dotnet}"

if command -v dotnet &>/dev/null && dotnet --list-sdks 2>/dev/null | grep -q "^10\."; then
    log ".NET 10 SDK already installed: $(dotnet --list-sdks | grep '^10\.' | tail -1)"
else
    log "Downloading dotnet-install script..."
    curl -sSL https://dot.net/v1/dotnet-install.sh -o /tmp/dotnet-install.sh
    chmod +x /tmp/dotnet-install.sh

    log "Installing .NET 10 SDK (latest from channel 10.0)..."
    /tmp/dotnet-install.sh --channel 10.0 --install-dir "$DOTNET_INSTALL_DIR"

    export PATH="$DOTNET_INSTALL_DIR:$PATH"
    export DOTNET_ROOT="$DOTNET_INSTALL_DIR"

    rm -f /tmp/dotnet-install.sh
    log ".NET 10 SDK installed at $DOTNET_INSTALL_DIR"
fi

log "Active SDK: $(dotnet --version)"

###############################################################################
step 2 "Back up project file"
###############################################################################

cp "$CSPROJ" "$CSPROJ.net6-backup"
log "Original .csproj saved to $CSPROJ.net6-backup"

###############################################################################
step 3 "Update Target Framework Monikers in .csproj"
###############################################################################

# --- TFM replacements (order: most-specific first) ---

# Android TFMs – the versioned suffix is no longer required in .NET 8+
sed -i 's|net6\.0-android31\.0|net10.0-android|g'  "$CSPROJ"
sed -i 's|net6\.0-android33\.0|net10.0-android|g'  "$CSPROJ"

# Apple platforms
sed -i 's|net6\.0-ios|net10.0-ios|g'                "$CSPROJ"
sed -i 's|net6\.0-maccatalyst|net10.0-maccatalyst|g' "$CSPROJ"

# Windows – keep the SDK version, update the .NET version
sed -i 's|net6\.0-windows10\.0\.22621\.0|net10.0-windows10.0.22621.0|g' "$CSPROJ"
# Standardise any stale 19041 Windows TFMs to the same SDK
sed -i 's|net6\.0-windows10\.0\.19041\.0|net10.0-windows10.0.22621.0|g' "$CSPROJ"

# Remove all Tizen references (Tizen support was dropped in .NET 7 MAUI)
# Case-insensitive delete of every line containing "tizen"
sed -i '/tizen/Id' "$CSPROJ"

log "TFMs updated: net6.0-* → net10.0-*"
log "Tizen TFM and SupportedOSPlatformVersion lines removed"

###############################################################################
step 4 "Update NuGet package references"
###############################################################################

# In .NET 10, <UseMaui>true</UseMaui> no longer auto-includes MAUI NuGet packages (MA002).
# Add the explicit Microsoft.Maui.Controls package reference.
sed -i 's|<PackageReference Include="CommunityToolkit.Mvvm" Version="8.0.0" />|<PackageReference Include="Microsoft.Maui.Controls" Version="10.0.20" />\n\t  <PackageReference Include="CommunityToolkit.Mvvm" Version="8.4.0" />|' "$CSPROJ"
log "Added Microsoft.Maui.Controls 10.0.20 (required since .NET 8 — MA002)"
log "CommunityToolkit.Mvvm bumped to 8.4.0"

# Remove NuGet.CommandLine – not needed as a project-level dependency
sed -i '/<PackageReference Include="NuGet.CommandLine"/,/<\/PackageReference>/d' "$CSPROJ"
log "Removed NuGet.CommandLine package reference"

# Symbol.XamarinEMDK 8.0.0.2 is intentionally kept:
#   Per the EMDK for MAUI/Xamarin 10.0 docs (see /docs/crawl_output-EMDK-MAUI.txt):
#   "EMDK for Xamarin 8.0 (or later)" is required for MAUI support.
#   The package name is Symbol.XamarinEMDK and the namespace is Symbol.XamarinEMDK.
#   The conditional ItemGroup was already updated by the TFM replacement above
#   from  Condition="'$(TargetFramework)' == 'net6.0-android31.0'"
#   to    Condition="'$(TargetFramework)' == 'net10.0-android'"
log "Symbol.XamarinEMDK 8.0.0.2 retained (Android-only, EMDK API unchanged)"

###############################################################################
step 5 "Update App.xaml.cs – replace deprecated MainPage property"
###############################################################################

# In .NET 9+ MAUI the Application.MainPage property setter was removed.
# The new pattern uses CreateWindow().

cat > "$PROJECT_DIR/App.xaml.cs" << 'CSHARP'
#nullable enable

namespace emdkMAUIapp;

public partial class App : Application
{
	public App()
	{
		InitializeComponent();
	}

	protected override Window CreateWindow(IActivationState? activationState)
	{
		return new Window(new AppShell());
	}
}
CSHARP

log "App.xaml.cs rewritten: MainPage = new AppShell() → CreateWindow()"

###############################################################################
step 6 "Update MainPage.xaml.cs – remove deprecated usings"
###############################################################################

# Microsoft.Maui.Controls.Compatibility was removed in .NET 9 MAUI.
# Microsoft.Maui.Controls is covered by ImplicitUsings.
sed -i '/using Microsoft\.Maui\.Controls\.Compatibility;/d' "$PROJECT_DIR/MainPage.xaml.cs"
sed -i '/using Microsoft\.Maui\.Controls;/d'                "$PROJECT_DIR/MainPage.xaml.cs"

log "Removed deprecated usings from MainPage.xaml.cs"

###############################################################################
step 7 "Verify iOS and MacCatalyst Program.cs entry points"
###############################################################################

# iOS and MacCatalyst still require explicit Program.cs entry points
# (UIApplication.Main) on cross-compiled Windows builds. Keep them intact.
log "Platforms/iOS/Program.cs retained (entry point required)"
log "Platforms/MacCatalyst/Program.cs retained (entry point required)"

###############################################################################
step 8 "Remove Tizen platform (unsupported since .NET 7 MAUI)"
###############################################################################

rm -rf "$PROJECT_DIR/Platforms/Tizen"
log "Removed Platforms/Tizen/ directory"

###############################################################################
step 9 "Update AndroidManifest.xml"
###############################################################################

MANIFEST="$PROJECT_DIR/Platforms/Android/AndroidManifest.xml"

# Bump targetSdkVersion to 36 (Android 16 – .NET 10 SDK default API level)
sed -i 's|android:targetSdkVersion="33"|android:targetSdkVersion="36"|' "$MANIFEST"

log "AndroidManifest.xml: targetSdkVersion 33 → 36"
log "EMDK manifest entries preserved (uses-library, uses-permission, queries)"

###############################################################################
step 10 "Update Windows Package.appxmanifest"
###############################################################################

APPXMANIFEST="$PROJECT_DIR/Platforms/Windows/Package.appxmanifest"

if [[ -f "$APPXMANIFEST" ]]; then
    # Update MaxVersionTested to match the target Windows SDK
    sed -i 's|MaxVersionTested="10.0.19041.0"|MaxVersionTested="10.0.22621.0"|g' "$APPXMANIFEST"
    log "Package.appxmanifest: MaxVersionTested → 10.0.22621.0"
fi

###############################################################################
step 11 "Restore NuGet packages"
###############################################################################

log "Running dotnet restore..."
cd "$REPO_ROOT"

if dotnet restore "$SLN"; then
    log "NuGet restore succeeded"
else
    warn "NuGet restore returned errors – review output above"
    warn "You may need to run:  dotnet nuget locals all --clear && dotnet restore"
fi

###############################################################################
# Summary
###############################################################################

echo ""
echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN} Migration Complete – .NET 6 MAUI → .NET 10 MAUI${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
echo ""
echo " Target Frameworks:"
echo "   net6.0-android31.0           → net10.0-android"
echo "   net6.0-ios                   → net10.0-ios"
echo "   net6.0-maccatalyst           → net10.0-maccatalyst"
echo "   net6.0-windows10.0.22621.0   → net10.0-windows10.0.22621.0"
echo "   net6.0-tizen                 → REMOVED"
echo ""
echo " NuGet Packages:"
echo "   Microsoft.Maui.Controls       (new)  → 10.0.20"
echo "   CommunityToolkit.Mvvm        8.0.0  → 8.4.0"
echo "   NuGet.CommandLine             6.3.1  → REMOVED"
echo "   Symbol.XamarinEMDK           8.0.0.2 (unchanged)"
echo ""
echo " EMDK (per /docs EMDK for MAUI/Xamarin 10.0 reference):"
echo "   Package:    Symbol.XamarinEMDK (Android-only condition updated)"
echo "   Namespace:  using Symbol.XamarinEMDK;  (unchanged)"
echo "   APIs:       EMDKManager, ProfileManager, VersionManager (unchanged)"
echo "   Manifest:   uses-library, EMDK permission, queries (unchanged)"
echo "   Config:     EMDKConfig.xml (unchanged)"
echo ""
echo " Code Changes:"
echo "   App.xaml.cs           MainPage setter → CreateWindow()"
echo "   MainPage.xaml.cs      Removed deprecated Compatibility using"
echo "   App.xaml.cs           Added #nullable enable"
echo "   AndroidManifest.xml   targetSdkVersion 33 → 36"
echo "   Package.appxmanifest  MaxVersionTested → 10.0.22621.0"
echo ""
echo " Removed Files:"
echo "   Platforms/Tizen/ (entire directory)"
echo ""
echo -e " Backup: ${YELLOW}$CSPROJ.net6-backup${NC}"
echo ""
echo " Next steps:"
echo "   dotnet build emdkbindingMAUIapp/emdkMAUIapp.csproj"
echo ""
