# Output all relevant EC2 instance details as a single object
output "instance_details" {
description = "Detailed information about the EC2 instance"
value = {
instance_id = aws_instance.public_instance.id

instance_public_ip = aws_instance.public_instance.public_ip
instance_private_ip = aws_instance.public_instance.private_ip
instance_name = aws_instance.public_instance.tags["Name"]
security_group_id = aws_instance.public_instance.vpc_security_group_ids
# Security group attached to the instance
subnet_id = aws_instance.public_instance.subnet_id
}
}

output "deployer_key_s3_uri" {
description = "S3 URI of the deployer key file"
value = "s3://${aws_s3_bucket_object.private_key_object.bucket}/${aws_s3_bucket_object.private_key_object.key}"
}
output "rds_endpoint" {
description = "The endpoint of the RDS database"
value = {
endpoint = aws_db_instance.mydb.endpoint
username = aws_db_instance.mydb.username
db_instance_id = aws_db_instance.mydb.id
}
}
