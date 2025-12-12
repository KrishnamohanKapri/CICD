#!/bin/bash
# Component Detection Script
# Maps changed file paths to component names

set -e

# #region agent log
# Determine log file path based on environment
if [ -n "$GITHUB_WORKSPACE" ]; then
    # GitHub Actions environment
    LOG_FILE="${GITHUB_WORKSPACE}/.cursor/debug.log"
else
    # Local environment
    LOG_FILE="/home/krish/Projects/MDE4CPP_CICD/.cursor/debug.log"
fi

# Ensure log directory exists
LOG_DIR=$(dirname "$LOG_FILE")
mkdir -p "$LOG_DIR" 2>/dev/null || true

log_debug() {
    # Silently fail if log file cannot be written (e.g., in CI without write permissions)
    echo "{\"timestamp\":$(date +%s000),\"location\":\"detect-components.sh:$1\",\"message\":\"$2\",\"data\":$3,\"sessionId\":\"debug-session\",\"runId\":\"run1\",\"hypothesisId\":\"$4\"}" >> "$LOG_FILE" 2>/dev/null || true
}
# #endregion agent log

# Get changed files from git diff
if [ -n "$GITHUB_BASE_REF" ]; then
    # PR: compare against base branch
    BASE_REF="${GITHUB_BASE_REF}"
    
    # #region agent log
    log_debug "8" "PR mode detected" "{\"GITHUB_BASE_REF\":\"$GITHUB_BASE_REF\",\"GITHUB_HEAD_REF\":\"$GITHUB_HEAD_REF\",\"GITHUB_SHA\":\"$GITHUB_SHA\"}" "A"
    # #endregion agent log
    
    # Fetch the base branch first to ensure it's available
    git fetch origin "${BASE_REF}:refs/remotes/origin/${BASE_REF}" 2>/dev/null || \
    git fetch origin "${BASE_REF}" 2>/dev/null || true
    
    # #region agent log
    CURRENT_HEAD=$(git rev-parse HEAD 2>/dev/null || echo "unknown")
    BASE_COMMIT=$(git rev-parse "origin/${BASE_REF}" 2>/dev/null || echo "unknown")
    log_debug "16" "After fetch" "{\"CURRENT_HEAD\":\"$CURRENT_HEAD\",\"BASE_COMMIT\":\"$BASE_COMMIT\"}" "A"
    # #endregion agent log
    
    # In GitHub Actions PR checkout, HEAD is the merge commit
    # Compare base branch to HEAD (merge commit) - this shows what changed in the PR
    CHANGED_FILES=$(git diff --name-only "origin/${BASE_REF}" HEAD 2>/dev/null || \
                    git diff --name-only "${BASE_REF}" HEAD 2>/dev/null || \
                    echo "")
    
    # #region agent log
    CHANGED_COUNT=$(echo "$CHANGED_FILES" | grep -c . || echo "0")
    log_debug "22" "Git diff result" "{\"changed_files_count\":$CHANGED_COUNT,\"changed_files\":\"$(echo "$CHANGED_FILES" | head -5 | tr '\n' ';')\"}" "A"
    # #endregion agent log
else
    # Push: compare against previous commit
    CHANGED_FILES=$(git diff --name-only HEAD~1 HEAD)
    
    # #region agent log
    log_debug "26" "Push mode" "{\"changed_files\":\"$(echo "$CHANGED_FILES" | head -5 | tr '\n' ';')\"}" "B"
    # #endregion agent log
fi

# If no changes, exit
if [ -z "$CHANGED_FILES" ]; then
    # #region agent log
    log_debug "29" "No changed files found" "{}" "C"
    # #endregion agent log
    echo ""
    exit 0
fi

# Component mapping: path pattern -> component name
declare -A COMPONENT_MAP

# Infrastructure
COMPONENT_MAP["src/common/abstractDataTypes"]="abstract-data-types"
COMPONENT_MAP["src/util"]="util"
COMPONENT_MAP["src/common/pluginFramework"]="plugin-framework"
COMPONENT_MAP["src/common/persistence"]="persistence"

# Generators
COMPONENT_MAP["generator/ecore4CPP"]="ecore4cpp-generator"
COMPONENT_MAP["generator/UML4CPP"]="uml4cpp-generator"
COMPONENT_MAP["generator/fUML4CPP"]="fuml4cpp-generator"

