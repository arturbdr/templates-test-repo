pipeline {
    agent any
    
    environment {
        DOCUMENT_SERVICE_URL = 'https://f0ed9cc2a917.ngrok-free.app'
    }
    
    stages {
        stage('Debug Info') {
            steps {
                script {
                    println "=== Debug Information ==="
                    println "Branch Name: ${env.BRANCH_NAME}"
                    println "Git Branch: ${env.GIT_BRANCH}"
                    println "Build Number: ${env.BUILD_NUMBER}"
                    println "Document Service URL: ${DOCUMENT_SERVICE_URL}"
                }
            }
        }
        
        stage('Register New Templates') {
            steps {
                script {
                    println "=== Template Registration Pipeline Started ==="

                    // Get git diff to find new template files
                    println "Getting git diff from HEAD~1 to HEAD..."

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
                        println "Git diff failed (maybe first commit?): ${e.message}"
                        println "Trying alternative approach..."
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
                            println "Alternative git approach also failed: ${e2.message}"
                        }
                    }
                    
                    if (!gitDiffOutput) {
                        println "No new template versions detected in git diff."
                        println "This might be because:"
                        println "1. No new .tsx files were added"
                        println "2. This is the first commit"
                        println "3. Files don't match the pattern src/templates/*/v[0-9]*.tsx"
                        return
                    }
                    
                    println "New template files detected:"
                    println gitDiffOutput

                    // Parse template information
                    def templatesToRegister = parseNewTemplates(gitDiffOutput)
                    
                    if (templatesToRegister.isEmpty()) {
                        println "No templates to register after parsing."
                        return
                    }
                    
                    println "Templates to register after parsing:"
                    templatesToRegister.each { template ->
                        println "- ${template.code}:${template.version} (from ${template.filePath})"
                    }
                    
                    // Get git metadata
                    def gitCommitHash = sh(script: "git rev-parse HEAD", returnStdout: true).trim()
                    def gitCommitMessage = sh(script: "git log -1 --pretty=%B", returnStdout: true).trim()
                    def gitCommitTimestamp = sh(script: "git log -1 --pretty=%cI", returnStdout: true).trim()
                    
                    println "=== Git Metadata ==="
                    println "Hash: ${gitCommitHash}"
                    println "Message: ${gitCommitMessage}"
                    println "Timestamp: ${gitCommitTimestamp}"

                    // Register each template
                    templatesToRegister.each { template ->
                        registerTemplateWithDocumentService(template, gitCommitHash, gitCommitMessage, gitCommitTimestamp)
                    }
                    
                    println "=== Template Registration Pipeline Completed ==="
                }
            }
        }
    }
}

// Parse git diff output to extract template information
List parseNewTemplates(String gitDiffOutput) {
    def templates = [:]
    def lines = gitDiffOutput.split('\n')
    
    println "=== Parsing Git Diff Output ==="
    lines.each { line ->
        if (line.trim().isEmpty()) return
        
        println "Processing line: ${line}"

        // Parse: src/templates/property-brochure/v2.tsx
        def matcher = line =~ /src\/templates\/([^\/]+)\/v(\d+)\.tsx$/
        if (matcher.find()) {
            def templateCode = matcher.group(1)
            def version = "v${matcher.group(2)}"
            
            println "Found template: code='${templateCode}', version='${version}', file='${line}'"

            // Keep only the highest version per template
            if (!templates[templateCode] || compareVersions(version, templates[templateCode].version) > 0) {
                templates[templateCode] = [
                    code: templateCode,
                    version: version,
                    filePath: line
                ]
                println "  -> Set as highest version for '${templateCode}': ${version}"
            } else {
                println "  -> Skipping '${version}' (current highest for '${templateCode}': '${templates[templateCode].version}')"
            }
        } else {
            println "  -> Line doesn't match template pattern, skipping"
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
    println "=== Registering Template: ${template.code}:${template.version} ==="

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
        
        // Use Groovy's built-in JSON serialization
        def jsonPayload = groovy.json.JsonOutput.toJson(payload)
        println "Sending payload to ${DOCUMENT_SERVICE_URL}/webhooks/backoffice/v1/templates"
        println "Payload: ${jsonPayload}"

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
        
        println "✅ Registration successful!"
        println "HTTP Status: ${response.status}"
        println "Response Body: ${response.content}"

        // Try to parse templateId from response using Groovy's JsonSlurper
        try {
            def responseData = new groovy.json.JsonSlurper().parseText(response.content)
            println "Template ID: ${responseData.templateId}"
        } catch (Exception e) {
            println "Note: Could not parse templateId from response: ${e.message}"
        }
        
    } catch (Exception e) {
        println "❌ Registration failed for ${template.code}:${template.version}"
        println "Error: ${e.message}"
        println "This will not fail the build, marking as unstable"
        currentBuild.result = 'UNSTABLE'
    }
}
