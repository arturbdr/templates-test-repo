pipeline {
    agent any

    environment {
        DOCUMENT_SERVICE_URL = 'https://f0ed9cc2a917.ngrok-free.app'
    }

    stages {
        stage('Debug Info') {
            steps {
                script {
                    printDebugInfo()
                }
            }
        }

        stage('Register New Templates') {
            steps {
                script {
                    runTemplateRegistrationPipeline()
                }
            }
        }
    }
}

/**
 * Prints debug information about the build environment.
 */
void printDebugInfo() {
    println "=== Debug Information ==="
    println "Branch Name: ${env.BRANCH_NAME}"
    println "Git Branch: ${env.GIT_BRANCH}"
    println "Build Number: ${env.BUILD_NUMBER}"
    println "Document Service URL: ${env.DOCUMENT_SERVICE_URL}"
}

/**
 * Main entrypoint for the template registration pipeline.
 */
void runTemplateRegistrationPipeline() {
    println "=== Template Registration Pipeline Started ==="
    def gitDiffOutput = getNewTemplateFilesFromGit()
    if (!gitDiffOutput) {
        printNoTemplatesFoundMessage()
        return
    }
    printNewTemplateFiles(gitDiffOutput)
    def templatesToRegister = extractTemplatesFromGitDiff(gitDiffOutput)
    if (templatesToRegister.isEmpty()) {
        println "No templates to register after parsing."
        return
    }
    printTemplatesToRegister(templatesToRegister)
    def gitMeta = getGitMetadata()
    printGitMetadata(gitMeta)
    registerTemplates(templatesToRegister, gitMeta)
    println "=== Template Registration Pipeline Completed ==="
}

/**
 * Attempts to get new template files from git diff.
 * @return String with file paths, one per line.
 */
String getNewTemplateFilesFromGit() {
    println "Getting git diff from HEAD~1 to HEAD..."
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
        println "Git diff failed (maybe first commit?): ${e.message}"
        println "Trying alternative approach..."
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
            println "Alternative git approach also failed: ${e2.message}"
            return ""
        }
    }
}

/**
 * Prints a message when no new templates are found.
 */
void printNoTemplatesFoundMessage() {
    println "No new template versions detected in git diff."
    println "This might be because:"
    println "1. No new .tsx files were added"
    println "2. This is the first commit"
    println "3. Files don't match the pattern src/templates/*/v[0-9]*.tsx"
}

/**
 * Prints the new template files detected.
 * @param gitDiffOutput String with file paths.
 */
void printNewTemplateFiles(String gitDiffOutput) {
    println "New template files detected:"
    println gitDiffOutput
}

/**
 * Extracts template information from git diff output.
 * @param gitDiffOutput String with file paths.
 * @return List of template maps.
 */
List extractTemplatesFromGitDiff(String gitDiffOutput) {
    println "=== Parsing Git Diff Output ==="
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
    println "Processing line: ${line}"
    def matcher = line =~ /src\/templates\/([^\/]+)\/v(\d+)\.tsx$/
    if (matcher.find()) {
        def templateCode = matcher.group(1)
        def version = "v${matcher.group(2)}"
        println "Found template: code='${templateCode}', version='${version}', file='${line}'"
        updateTemplateIfHighestVersion(templates, templateCode, version, line)
    } else {
        println "  -> Line doesn't match template pattern, skipping"
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
        println "  -> Set as highest version for '${templateCode}': ${version}"
    } else {
        println "  -> Skipping '${version}' (current highest for '${templateCode}': '${templates[templateCode].version}')"
    }
}

/**
 * Prints the templates that will be registered.
 */
void printTemplatesToRegister(List templatesToRegister) {
    println "Templates to register after parsing:"
    templatesToRegister.each { template ->
        println "- ${template.code}:${template.version} (from ${template.filePath})"
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
    println "=== Git Metadata ==="
    println "Hash: ${gitMeta.hash}"
    println "Message: ${gitMeta.message}"
    println "Timestamp: ${gitMeta.timestamp}"
}

/**
 * Registers all templates with the document service.
 */
void registerTemplates(List templatesToRegister, Map gitMeta) {
    templatesToRegister.each { template ->
        registerTemplateWithDocumentService(template, gitMeta)
    }
}

/**
 * Registers a single template with the document service.
 * @param template Map with template info.
 * @param gitMeta Map with git metadata.
 */
void registerTemplateWithDocumentService(Map template, Map gitMeta) {
    println "=== Registering Template: ${template.code}:${template.version} ==="
    try {
        def payload = buildDocumentServicePayload(template, gitMeta)
        def jsonPayload = groovy.json.JsonOutput.toJson(payload)
        println "Sending payload to ${env.DOCUMENT_SERVICE_URL}/webhooks/backoffice/v1/templates"
        println "Payload: ${jsonPayload}"
        def response = sendDocumentServiceRequest(jsonPayload)
        printDocumentServiceResponse(response)
    } catch (Exception e) {
        println "❌ Registration failed for ${template.code}:${template.version}"
        println "Error: ${e.message}"
        println "This will not fail the build, marking as unstable"
        currentBuild.result = 'UNSTABLE'
    }
}

/**
 * Builds the payload for the document service registration.
 */
Map buildDocumentServicePayload(Map template, Map gitMeta) {
    [
        code: template.code,
        version: template.version,
        labels: ["pdf-template", "jenkins-test", "github-repo"],
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
 * Sends the HTTP request to the document service.
 * @param jsonPayload String JSON payload.
 * @return Response object.
 */
def sendDocumentServiceRequest(String jsonPayload) {
    httpRequest(
        httpMode: 'POST',
        url: "${env.DOCUMENT_SERVICE_URL}/webhooks/backoffice/v1/templates",
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
    println "✅ Registration successful!"
    println "HTTP Status: ${response.status}"
    println "Response Body: ${response.content}"
    try {
        def responseData = new groovy.json.JsonSlurper().parseText(response.content)
        println "Template ID: ${responseData.templateId}"
    } catch (Exception e) {
        println "Note: Could not parse templateId from response: ${e.message}"
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
