
#!/bin/bash
set -euo pipefail

REGION="us-east-2"
SECRET_ARN="arn:aws:secretsmanager:us-east-2:395459394365:secret:rds!db-b75b5dc6-f761-498a-8365-2d0a016db2fd-tSccKj"
DB_HOST="tf-project2-mysql.cnu2wsciatwj.us-east-2.rds.amazonaws.com"
DB_NAME="jwt"
WAR_BUCKET="project2-war-395459394365-1791684181"

# Install Java, AWS CLI, and jq
dnf install -y java-17-amazon-corretto awscli jq

# Retrieve database credentials without printing them
umask 077
aws secretsmanager get-secret-value \
  --secret-id "$SECRET_ARN" \
  --region "$REGION" \
  --query SecretString \
  --output text |
jq -r '"DB_USER=\(.username)\nDB_PASSWORD=\(.password)"' \
  > /etc/tomcat-db.env

chmod 600 /etc/tomcat-db.env

# Install Tomcat 9
TOMCAT_VERSION="9.0.108"
cd /opt

curl -fL --retry 3 \
  "https://archive.apache.org/dist/tomcat/tomcat-9/v${TOMCAT_VERSION}/bin/apache-tomcat-${TOMCAT_VERSION}.tar.gz" \
  -o tomcat.tar.gz

test -s tomcat.tar.gz
tar -xzf tomcat.tar.gz
mv "apache-tomcat-${TOMCAT_VERSION}" tomcat
rm tomcat.tar.gz

# Download the prebuilt WAR from private S3
aws s3 cp \
  "s3://${WAR_BUCKET}/LoginWebApp.war" \
  /opt/tomcat/webapps/LoginWebApp.war \
  --region "$REGION"

JAVA_HOME="$(dirname "$(dirname "$(readlink -f "$(command -v java)")")")"
# Configure Tomcat
cat > /etc/systemd/system/tomcat.service <<SERVICE
[Unit]
Description=Apache Tomcat 9
After=network.target

[Service]
Type=forking
Environment=JAVA_HOME=${JAVA_HOME}
Environment=PATH=${JAVA_HOME}/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin
Environment=CATALINA_HOME=/opt/tomcat
Environment=CATALINA_BASE=/opt/tomcat
Environment=DB_HOST=${DB_HOST}
Environment=DB_NAME=${DB_NAME}
EnvironmentFile=/etc/tomcat-db.env
ExecStart=/opt/tomcat/bin/startup.sh
ExecStop=/opt/tomcat/bin/shutdown.sh
Restart=on-failure
User=root

[Install]
WantedBy=multi-user.target
SERVICE

systemctl daemon-reload
systemctl enable tomcat
systemctl start tomcat