# tfe_fdo_active_active_on_aws.py

from diagrams import Cluster, Diagram
from diagrams.aws.general import Client
from diagrams.aws.network import Route53, ElbApplicationLoadBalancer
from diagrams.aws.compute import EC2, EC2AutoScaling
from diagrams.aws.database import RDSPostgresqlInstance, ElasticacheForRedis
from diagrams.aws.storage import SimpleStorageServiceS3Bucket


with Diagram("TFE FDO Active-Active on AWS", show=False, direction="TB"):
    
    Client = Client("Client")
    
    with Cluster("AWS"):
        DNS = Route53("DNS")
        with Cluster("VPC"):
            with Cluster("Public Subnet"):
                Bastion = EC2 ("Bastion Host")
                ALB = ElbApplicationLoadBalancer ("Application Load Balancer")
            
            with Cluster("Private Subnet"):
                ASG = EC2AutoScaling ("Auto Scaling Group")
                Postgres = RDSPostgresqlInstance("PostgreSQL")
                Redis = ElasticacheForRedis("Redis")

        S3 = SimpleStorageServiceS3Bucket("S3 bucket")

    Client >> DNS
    DNS >> ALB
    Bastion >> ASG
    ALB >> ASG
    ASG >> Postgres
    ASG >> Redis
    ASG >> S3
