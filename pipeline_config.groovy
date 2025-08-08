libraries {
    sdp
}

application_environments {
    dev {
        short_name = "dev"
        document_service_url = "https://f0ed9cc2a917.ngrok-free.app"
    }
    staging {
        short_name = "staging"
        document_service_url = "https://f0ed9cc2a917.ngrok-free.app"
    }
    prod {
        short_name = "prod"
        document_service_url = "https://f0ed9cc2a917.ngrok-free.app"
    }
}

keywords {
    develop = /^develop$/
    main = /^main$/
    production = /^v\d+\.\d+\.\d+/
}
