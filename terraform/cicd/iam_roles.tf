resource "aws_iam_role" "codepipeline_role" {
  name = "codepipeline-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Effect = "Allow",
      Principal = {
        Service = "codepipeline.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "codepipeline_policy" {
  role       = aws_iam_role.codepipeline_role.name
  policy_arn = "arn:aws:iam::aws:policy/AWSCodePipeline_FullAccess"
}

resource "aws_iam_role" "codebuild_role" {
  name = "codebuild-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Effect = "Allow",
      Principal = {
        Service = "codebuild.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy" "codepipeline_codebuild_access" {
  name = "codepipeline-codebuild-access"
  role = aws_iam_role.codepipeline_role.name

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "codebuild:StartBuild",
          "codebuild:BatchGetBuilds"
        ],
        Resource = "arn:aws:codebuild:ap-south-1:879112120115:project/dofs-terraform-build"
      }
    ]
  })
}

resource "aws_iam_role_policy" "codepipeline_s3_access" {
  name = "codepipeline-s3-access"
  role = aws_iam_role.codepipeline_role.name

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:PutObject",
          "s3:PutObjectAcl"
        ],
        Resource = [
          "arn:aws:s3:::dofs-pipeline-artifacts",
          "arn:aws:s3:::dofs-pipeline-artifacts/*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "codebuild_policy" {
  role       = aws_iam_role.codebuild_role.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

resource "aws_iam_policy" "codestar_connection_policy" {
  name   = "UseCodeStarConnectionPolicy"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = [
          "codestar-connections:UseConnection"
        ],
        Resource = "arn:aws:codeconnections:ap-south-1:879112120115:connection/983ae101-a17f-4b3e-a9df-bf5553e8622f"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "codepipeline_codestar_access" {
  role       = aws_iam_role.codepipeline_role.name
  policy_arn = aws_iam_policy.codestar_connection_policy.arn
}

