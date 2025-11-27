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
    export derivedData=${OPTARG}
    ;;
  esac
done

# Change Directory
if [ "$directory" != "." ]; then
  echo "Changing directory to '$directory'."
  cd $directory
fi

# Identify `Package.resolved` location
RESOLVED_PATH=$(find . -type f -name "Package.resolved" -path "*/*.xcodeproj/*")

CHECKSUM=$(shasum "$RESOLVED_PATH")
echo "Identified Package.resolved at '$RESOLVED_PATH'."
echo "Checksum: $CHECKSUM."

# Define Xcodebuild Inputs
xcodebuildInputs="-scheme $scheme -derivedDataPath $derivedData"

# If `forceResolution`, then delete the `Package.resolved`
if [ "$forceResolution" = true ] || [ "$forceResolution" = 'true' ]; then
  echo "Deleting Package.resolved to force it to be regenerated under new format."
  rm -rf "$RESOLVED_PATH" 2>/dev/null
fi

# Should be mostly redundant as we use the disable cache flag.
SPM_CACHE="~/Library/Caches/org.swift.swiftpm/"
rm -rf "$SPM_CACHE"

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
