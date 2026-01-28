# Visual Studio Code Docker Bake file, for details refer to:
#   - https://docs.docker.com/build/bake/reference/
# Do not edit manually — changes will be overwritten.

## Functions ###########################################################################################################

## Variables ###########################################################################################################

## Targets #############################################################################################################
target "dev-container-vscode" {
    inherits = ["target-base"]
    dockerfile = "./.devcontainer/dev-container-vscode.Dockerfile"
    description = "Visual Studio Code Dev Container local image for '{BAKE_PROJECT_NAME}' project."
    tags = [
        "${BAKE_IMAGE_LOCAL_REGISTRY}/${BAKE_PROJECT_NAME}-dev-container-vscode:latest"
    ]
}

## Groups ##############################################################################################################
