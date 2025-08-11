/**
 * Jenkins Pipeline for Template Registration
 *
 * This pipeline automatically detects and registers NEW template versions ONLY
 * when changes are pushed to specific branches.
 *
 * IMPORTANT RULES:
 * 1. Git diff scope: Only processes the last commit that was pushed to the branch
 * 2. Version processing: ONLY processes NEW versions (like v3 being added)
 *    - Ignores changes to existing versions (like v2 being modified)
 *    - Ignores deletions of existing versions
 *    - Only calls webhook for truly NEW template versions
 *
 * Usage:
 * - on_change to: develop, { register_templates dev }
 *
 * Parameters:
 * - app_env: Environment configuration (dev, staging, prod)
 *
 * The pipeline will:
 * 1. Detect NEW template files from git diff (only added files with ^A status)
 * 2. Fall back to git show if git diff fails (handles shallow clones)
 * 3. Only register NEW template versions with the document service
 * 4. Provide detailed debugging information if no NEW templates are found
 *
 * Example scenarios:
 * - v3.tsx added -> Will process and register v3
 * - v2.tsx modified -> Will NOT process (ignored)
 * - v1.tsx deleted -> Will NOT process (ignored)
 * - v2.tsx content changed -> Will NOT process (ignored)
 */

on_change to: develop, {
  // Only registers NEW template versions (ignores changes to existing versions)
  register_templates dev
}

on_change to: main, {
  register_templates staging
}

on_change to: production, {
  register_templates prod
}

/**
 * Main entrypoint for the template registration pipeline.
 */
void register_templates(app_env) {
  node {
    stage("Register Templates - ${app_env.short_name}") {
      script {
        echo """=== Template Registration for ${app_env.short_name.toUpperCase()} ==="
         \n"Document Service URL: ${app_env.document_service_url}"
         \n"Processing: NEW template versions ONLY (ignores changes to existing versions)"""

        // Get git diff to find NEW template files (last commit only)
        def gitDiffOutput = getNewTemplateFilesFromGit()
        if (!gitDiffOutput) {
          printNoTemplatesFoundMessage()
          echo "No NEW template versions to register. Exiting."
          return
        }

        printNewTemplateFiles(gitDiffOutput)
        def templatesToRegister = extractTemplatesFromGitDiff(gitDiffOutput)
        if (templatesToRegister.isEmpty()) {
          echo "No NEW templates to register after parsing."
          return
        }

        printTemplatesToRegister(templatesToRegister)
        def gitMeta = getGitMetadata()
        printGitMetadata(gitMeta)
        registerTemplates(templatesToRegister, gitMeta, app_env)
        echo "=== Template Registration for ${app_env.short_name.toUpperCase()} Completed ==="
      }
    }
  }
}

/**
 * Gets new template files from git diff (last commit only).
 * Only processes NEW versions, ignores changes to existing versions.
 * @return String with file paths, one per line.
 */
String getNewTemplateFilesFromGit() {
  echo "Getting git diff to find NEW template versions (last commit only)..."

  // First, check if we have enough git history
  def gitDepth = sh(script: "git rev-list --count HEAD", returnStdout: true).trim().toInteger()
  echo "Git depth: ${gitDepth} commits"

  if (gitDepth <= 1) {
    echo "Shallow clone or single commit detected. Using git show approach..."
    return getNewTemplateFilesFromGitShow()
  }

  // Try git diff approach first - ONLY process added files (^A), ignore modifications (^M) and deletions (^D)
  try {
    echo "Attempting git diff HEAD~1 HEAD (only NEW files)..."
    def result = sh(
      script: """
        git diff HEAD~1 HEAD --name-status |
        grep '^A' |
        grep 'src/templates/.*/v[0-9]*.tsx' |
        awk '{print \$2}'
      """,
      returnStdout: true
    ).trim()

    if (result) {
      echo "Git diff approach successful - found NEW template versions"
      return result
    } else {
      echo "Git diff found no NEW template versions, trying git show approach..."
      return getNewTemplateFilesFromGitShow()
    }
  } catch (Exception e) {
    echo "Git diff failed: ${e.message}"
    echo "Falling back to git show approach..."
    return getNewTemplateFilesFromGitShow()
  }
}

