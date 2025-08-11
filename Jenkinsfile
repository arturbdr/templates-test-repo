on_change to: develop, {
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
         "Document Service URL: ${app_env.document_service_url}"""

        // Get git diff to find new template files (last commit only)
        def gitDiffOutput = getNewTemplateFilesFromGit()
        if (!gitDiffOutput) {
          printNoTemplatesFoundMessage()
          return
        }

        printNewTemplateFiles(gitDiffOutput)
        def templatesToRegister = extractTemplatesFromGitDiff(gitDiffOutput)
        if (templatesToRegister.isEmpty()) {
          echo "No templates to register after parsing."
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
 * Gets new template files from git diff (last commit).
 * @return String with file paths, one per line.
 */
String getNewTemplateFilesFromGit() {
  echo "Getting git diff from HEAD~1 to HEAD (last commit only)..."
  try {
    return sh(
      script: """
        git diff HEAD~1 HEAD --name-status |
        grep '^A' |
        grep 'src/templates/.*/v[0-9]*.tsx' |
        awk '{print \$2}'
      """,
      returnStdout: true
    ).trim()
  } catch (Exception e) {
    echo "Git diff failed (maybe first commit?): ${e.message}"
    echo "Trying alternative approach..."
    try {
      return sh(
        script: """
          git show --name-status --pretty=format: HEAD |
          grep '^A' |
          grep 'src/templates/.*/v[0-9]*.tsx' |
          awk '{print \$2}'
        """,
        returnStdout: true
      ).trim()
    } catch (Exception e2) {
      echo "Alternative git approach also failed: ${e2.message}"
      return ""
    }
  }
}

/**
 * Prints a message when no new templates are found.
 */
void printNoTemplatesFoundMessage() {
  echo """
        No new template versions detected in git diff.
        This might be because:
        1. No new .tsx files were added
        2. This is the first commit
        3. Files don't match the pattern src/templates/*/v[0-9]*.tsx"""
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
