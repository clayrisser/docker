variable "IMAGE" {
  default = ""
}

variable "TAG" {
  default = ""
}

variable "MAJOR" {
  default = ""
}

variable "MINOR" {
  default = ""
}

variable "PATCH" {
  default = ""
}

variable "GIT_COMMIT" {
  default = ""
}

target "default" {
  context    = ".."
  dockerfile = "docker/Dockerfile"
  platforms  = ["linux/amd64"]
  output     = ["type=docker"]
  tags = [
    "${IMAGE}:${TAG}",
    "${IMAGE}:${MAJOR}",
    "${IMAGE}:${MINOR}",
    "${IMAGE}:${PATCH}",
    "${IMAGE}:${GIT_COMMIT}"
  ]
}
