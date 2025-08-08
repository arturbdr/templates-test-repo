pipeline {
    agent any
    
    environment {
        DOCUMENT_SERVICE_URL = 'https://f0ed9cc2a917.ngrok-free.app'
    }
    
    stages {
        stage('Debug Info') {
            steps {
                script {
                    echo "=== Debug Information ==="
                    echo "Branch Name: ${env.BRANCH_NAME}"
                    echo "Git Branch: ${env.GIT_BRANCH}"
                    echo "Build Number: ${env.BUILD_NUMBER}"
                    echo "Document Service URL: ${DOCUMENT_SERVICE_URL}"
                }
            }
        }
        
        stage('Register New Templates') {
            steps {
                script {
                    echo "=== Template Registration Pipeline Started ==="
                    
                    // Get git diff to find new template files
                    echo "Getting git diff from HEAD~1 to HEAD..."
                    
                    def gitDiffOutput = ""
                    try {
                        gitDiffOutput = sh(
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
                            gitDiffOutput = sh(
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
                        }
                    }
                    
                    if (!gitDiffOutput) {
                        echo "No new template versions detected in git diff."
                        echo "This might be because:"
                        echo "1. No new .tsx files were added"
                        echo "2. This is the first commit"
                        echo "3. Files don't match the pattern src/templates/*/v[0-9]*.tsx"
                        return
                    }
                    
                    echo "New template files detected:"
                    echo gitDiffOutput
                    
                    // Parse template information
                    def templatesToRegister = parseNewTemplates(gitDiffOutput)
                    
                    if (templatesToRegister.isEmpty()) {
                        echo "No templates to register after parsing."
                        return
                    }
                    
                    echo "Templates to register after parsing:"
                    templatesToRegister.each { template ->
                        echo "- ${template.code}:${template.version} (from ${template.filePath})"
                    }
                    
                    // Get git metadata
                    def gitCommitHash = sh(script: "git rev-parse HEAD", returnStdout: true).trim()
                    def gitCommitMessage = sh(script: "git log -1 --pretty=%B", returnStdout: true).trim()
                    def gitCommitTimestamp = sh(script: "git log -1 --pretty=%cI", returnStdout: true).trim()
                    
                    echo "=== Git Metadata ==="
                    echo "Hash: ${gitCommitHash}"
                    echo "Message: ${gitCommitMessage}"
                    echo "Timestamp: ${gitCommitTimestamp}"
                    
                    // Register each template
                    templatesToRegister.each { template ->
                        registerTemplateWithDocumentService(template, gitCommitHash, gitCommitMessage, gitCommitTimestamp)
                    }
                    
                    echo "=== Template Registration Pipeline Completed ==="
                }
            }
        }
    }
}

// Parse git diff output to extract template information
List parseNewTemplates(String gitDiffOutput) {
    def templates = [:]
    def lines = gitDiffOutput.split('\n')
    
    echo "=== Parsing Git Diff Output ==="
    lines.each { line ->
        if (line.trim().isEmpty()) return
        
        echo "Processing line: ${line}"
        
        // Parse: src/templates/property-brochure/v2.tsx
        def matcher = line =~ /src\/templates\/([^\/]+)\/v(\d+)\.tsx$/
        if (matcher.find()) {
            def templateCode = matcher.group(1)
            def version = "v${matcher.group(2)}"
            
            echo "Found template: code='${templateCode}', version='${version}', file='${line}'"
            
            // Keep only the highest version per template
            if (!templates[templateCode] || compareVersions(version, templates[templateCode].version) > 0) {
                templates[templateCode] = [
                    code: templateCode,
                    version: version,
                    filePath: line
                ]
                echo "  -> Set as highest version for '${templateCode}': ${version}"
            } else {
                echo "  -> Skipping '${version}' (current highest for '${templateCode}': '${templates[templateCode].version}')"
            }
        } else {
            echo "  -> Line doesn't match template pattern, skipping"
        }
    }
    
    return templates.values().toList()
}

// Compare version strings (v1, v2, etc.)
int compareVersions(String version1, String version2) {
    def v1 = version1.replace('v', '').toInteger()
    def v2 = version2.replace('v', '').toInteger()
    return v1.compareTo(v2)
}

// Register template with document-service
void registerTemplateWithDocumentService(Map template, String gitHash, String gitMessage, String gitTimestamp) {
    echo "=== Registering Template: ${template.code}:${template.version} ==="
    
    try {
        // Build request payload
        def payload = [
            code: template.code,
            version: template.version,
            labels: ["pdf-template", "jenkins-test", "github-repo"],
            git: [
                repo: "arturbdr/templates-test-repo",
                commit: [
                    hash: gitHash,
                    message: gitMessage,
                    timestamp: gitTimestamp
                ]
            ]
        ]
        
        def jsonPayload = writeJSON returnText: true, json: payload
        echo "Sending payload to ${DOCUMENT_SERVICE_URL}/webhooks/backoffice/v1/templates"
        echo "Payload: ${jsonPayload}"
        
        // Make HTTP call to document-service
        def response = httpRequest(
            httpMode: 'POST',
            url: "${DOCUMENT_SERVICE_URL}/webhooks/backoffice/v1/templates",
            contentType: 'APPLICATION_JSON',
            requestBody: jsonPayload,
            validResponseCodes: '201',
            timeout: 30,
            ignoreSslErrors: true
        )
        
        echo "✅ Registration successful!"
        echo "HTTP Status: ${response.status}"
        echo "Response Body: ${response.content}"
        
        // Try to parse templateId from response
        try {
            def responseData = readJSON text: response.content
            echo "Template ID: ${responseData.templateId}"
        } catch (Exception e) {
            echo "Note: Could not parse templateId from response: ${e.message}"
        }
        
    } catch (Exception e) {
        echo "❌ Registration failed for ${template.code}:${template.version}"
        echo "Error: ${e.message}"
        echo "This will not fail the build, marking as unstable"
        currentBuild.result = 'UNSTABLE'
    }
}
