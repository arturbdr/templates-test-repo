# Test Repository for Jenkins Pipeline

This is a minimal test repository to validate the Jenkins pipeline logic locally.

## Files:
- `test-pipeline.groovy` - Standalone pipeline for testing HTTP requests and git diff logic
- `README.md` - This file

## Usage in Jenkins:

1. Create a new Pipeline job in Jenkins
2. Choose "Pipeline script from SCM" or copy the content of `test-pipeline.groovy`
3. Run the job to test functionality

## What it tests:
- HTTP Request plugin functionality
- Git diff parsing logic  
- JSON payload creation
- Error handling