# Core Models
COMPONENT_MAP["src/ecore"]="ecore"
COMPONENT_MAP["src/uml/types"]="types"
COMPONENT_MAP["src/uml/uml"]="uml"
COMPONENT_MAP["src/fuml"]="fuml"
COMPONENT_MAP["src/pscs"]="pscs"
COMPONENT_MAP["src/pssm"]="pssm"

# OCL
COMPONENT_MAP["src/ocl/oclModel"]="ocl-model"
COMPONENT_MAP["src/ocl/oclParser"]="ocl-parser"

# Reflection
COMPONENT_MAP["src/common/ecoreReflection"]="ecore-reflection"
COMPONENT_MAP["src/common/primitivetypesReflection"]="primitivetypes-reflection"
COMPONENT_MAP["src/common/umlReflection"]="uml-reflection"

# Profiles
COMPONENT_MAP["src/common/standardProfile"]="standard-profile"
COMPONENT_MAP["src/common/UML4CPPProfile"]="uml4cpp-profile"

# Application
COMPONENT_MAP["src/common/FoundationalModelLibrary"]="foundational-model-library"

# Gradle Plugins (affects all components)
COMPONENT_MAP["gradlePlugins"]="all"

# Docker (affects all components)
COMPONENT_MAP["docker"]="all"

# Track detected components
declare -A DETECTED_COMPONENTS

# Process each changed file
FILE_COUNT=0
MATCHED_COUNT=0
while IFS= read -r file; do
    [ -z "$file" ] && continue
    FILE_COUNT=$((FILE_COUNT + 1))
    
    # #region agent log
    log_debug "82" "Processing file" "{\"file\":\"$file\",\"file_number\":$FILE_COUNT}" "D"
    # #endregion agent log
    
    # Skip generated files and build artifacts
    if [[ "$file" == *"/src_gen/"* ]] || \
       [[ "$file" == *"/build/"* ]] || \
       [[ "$file" == *"/.cmake/"* ]] || \
       [[ "$file" == *"/application/"* ]] || \
       [[ "$file" == "*.dll" ]] || \
       [[ "$file" == "*.jar" ]] || \
       [[ "$file" == "*.a" ]]; then
        # #region agent log
        log_debug "91" "File skipped" "{\"file\":\"$file\",\"reason\":\"generated_or_build_artifact\"}" "D"
        # #endregion agent log
        continue
    fi
    
    # Check each path pattern
    MATCHED=false
    for path_pattern in "${!COMPONENT_MAP[@]}"; do
        if [[ "$file" == "$path_pattern"* ]]; then
            component="${COMPONENT_MAP[$path_pattern]}"
            MATCHED=true
            MATCHED_COUNT=$((MATCHED_COUNT + 1))
            
            # #region agent log
            log_debug "96" "File matched pattern" "{\"file\":\"$file\",\"pattern\":\"$path_pattern\",\"component\":\"$component\"}" "D"
            # #endregion agent log
            
            # Special handling for "all" components
            if [ "$component" = "all" ]; then
                # Return all components
                echo "abstract-data-types util plugin-framework persistence ecore4cpp-generator uml4cpp-generator fuml4cpp-generator ecore types uml fuml pscs pssm ocl-model ocl-parser ecore-reflection primitivetypes-reflection uml-reflection standard-profile uml4cpp-profile foundational-model-library"
                exit 0
            fi
            
            DETECTED_COMPONENTS["$component"]=1
            break
        fi
    done
    
    # #region agent log
    if [ "$MATCHED" = "false" ]; then
        log_debug "109" "File did not match any pattern" "{\"file\":\"$file\"}" "D"
    fi
    # #endregion agent log
done <<< "$CHANGED_FILES"

# #region agent log
log_debug "113" "Component detection summary" "{\"total_files\":$FILE_COUNT,\"matched_files\":$MATCHED_COUNT,\"detected_components_count\":${#DETECTED_COMPONENTS[@]}}" "E"
# #endregion agent log

# Output unique components
if [ ${#DETECTED_COMPONENTS[@]} -eq 0 ]; then
    echo ""
else
    # Sort components for consistent output
    printf '%s\n' "${!DETECTED_COMPONENTS[@]}" | sort | tr '\n' ' ' | sed 's/ $//'
fi

