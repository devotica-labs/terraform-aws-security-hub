# Data sources used by main.tf.
# Kept minimal so tflint + terraform plan stay fast on offline runs.

data "aws_region" "current" {}
