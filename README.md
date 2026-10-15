# Highly Available AWS Web Application Infrastructure Using CloudFormation

## Project Overview

This project demonstrates the deployment of a highly available Java web application infrastructure on Amazon Web Services (AWS) using AWS CloudFormation.

The infrastructure hosts a Java web application on Amazon EC2 instances running Apache Tomcat, connects the application to an Amazon RDS MySQL database, and distributes incoming HTTPS traffic through an Application Load Balancer.

AWS CloudFormation manages the infrastructure as code, while Amazon EC2 Auto Scaling and CloudWatch alarms provide CPU-based scaling policies.

## Architecture
![AWS CloudFormation architecture](Architecture-1.png)
**Application request flow**

User → Custom Domain → Route 53 / DNS → Application Load Balancer (HTTPS) → EC2 Instances running Apache Tomcat → Amazon RDS for MySQL

**Application deployment flow**

GitHub Repository → Maven Build → WAR Artifact → Apache Tomcat on EC2

**Monitoring and logging**

- Amazon CloudWatch monitors CPU utilization and evaluates scaling alarms.
- EC2 Auto Scaling policies adjust application capacity.
- Amazon SNS sends notifications about Auto Scaling events.
- Amazon S3 stores Application Load Balancer access logs.

## AWS Services and Technologies

| Service / Technology | Purpose |
|---|---|
| AWS CloudFormation | Infrastructure provisioning using YAML templates |
| Amazon VPC | Network isolation and infrastructure networking |
| Public and private subnets | Separate load balancer and application/database network tiers |
| Amazon EC2 | Hosts the Java application |
| EC2 Auto Scaling | Maintains and adjusts application instance capacity |
| Application Load Balancer | Distributes incoming application traffic |
| AWS Certificate Manager | Provides the TLS certificate for HTTPS |
| Amazon Route 53 | DNS integration |
| Amazon RDS for MySQL | Relational database for application data |
| AWS Secrets Manager | Secure storage and retrieval of database credentials |
| Amazon CloudWatch | CPU monitoring and scaling alarms |
| Amazon SNS | Auto Scaling event notifications |
| Amazon S3 | Storage for ALB access logs |
| Git and GitHub | Application source control |
| Apache Maven | Builds and packages the Java application |
| Apache Tomcat 9 | Runs the Java web application |

## Project Architecture and Configuration

### 1. Network Infrastructure

The network layer provides the VPC and subnet architecture required for the application.

The design includes:
- Public subnets for internet-facing infrastructure.
- Private application subnets for EC2 instances.
- Private database networking for Amazon RDS.
- Internet Gateway and NAT Gateway routing where configured.
- Security groups controlling traffic between application components.

### 2. Application Load Balancer and HTTPS

An internet-facing Application Load Balancer receives HTTPS traffic on port 443 and forwards requests to the application target group.

The target group forwards HTTP traffic to Apache Tomcat on port 8080.

The HTTPS listener uses an AWS Certificate Manager certificate.
![Healthy ALB Targets](alb-healthy-targets.png)

### 3. EC2 Application Deployment

The application launch template configures Amazon Linux 2023 instances with Java 17, Git, Maven, and supporting utilities.

During instance initialization, the startup script:

1. Installs the required packages.
2. Downloads and installs Apache Tomcat 9.
3. Retrieves database credentials from AWS Secrets Manager.
4. Configures the database connection environment variables.
5. Clones the Java application source code from GitHub.
6. Builds the application using Maven.
7. Copies the generated `LoginWebApp.war` artifact into Tomcat's `webapps` directory.
8. Enables and starts the Tomcat systemd service.

This workflow builds the WAR from GitHub source code. The active CloudFormation startup script does not download the application WAR from S3.

### 4. Amazon RDS MySQL Integration

The Java application connects to an Amazon RDS MySQL database.

**Database configuration**

- Database name: `jwt`
- Database engine: MySQL
- Application components: `login.jsp` and `userRegistration.jsp`

The application uses database credentials retrieved from AWS Secrets Manager. Network access to the database should be restricted to authorized application resources.

### 5. Auto Scaling and CloudWatch Alarms

The Auto Scaling group is configured with the following capacity limits:

| Setting | Value |
|---|---:|
| Minimum capacity | 2 instances |
| Desired capacity | 2 instances |
| Maximum capacity | 4 instances |

Two CloudWatch alarms are configured to evaluate average CPU utilization over five-minute periods, with two evaluation periods.

**Scale-out policy**

- CPU utilization above 70% triggers the high-CPU alarm.
- The step adjustments increase capacity by one instance for a breach of 0–20 percentage points above the threshold.
- A breach of 20 percentage points or more increases capacity by two instances.

**Scale-in policy**

- CPU utilization below 30% triggers the low-CPU alarm.
- The policy decreases capacity by one instance, subject to the Auto Scaling group's minimum capacity.

