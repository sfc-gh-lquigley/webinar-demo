variable "aws_region" {
  default = "us-west-2"
}

variable "vpc_id" {
  default = "vpc-0730590be4b927578"
}

variable "private_subnet_ids" {
  default = [
    "subnet-0da2a405a778a09a9",
    "subnet-00eed2b7be7182529",
    "subnet-0ada43aede9f1c386"
  ]
}

variable "logwriter_firehose_arn" {
  default = "arn:aws:firehose:us-west-2:384876807807:deliverystream/webinar-demo-stack-LogWriter"
}

variable "logwriter_destination_role_arn" {
  default = "arn:aws:iam::384876807807:role/webinar-demo-stack-LogWriter-9CN804-DestinationRole-LxkKGdCWFRA3"
}

variable "prefix" {
  default = "observe-batch-demo"
}
