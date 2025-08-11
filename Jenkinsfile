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
 * Parameters:
 * - app_env: Environment configuration (dev, staging, prod)
 *
 * The pipeline will:
 * 1. Detect NEW template files
 * 2. Only register NEW template versions with the document service
 *
 * Example scenarios:
 * - v3.tsx added -> Will process and register v3
 * - v2.tsx modified -> Will NOT process (ignored)
 * - v1.tsx deleted -> Will NOT process (ignored)
 * - v2.tsx content changed -> Will NOT process (ignored)
 */

on_change to: develop, {
  // Only registers NEW template versions (ignores changes to existing versions)
  withChecks('Template Registration') {
    register_templates dev
  }
}

on_change to: main, {
  withChecks('Template Registration') {
    register_templates staging
  }
}

on_change to: production, {
  withChecks('Template Registration') {
    register_templates prod
  }
}

/**
 * Main entrypoint for the template registration pipeline.
 */
void register_templates(app_env) {
  node {
    stage("Register Templates - ${app_env.short_name}") {
      script {
        // Ensure we're in the right directory and git repository is available
        checkout scm

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

  try {
    echo "Using git diff HEAD~1 HEAD to find NEW template versions..."
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
      echo "Git diff successful - found NEW template versions"
      return result
    } else {
      echo "No NEW template versions found in git diff"
      return ""
    }
  } catch (Exception e) {
    echo "Git diff failed: ${e.message}"
    echo "This might indicate a shallow clone or single commit"
    return ""
  }
}

void printNoTemplatesFoundMessage() {
  echo """No NEW template versions detected in git diff.
        This might be because:
        1. No NEW .tsx files were added (only existing ones were modified/deleted)
        2. This is the first commit or shallow clone
        3. Files don't match the pattern src/templates/.*/v[0-9]*.tsx

        REMEMBER: This pipeline only processes NEW versions, not changes to existing ones.
        - v3.tsx added -> Will process and register v3
        - v2.tsx modified -> Will NOT process (ignored)
        - v1.tsx deleted -> Will NOT process (ignored)"""

}

/**
 * Prints the new template files detected.
 */
void printNewTemplateFiles(String gitDiffOutput) {
  echo "New template files detected:"
  echo gitDiffOutput
}

/**
 * Extracts template information from git diff output.
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
    // Re-throw the exception to fail the check
    throw e
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
