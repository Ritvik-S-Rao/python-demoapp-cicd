# Python Flask App - CI/CD & AWS Deployment Pipeline

This repository contains an end-to-end CI/CD pipeline for containerizing and deploying a legacy Python Flask application to AWS EC2 using GitHub Actions, Docker, and Terraform.

##Architecture
![CI/CD pipeline architecture](./docs/Architecture.png)

## 🙏 Acknowledgments
A special thanks to [benc-uk](https://github.com/benc-uk) for providing the original base application: [benc-uk/python-demoapp](https://github.com/benc-uk/python-demoapp). This project builds upon their foundational work by introducing a robust Infrastructure as Code (IaC) setup and an automated deployment workflow.

## 🏗️ Tech Stack
* **Application:** Python 3.9, Flask, Gunicorn
* **Containerization:** Docker, Docker Hub
* **CI/CD:** GitHub Actions
* **Security:** Trivy (Vulnerability Scanner)
* **Infrastructure (IaC):** Terraform
* **Cloud Provider:** AWS (EC2)

## 🚀 Pipeline Overview
The GitHub Actions workflow (`main.yml`) automates the following steps upon every code push:
1. **Testing:** Sets up a Python 3.9 environment, installs pinned legacy dependencies, and validates the application using `pytest`.
2. **Build & Push:** Authenticates securely with Docker Hub and builds/pushes the latest container image.
3. **Security Scan:** Runs AquaSecurity Trivy to check the Docker image for critical OS and library vulnerabilities. *(Note: Currently configured to report findings without failing the pipeline).*
4. **Deployment:** SSHs into the Terraform-provisioned AWS EC2 instance, installs Docker (if missing), and deploys the newly built container on port 5000.

## ⚙️ Setup & Deployment Order
Because the GitHub Actions pipeline relies on infrastructure and secrets managed by Terraform, you must deploy the infrastructure *before* triggering the pipeline.

1. **Configure Docker Hub Secrets:** Terraform does not manage Docker credentials. You must manually add these to your GitHub Repository (**Settings > Secrets and variables > Actions**):
   * `DOCKERHUB_USERNAME`: Your Docker Hub ID.
   * `DOCKERHUB_TOKEN`: A Docker Hub Personal Access Token.
2. **Export GitHub Credentials:** Terraform requires a GitHub Personal Access Token (PAT) to inject AWS deployment secrets. Export this to your local terminal session:
   ```bash
   export GITHUB_TOKEN="your_personal_access_token"
   ```
   *(Note: If using a Fine-grained PAT, it requires `Secrets: Read and Write` and `Administration: Read-only` permissions on the repository. If using a Classic PAT, use the `repo` scope).*
3. **Provision Infrastructure:**
   ```bash
   terraform init
   terraform apply
   ```
   *Terraform will create the EC2 instance, configure security groups, and automatically inject `EC2_HOST_IP` and `EC2_SSH_KEY` into your GitHub Repository Secrets.*
4. **Trigger Pipeline:** Push code to the `main` branch to trigger the GitHub Actions workflow, which will build and deploy the app to the new instance.

## 🌐 Viewing the Application
Once the pipeline successfully completes the deployment step, your application is live.
1. Retrieve the dynamic public IP address of your EC2 instance from Terraform:
   ```bash
   terraform show | grep public_ip
   ```
   *(Note: This is a standard Public IP, not an Elastic IP. It will change if the instance is destroyed and recreated).*
2. Open your web browser and navigate to:
   ```text
   http://<YOUR_EC2_PUBLIC_IP>:5000
   ```

## 🔒 Security Considerations & Known Trade-offs
To keep this project lightweight and focused on pipeline mechanics, certain architectural trade-offs were made:
* **State File Security:** The Terraform state file currently stores the generated TLS private key in plaintext. In a production environment, this state must be stored in an encrypted remote backend (e.g., AWS S3 with DynamoDB state locking and KMS encryption) to prevent credential leakage.
* **Open SSH Access:** Because the pipeline uses GitHub-hosted runners with dynamic IP addresses, port 22 on the EC2 instance is open to `0.0.0.0/0`. In a stricter production environment, a self-hosted runner inside the VPC or AWS Systems Manager (SSM) should be used to avoid exposing the SSH port to the internet.

## 🛠️ Troubleshooting & Key Learnings
* **Legacy Dependency Conflicts:** Modern versions of `Jinja2` (3.1.0+) removed the `escape` module, breaking older Flask applications. This was resolved by explicitly pinning legacy packages (`"Jinja2<3.1.0" "markupsafe==2.0.1" "itsdangerous==2.0.1" "Werkzeug==2.0.3"`) in both the CI runner and the `Dockerfile`.
* **Docker Socket Permissions:** Deploying via GitHub Actions required configuring the EC2 `ubuntu` user with proper administrative privileges, utilizing `sudo` for all Docker execution commands to avoid `permission denied` socket errors.
* **Container Networking:** To prevent "Connection Refused" errors, the Gunicorn binding was explicitly updated to `0.0.0.0:5000` to accept external internet traffic.
* **Dockerfile Syntax:** Corrected Docker's "exec form" execution by ensuring strict JSON array syntax in the `CMD` instruction (`CMD ["gunicorn", "-b", "0.0.0.0:5000", "run:app"]`) to prevent instant container crashes.

## 🧹 Infrastructure Lifecycle & Cleanup
To cleanly tear down the environment and stop AWS billing:
```bash
terraform destroy
```
*(This destroys the AWS resources and automatically deletes the injected GitHub Secrets).*
