#!/bin/bash
set -e

# Load Options
while getopts "a:b:c:d:e:f:g:" o; do
  case "${o}" in
  a)
    export directory=${OPTARG}
    ;;
  b)
    export forceResolution=${OPTARG}
    ;;
  c)
    export failWhenOutdated=${OPTARG}
    ;;
  d)
    if [ ! -z "${OPTARG}" ]; then
      export DEVELOPER_DIR="${OPTARG}"
    fi
    ;;
  e)
    export workspaceName=${OPTARG}
    ;;
  f)
    export scheme=${OPTARG}
    ;;
  g)
    export projectName=${OPTARG}
    ;;
  esac
done

# Input Validation
if [ ! -z "$workspaceName" ] && [ -z "$scheme" ]; then
  echo "::error::Your action specifies a workspace name but does not define a scheme. You must provide both when using the workspace option."
  exit 1
fi

# Change Directory
if [ "$directory" != "." ]; then
  echo "Changing directory to '$directory'."
  cd $directory
fi

# Identify `Package.resolved` location
if [ ! -z "$workspaceName" ]; then
  RESOLVED_PATH=$(find $workspaceName -type f -name "Package.resolved" | grep -v "*/*.xcworkspace/*")
else
  RESOLVED_PATH=$(find . -type f -name "Package.resolved" -path "*/*.xcodeproj/*")
fi

CHECKSUM=$(shasum "$RESOLVED_PATH")
echo "Identified Package.resolved at '$RESOLVED_PATH'."
echo "Checksum: $CHECKSUM."

# Define Xcodebuild Inputs
if [ ! -z "$workspaceName" ]; then
  xcodebuildInputs="-workspace $workspaceName -scheme $scheme"
else
  xcodebuildInputs=""
fi

# Default DerivedData path
DERIVED_DATA_DIR=~/Library/Developer/Xcode/DerivedData

if [ -z "$projectName" ]; then
    echo "🔍 Scanning for recent derived data folders..."
    echo "Tip: Pass your project/workspace name to narrow results."
    
    # List most recently modified folders
    ls -lt "$DERIVED_DATA_DIR" | head -10
else
    echo "🔍 Looking for DerivedData folder matching: $projectName"
    
    MATCH=$(find "$DERIVED_DATA_DIR" -maxdepth 1 -type d -name "${projectName}-*" | head -n 1)
    
    if [ -n "$MATCH" ]; then
        echo "✅ Found DerivedData folder:"
        echo "$MATCH"
    else
        echo "❌ No DerivedData folder found matching: $projectName"
    fi
fi

# If `forceResolution`, then delete the `Package.resolved`
if [ "$forceResolution" = true ] || [ "$forceResolution" = 'true' ]; then
  echo "Deleting Package.resolved to force it to be regenerated under new format."
  rm -rf "$RESOLVED_PATH" 2>/dev/null
fi

# Should be mostly redundant as we use the disable cache flag.
SPM_CACHE="~/Library/Caches/org.swift.swiftpm/"
rm -rf "$CACHE_PATH"

# Resolve Dependencies
echo "::group::xcodebuild resolve dependencies"
xcodebuild ${xcodebuildInputs} -resolvePackageDependencies -disablePackageRepositoryCache
echo "::endgroup"

# Determine Changes
NEWCHECKSUM=$(shasum "$RESOLVED_PATH")

if [ "$CHECKSUM" != "$NEWCHECKSUM" ]; then
  echo "dependenciesChanged=true" >> $GITHUB_OUTPUT

  if [ "$failWhenOutdated" = true ] || [ "$failWhenOutdated" = 'true' ]; then
    exit 1
  fi
else
  echo "dependenciesChanged=false" >> $GITHUB_OUTPUT
fi