The scaling policies are configured in CloudFormation. Successful scale-out and scale-in behavior should be documented separately if those events are tested.
![Auto Scaling Configuration](autoscaling-policies.png)

### 6. SNS Notifications

Amazon SNS is configured to send email notifications for Auto Scaling events, including instance launches, launch failures, terminations, and termination failures.

The email subscription must be confirmed to receive notifications.

### 7. Amazon S3 Access Logging

The CloudFormation application template creates an S3 bucket for Application Load Balancer access logs.

The bucket has public access blocked, and a bucket policy permits the required log-delivery service to write log objects.

These are load balancer access logs, not the Java application's Tomcat logs or the WAR deployment artifact.

## Repository Structure

```text
Project2-CloudFormation/
├── templates/
│   ├── network.yaml
│   ├── security.yaml
│   ├── database.yaml
│   └── application.yaml
├── user-scripts/
│   └── test-instance-userdata.sh
├── screenshots/
└── README.md
```

The `user-scripts/test-instance-userdata.sh` file is a separate test deployment script that downloads a prebuilt WAR from S3. It is not automatically executed by CloudFormation simply because it exists in the repository.

## Deployment Instructions

### Prerequisites

- An AWS account with the required permissions.
- AWS CLI configured for the target account and region.
- CloudFormation templates and required stack exports available.
- An ACM certificate issued in the same region as the Application Load Balancer.
- A configured RDS database and database credentials in Secrets Manager.
- A GitHub repository containing the Java application source code.
- Required DNS records and networking configuration.

This project uses the `us-east-2` (US East – Ohio) region.

### Step 1: Clone the repository

```bash
git clone YOUR-CLOUDFORMATION-REPOSITORY-URL
cd Project2-CloudFormation
```

Replace the repository URL with your actual GitHub repository URL.

### Step 2: Review the templates

Review the YAML files in the `templates/` directory and confirm that parameters, resource references, subnet IDs, security groups, database settings, and IAM permissions match the intended AWS environment.

### Step 3: Validate the templates

For example:

```bash
aws cloudformation validate-template \
  --template-body file://templates/application.yaml \
  --region us-east-2
```

Repeat validation for the other templates as appropriate. Template validation checks syntax and basic structure; it does not guarantee that every resource can be created successfully.

### Step 4: Deploy the infrastructure stacks

Deploy the network, security, database integration, and application stacks in dependency order.

Review each stack's parameters, exports, IAM capabilities, and resource changes before deployment.

For application stack updates, use a CloudFormation change set to review proposed changes before execution.

### Step 5: Verify the deployment

After the application stack reaches `CREATE_COMPLETE` or `UPDATE_COMPLETE`, verify:

- The Auto Scaling group has the expected capacity.
- EC2 instances pass their status checks.
- The ALB target group reports healthy targets.
- The HTTPS listener and certificate are configured correctly.
- The application can connect to the RDS database.
- SNS subscription confirmation and S3 access logging are configured.

## Testing and Validation

The following checks have been performed during project implementation:

- The Java application was accessed over HTTPS.
- Login and registration functionality was tested.
- Two application targets were confirmed healthy in the ALB target group.
- The Auto Scaling group was configured with a minimum of two, desired capacity of two, and maximum of four instances.
- CloudWatch CPU alarms and step-scaling policies were created.
- The CloudFormation application stack reached `UPDATE_COMPLETE`.
![Successful application login page](application-login.png)

Actual scale-out and scale-in events should only be reported as tested if the resulting instance-count changes were observed and verified.

## Security Considerations

- Retrieve database credentials through AWS Secrets Manager rather than committing passwords to source control.
- Restrict RDS inbound access to the application security group.
- Keep application instances in private subnets where configured.
- Require IMDSv2 on EC2 instances.
- Block public access to the ALB access-log bucket.
- Apply least-privilege IAM permissions.
- For production use, store passwords using an appropriate password-hashing algorithm and review application authentication security.

## Cleanup and Cost Management

AWS resources can incur charges while running, including EC2 instances, NAT Gateways, load balancers, and RDS.

When the project is no longer needed, review the CloudFormation stack dependencies and delete resources in the correct order. Check for resources that may remain outside CloudFormation-managed stacks, such as pre-existing databases, S3 buckets, or other separately managed resources.

## Learning Outcomes

This project demonstrates practical experience with:

- Infrastructure as Code using AWS CloudFormation.
- VPC networking and subnet design.
- HTTPS traffic management through an Application Load Balancer.
- Java application deployment using GitHub, Maven, and Tomcat.
- Application-to-database connectivity with Amazon RDS MySQL.
- Secure database credential retrieval through AWS Secrets Manager.
- CPU-based EC2 Auto Scaling policies and CloudWatch alarms.
- SNS notifications and S3 access logging.
- CloudFormation validation, change sets, deployment, and troubleshooting.

## Author

**Harman**

AWS Cloud | DevOps | Infrastructure as Code
