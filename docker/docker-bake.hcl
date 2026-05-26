variable "BAKE_OUTPUT" {}
variable "DOCKER_REGISTRY" {}
variable "DOCKER_NAME" {}
variable "DOCKER_TAG" {}
variable "GIT_COMMIT" {}

group "default" {
  targets = ["mkpm-docker"]
}

target "_common" {
  context = ".."
  output  = ["type=${BAKE_OUTPUT}"]
}

target "mkpm-docker" {
  inherits   = ["_common"]
  dockerfile = "docker/Dockerfile"
  tags = [
    "${DOCKER_REGISTRY}/${DOCKER_NAME}:${DOCKER_TAG}",
    "${DOCKER_REGISTRY}/${DOCKER_NAME}:${GIT_COMMIT}",
  ]
}
