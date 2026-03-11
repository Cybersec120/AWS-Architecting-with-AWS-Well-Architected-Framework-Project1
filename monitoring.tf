# ─────────────────────────────────────────────
# SNS — Alert Topic
# All CloudWatch alarms fire to this topic
# ─────────────────────────────────────────────

resource "aws_sns_topic" "alerts" {
  name              = "${var.project_name}-alerts"
  kms_master_key_id = "alias/aws/sns"
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# ─────────────────────────────────────────────
# CloudWatch Alarms — CloudFront Metrics
# ─────────────────────────────────────────────

# Alarm: High 4xx error rate (client errors — bad links, missing pages)
resource "aws_cloudwatch_metric_alarm" "cloudfront_4xx_errors" {
  alarm_name          = "${var.project_name}-cloudfront-4xx-error-rate"
  alarm_description   = "CloudFront 4xx error rate exceeded ${var.error_rate_threshold}%"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "4xxErrorRate"
  namespace           = "AWS/CloudFront"
  period              = 300 # 5 minutes
  statistic           = "Average"
  threshold           = var.error_rate_threshold
  treat_missing_data  = "notBreaching"

  dimensions = {
    DistributionId = aws_cloudfront_distribution.website.id
    Region         = "Global"
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions    = [aws_sns_topic.alerts.arn]
}

# Alarm: High 5xx error rate (server errors — origin failures)
resource "aws_cloudwatch_metric_alarm" "cloudfront_5xx_errors" {
  alarm_name          = "${var.project_name}-cloudfront-5xx-error-rate"
  alarm_description   = "CloudFront 5xx error rate exceeded 1% — possible origin issue"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "5xxErrorRate"
  namespace           = "AWS/CloudFront"
  period              = 300
  statistic           = "Average"
  threshold           = 1 # 5xx should almost never happen
  treat_missing_data  = "notBreaching"

  dimensions = {
    DistributionId = aws_cloudfront_distribution.website.id
    Region         = "Global"
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions    = [aws_sns_topic.alerts.arn]
}

# Alarm: Sudden drop in requests (could mean DNS issue or traffic drop)
resource "aws_cloudwatch_metric_alarm" "cloudfront_low_requests" {
  alarm_name          = "${var.project_name}-cloudfront-low-requests"
  alarm_description   = "Unusually low request count — possible availability issue"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 3
  metric_name         = "Requests"
  namespace           = "AWS/CloudFront"
  period              = 3600 # 1 hour window
  statistic           = "Sum"
  threshold           = 10
  treat_missing_data  = "breaching" # No data = something is wrong

  dimensions = {
    DistributionId = aws_cloudfront_distribution.website.id
    Region         = "Global"
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
}

# ─────────────────────────────────────────────
# CloudWatch Dashboard
# Single pane of glass for the website health
# ─────────────────────────────────────────────

resource "aws_cloudwatch_dashboard" "website" {
  dashboard_name = "${var.project_name}-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "text"
        x      = 0
        y      = 0
        width  = 24
        height = 1
        properties = {
          markdown = "## ${var.project_name} — Production Dashboard | Environment: ${var.environment}"
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 1
        width  = 8
        height = 6
        properties = {
          title  = "Request Count"
          view   = "timeSeries"
          region = "us-east-1"
          metrics = [
            ["AWS/CloudFront", "Requests", "DistributionId",
            aws_cloudfront_distribution.website.id, "Region", "Global"]
          ]
          period = 300
          stat   = "Sum"
        }
      },
      {
        type   = "metric"
        x      = 8
        y      = 1
        width  = 8
        height = 6
        properties = {
          title  = "4xx Error Rate (%)"
          view   = "timeSeries"
          region = "us-east-1"
          metrics = [
            ["AWS/CloudFront", "4xxErrorRate", "DistributionId",
            aws_cloudfront_distribution.website.id, "Region", "Global"]
          ]
          period = 300
          stat   = "Average"
        }
      },
      {
        type   = "metric"
        x      = 16
        y      = 1
        width  = 8
        height = 6
        properties = {
          title  = "5xx Error Rate (%)"
          view   = "timeSeries"
          region = "us-east-1"
          metrics = [
            ["AWS/CloudFront", "5xxErrorRate", "DistributionId",
            aws_cloudfront_distribution.website.id, "Region", "Global"]
          ]
          period = 300
          stat   = "Average"
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 7
        width  = 12
        height = 6
        properties = {
          title  = "Bytes Downloaded"
          view   = "timeSeries"
          region = "us-east-1"
          metrics = [
            ["AWS/CloudFront", "BytesDownloaded", "DistributionId",
            aws_cloudfront_distribution.website.id, "Region", "Global"]
          ]
          period = 300
          stat   = "Sum"
        }
      },
      {
        type   = "alarm"
        x      = 12
        y      = 7
        width  = 12
        height = 6
        properties = {
          title = "Alarm Status"
          alarms = [
            aws_cloudwatch_metric_alarm.cloudfront_4xx_errors.arn,
            aws_cloudwatch_metric_alarm.cloudfront_5xx_errors.arn,
            aws_cloudwatch_metric_alarm.cloudfront_low_requests.arn
          ]
        }
      }
    ]
  })
}

# ─────────────────────────────────────────────
# CloudWatch Log Group
# For future Lambda@Edge or application logs
# ─────────────────────────────────────────────

resource "aws_cloudwatch_log_group" "website" {
  name              = "/aws/${var.project_name}/website"
  retention_in_days = var.log_retention_days

  tags = {
    Name = "${var.project_name}-logs"
  }
}
