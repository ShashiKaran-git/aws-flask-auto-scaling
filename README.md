# 🚀 AWS Auto Scaling Flask App (Terraform + ALB + CloudWatch)

## 📌 Overview

This project demonstrates a production-style deployment of a Flask application on AWS using Infrastructure as Code (Terraform), Auto Scaling, and monitoring.

---

## 🏗️ Architecture

* Application Load Balancer (ALB)
* EC2 instances (Dockerized Flask app)
* Auto Scaling Group (ASG)
* CloudWatch (Metrics & Alarms)
* SNS (Email Notifications)

---

## ⚙️ Features

* High availability using ALB
* Auto scaling based on CPU utilization
* Self-healing infrastructure (auto replacement of unhealthy instances)
* Real-time monitoring with CloudWatch
* Email alerts using SNS

---

## 🧪 Failure Simulation

* Manually stopped Docker container
* Instance became unhealthy
* Auto Scaling replaced the instance automatically

---

## 📊 Observability

* CPU Utilization monitored in CloudWatch
* Alerts triggered when threshold exceeded
* Scaling events tracked in Activity History

---

## 🛠️ Tech Stack

* AWS (EC2, ALB, ASG, CloudWatch, SNS)
* Terraform
* Docker
* Flask

---

## 🚀 Deployment Steps

```bash
cd terraform
terraform init
terraform apply
```

---

## 📸 Screenshots

## 📸 Project Screenshots

### CPU Utilization Spike
![CPU Graph](assets/cwmetrics.png)

### CloudWatch Alarm Triggered
![Alarm](assets/alarm.png)

### Auto Scaling Activity
![ASG](assets/asg.png)

---

## 🧠 Key Learnings

* Real-world Auto Scaling behavior
* Load balancing and health checks
* Monitoring and alerting systems
* Designing self-healing infrastructure
