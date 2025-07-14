resource "aws_codebuild_project" "terraform_build" {
  name          = "dofs-terraform-build"
  description   = "Build project to deploy Terraform"
  service_role  = aws_iam_role.codebuild_role.arn
  build_timeout = 10

  artifacts {
    type = "NO_ARTIFACTS"
  }

  environment {
    compute_type    = "BUILD_GENERAL1_SMALL"
    image           = "aws/codebuild/standard:7.0"
    type            = "LINUX_CONTAINER"
    privileged_mode = true

    environment_variable {
      name  = "TF_VAR_env"
      value = "dev"
    }
  }

  source {
    type            = "GITHUB"
    location        = "https://github.com/adityaoncloud/dofs-project.git"
    buildspec       = "buildspec.yml"
    git_clone_depth = 1
  }
}
