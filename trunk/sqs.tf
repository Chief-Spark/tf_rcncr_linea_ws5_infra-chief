# Facturacion: cola SQS FIFO + DLQ. La consume la Lambda de Facturacion de esta
# misma cuenta (lambda.tf); su permiso de lectura va en su rol.
# (No hay libreria eits-tf-aws-sqs confirmada para este repo: recursos nativos.)
resource "aws_sqs_queue" "facturacion_dlq" {
  name                      = local.names.sqs_facturacion_dlq
  fifo_queue                = true
  message_retention_seconds = 1209600
  sqs_managed_sse_enabled   = local.kms_enabled ? null : true
  kms_master_key_id         = local.kms_key_arn
}

resource "aws_sqs_queue" "facturacion" {
  name                        = local.names.sqs_facturacion
  fifo_queue                  = true
  content_based_deduplication = true
  visibility_timeout_seconds  = var.facturacion_visibility_timeout_seconds
  sqs_managed_sse_enabled     = local.kms_enabled ? null : true
  kms_master_key_id           = local.kms_key_arn

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.facturacion_dlq.arn
    maxReceiveCount     = var.facturacion_max_receive_count
  })
}

resource "aws_sqs_queue_redrive_allow_policy" "facturacion_dlq" {
  queue_url = aws_sqs_queue.facturacion_dlq.id

  redrive_allow_policy = jsonencode({
    redrivePermission = "byQueue"
    sourceQueueArns   = [aws_sqs_queue.facturacion.arn]
  })
}

data "aws_iam_policy_document" "facturacion_queue" {
  statement {
    sid       = "DenyInsecureTransport"
    effect    = "Deny"
    actions   = ["sqs:*"]
    resources = [aws_sqs_queue.facturacion.arn]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }

  # RecMicroservicios (misma cuenta) publica en la cola: basta con la queue
  # policy, sin tocar su rol (que no administra este repo).
  dynamic "statement" {
    for_each = data.aws_lambda_function.recmicroservicios
    content {
      sid       = "AllowRecMicroserviciosProducer"
      actions   = ["sqs:SendMessage", "sqs:GetQueueAttributes", "sqs:GetQueueUrl"]
      resources = [aws_sqs_queue.facturacion.arn]

      principals {
        type        = "AWS"
        identifiers = [statement.value.role]
      }
    }
  }
}

resource "aws_sqs_queue_policy" "facturacion" {
  queue_url = aws_sqs_queue.facturacion.id
  policy    = data.aws_iam_policy_document.facturacion_queue.json
}