/**
 * Gets new template files using git show (works with shallow clones).
 * Only processes NEW versions, ignores changes to existing versions.
 * @return String with file paths, one per line.
 */
String getNewTemplateFilesFromGitShow() {
  try {
    echo "Using git show to find NEW template versions..."
    return sh(
      script: """
        git show --name-status --pretty=format: HEAD |
        grep '^A' |
        grep 'src/templates/.*/v[0-9]*.tsx' |
        awk '{print \$2}'
      """,
      returnStdout: true
    ).trim()
  } catch (Exception e) {
    echo "Git show approach also failed: ${e.message}"
    echo "Note: This approach only works for NEW files, not changes to existing versions"
    return ""
  }
}

/**
 * Prints a message when no new templates are found.
 */
void printNoTemplatesFoundMessage() {
  echo """No NEW template versions detected in git diff.
        This might be because:
        1. No NEW .tsx files were added (only existing ones were modified/deleted)
        2. This is the first commit or shallow clone
        3. Files don't match the pattern src/templates/*/v[0-9]*.tsx
        4. Git history is limited

        REMEMBER: This pipeline only processes NEW versions, not changes to existing ones.
        - v3.tsx added -> Will process and register v3
        - v2.tsx modified -> Will NOT process (ignored)
        - v1.tsx deleted -> Will NOT process (ignored)"""

  // Add debugging information
  debugGitAndWorkingDirectory()
}

/**
 * Debugs git state and working directory for troubleshooting.
 */
void debugGitAndWorkingDirectory() {
  echo "=== Debug Information ==="

  try {
    echo "Current working directory:"
    sh "pwd && ls -la"

    echo "Git status:"
    sh "git status --porcelain"

    echo "Git log (last 3 commits):"
    sh "git log --oneline -3"

    echo "Git depth:"
    sh "git rev-list --count HEAD"

    echo "Template directory contents:"
    sh "find src/templates -type f 2>/dev/null || echo 'src/templates directory not found'"

    echo "Git diff status for last commit (showing what changed):"
    if (sh(script: "git rev-list --count HEAD", returnStdout: true).trim().toInteger() > 1) {
      sh "git diff HEAD~1 HEAD --name-status | grep 'src/templates' || echo 'No template files changed in last commit'"
    } else {
      echo "Single commit - no diff available"
    }

    echo "All .tsx files in project:"
    sh "find . -name '*.tsx' -type f 2>/dev/null || echo 'No .tsx files found'"

  } catch (Exception e) {
    echo "Debug commands failed: ${e.message}"
  }
}

/**
 * Prints the new template files detected.
 * @param gitDiffOutput String with file paths.
 */
void printNewTemplateFiles(String gitDiffOutput) {
  echo "New template files detected:"
  echo gitDiffOutput
}

/**
 * Extracts template information from git diff output.
 * @param gitDiffOutput String with file paths.
 * @return List of template maps.
 */
List extractTemplatesFromGitDiff(String gitDiffOutput) {
  echo "=== Parsing Git Diff Output ==="
  def templates = [:]
  def lines = gitDiffOutput.split('\n')
  lines.each { line ->
    if (line.trim().isEmpty()) return
    processGitDiffLine(line, templates)
  }
  return templates.values().toList()
}

/**
 * Processes a single line from git diff and updates the templates map.
 * @param line String file path.
 * @param templates Map of templateCode -> template info.
 */
void processGitDiffLine(String line, Map templates) {
  echo "Processing line: ${line}"
  def matcher = line =~ /src\/templates\/([^\/]+)\/v(\d+)\.tsx$/
  if (matcher.find()) {
    def templateCode = matcher.group(1)
    def version = "v${matcher.group(2)}"
    echo "Found template: code='${templateCode}', version='${version}', file='${line}'"
    updateTemplateIfHighestVersion(templates, templateCode, version, line)
  } else {
    echo "  -> Line doesn't match template pattern, skipping"
  }
}

/**
 * Updates the templates map if the version is the highest seen so far.
 */
void updateTemplateIfHighestVersion(Map templates, String templateCode, String version, String filePath) {
  if (!templates[templateCode] || compareVersions(version, templates[templateCode].version) > 0) {
    templates[templateCode] = [
      code: templateCode,
      version: version,
      filePath: filePath
    ]
    echo "  -> Set as highest version for '${templateCode}': ${version}"
  } else {
    echo "  -> Skipping '${version}' (current highest for '${templateCode}': '${templates[templateCode].version}')"
  }
}

