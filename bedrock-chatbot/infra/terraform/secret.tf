# The app access code. Generated randomly and written with a write-only
# argument, so the value never lands in Terraform state.

ephemeral "random_password" "access_code" {
  length  = 32
  special = false
}

resource "aws_secretsmanager_secret" "access_code" {
  name = "${var.project}/access-code"

  # Learning project: allow immediate deletion on destroy.
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "access_code" {
  secret_id = aws_secretsmanager_secret.access_code.id

  # Write-only: the value is sent to AWS but not stored in state. It is
  # (re)written only when secret_string_wo_version changes — bump it to rotate.
  secret_string_wo         = jsonencode({ accessCode = ephemeral.random_password.access_code.result })
  secret_string_wo_version = 1
}
