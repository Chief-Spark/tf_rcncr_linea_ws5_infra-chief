# Facturacion: cola SQS FIFO + DLQ. La Lambda que la consume vive en otra cuenta;
# aqui solo se le da acceso cross-account por queue policy.
# (No hay libreria eits-tf-aws-sqs confirmada para este repo: recursos nativos.)
resource "aws_sqs_queue" "facturacion_dlq" {
  name                      = local.names.sqs_facturacion_dlq
  fifo_queue                = true
  message_retention_seconds = 1209600
  sqs_managed_sse_enabled   = local.kms_key_arn == null ? true : null
  kms_master_key_id         = local.kms_key_arn
}

resource "aws_sqs_queue" "facturacion" {
  name                        = local.names.sqs_facturacion
  fifo_queue                  = true
  content_based_deduplication = true
  visibility_timeout_seconds  = var.facturacion_visibility_timeout_seconds
  sqs_managed_sse_enabled     = local.kms_key_arn == null ? true : null
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

  dynamic "statement" {
    for_each = length(var.facturacion_consumer_principal_arns) > 0 ? [1] : []
    content {
      sid       = "AllowCrossAccountConsumer"
      actions   = ["sqs:ReceiveMessage", "sqs:DeleteMessage", "sqs:ChangeMessageVisibility", "sqs:GetQueueAttributes"]
      resources = [aws_sqs_queue.facturacion.arn]

      principals {
        type        = "AWS"
        identifiers = var.facturacion_consumer_principal_arns
      }
    }
  }
}

resource "aws_sqs_queue_policy" "facturacion" {
  queue_url = aws_sqs_queue.facturacion.id
  policy    = data.aws_iam_policy_document.facturacion_queue.json
}