/**
 * Prints the templates that will be registered.
 */
void printTemplatesToRegister(List templatesToRegister) {
  echo "Templates to register after parsing:"
  templatesToRegister.each { template ->
    echo "- ${template.code}:${template.version} (from ${template.filePath})"
  }
}

/**
 * Gets git metadata for the current commit.
 * @return Map with hash, message, timestamp.
 */
Map getGitMetadata() {
  [
    hash: sh(script: "git rev-parse HEAD", returnStdout: true).trim(),
    message: sh(script: "git log -1 --pretty=%B", returnStdout: true).trim(),
    timestamp: sh(script: "git log -1 --pretty=%cI", returnStdout: true).trim()
  ]
}

/**
 * Prints git metadata.
 */
void printGitMetadata(Map gitMeta) {
  echo "=== Git Metadata ==="
  echo "Hash: ${gitMeta.hash}"
  echo "Message: ${gitMeta.message}"
  echo "Timestamp: ${gitMeta.timestamp}"
}

/**
 * Registers all templates with the document service.
 */
void registerTemplates(List templatesToRegister, Map gitMeta, app_env) {
  templatesToRegister.each { template ->
    registerTemplateWithDocumentService(template, gitMeta, app_env)
  }
}

/**
 * Registers a single template with the document service.
 * @param template Map with template info.
 * @param gitMeta Map with git metadata.
 * @param app_env Environment configuration.
 */
void registerTemplateWithDocumentService(Map template, Map gitMeta, app_env) {
  echo "=== Registering Template: ${template.code}:${template.version} with ${app_env.short_name.toUpperCase()} ==="
  try {
    def payload = buildDocumentServicePayload(template, gitMeta, app_env)
    def jsonPayload = groovy.json.JsonOutput.toJson(payload)
    echo "Sending payload to ${app_env.document_service_url}/webhooks/backoffice/v1/templates"
    echo "Payload: ${jsonPayload}"

    def response = sendDocumentServiceRequest(jsonPayload, app_env)
    printDocumentServiceResponse(response)
  } catch (Exception e) {
    echo "Registration failed for ${template.code}:${template.version}"
    echo "Error: ${e.message}"
    echo "This will not fail the build, marking as unstable"
    currentBuild.result = 'UNSTABLE'
  }
}

/**
 * Builds the payload for the document service registration.
 */
Map buildDocumentServicePayload(Map template, Map gitMeta, app_env) {
  [
    code: template.code,
    version: template.version,
    git: [
      repo: "arturbdr/templates-test-repo",
      commit: [
        hash: gitMeta.hash,
        message: gitMeta.message,
        timestamp: gitMeta.timestamp
      ]
    ]
  ]
}

/**
 * Sends the HTTP request to the document service using Jenkins HTTP Request plugin.
 * @param jsonPayload String JSON payload.
 * @param app_env Environment configuration.
 * @return Response object.
 */
def sendDocumentServiceRequest(String jsonPayload, app_env) {
  httpRequest(
    httpMode: 'POST',
    url: "${app_env.document_service_url}/webhooks/backoffice/v1/templates",
    contentType: 'APPLICATION_JSON',
    requestBody: jsonPayload,
    validResponseCodes: '201',
    timeout: 30,
    ignoreSslErrors: true
  )
}

/**
 * Prints the response from the document service and attempts to extract the templateId.
 */
void printDocumentServiceResponse(def response) {
  echo "Registration successful!"
  echo "HTTP Status: ${response.status}"
  echo "Response Body: ${response.content}"
  try {
    def responseData = new groovy.json.JsonSlurper().parseText(response.content)
    echo "Template ID: ${responseData.templateId}"
  } catch (Exception e) {
    echo "Note: Could not parse templateId from response: ${e.message}"
  }
}

/**
 * Compares two version strings (e.g., v1, v2).
 * @return int: 1 if version1 > version2, -1 if version1 < version2, 0 if equal.
 */
int compareVersions(String version1, String version2) {
  def v1 = version1.replace('v', '').toInteger()
  def v2 = version2.replace('v', '').toInteger()
  return v1 <=> v2
}
