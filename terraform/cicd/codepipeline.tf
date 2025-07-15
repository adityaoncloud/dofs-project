resource "aws_s3_bucket" "codepipeline_artifacts" {
  bucket = "dofs-pipeline-artifacts"
  force_destroy = true
}

resource "aws_codepipeline" "terraform_pipeline" {
  name     = "dofs-terraform-pipeline"
  role_arn = aws_iam_role.codepipeline_role.arn
  artifact_store {
    location = aws_s3_bucket.codepipeline_artifacts.bucket
    type     = "S3"
  }

  stage {
    name = "Source"
    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeStarSourceConnection"
      version          = "1"
      output_artifacts = ["source_output"]

      configuration = {
      ConnectionArn        = "arn:aws:codeconnections:ap-south-1:879112120115:connection/983ae101-a17f-4b3e-a9df-bf5553e8622f"
      FullRepositoryId     = "adityaoncloud/dofs-project"
      BranchName           = "main"
    }
    }
  }

  stage {
    name = "Deploy"
    action {
      name             = "TerraformDeploy"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      input_artifacts  = ["source_output"]
      version          = "1"
      configuration = {
        ProjectName = aws_codebuild_project.terraform_build.name
      }
    }
  }
}
