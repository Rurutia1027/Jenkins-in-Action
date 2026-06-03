# Jenkins in Action 

## Learning Objectives 
- Understand the full CI/CD lifecycle and its importance in modern software development. 
- Gain hands-on experience with **Jenkins installation, configuration, and pipelines**. 
- Explore **Maven builds, Docker integration, and DevSecOps practices**
- Learn advanced Jenkins features: 
> Multibranch Pipelines
> Shared Libraries 
> Webhook integration with GitHub 
- Develop **production-grade CI/CD pipelines** for real-world applications. 
- Extend learning to **Cloud Native concepts and Kubernetes deployment**. 


## Learning Tour 
### 1. CI/CD & SDLC Foundations 
- SDLC lifecycle, CI/CD principles, Git branching strategies 
- Understand how modern delivery pipelines are structured and why CI/CD matters


### 2. Jenkins Fundamentals 
- Jenkins architecture, installation (local/Docker), core concepts (controller, agents, jobs)
- Be able to install, configure, and understand Jenkins execution model 

### 3. Freestyle Jobs 
- Jenkins freestyle jobs, workspace, JENKINS_HOME, basic build automation 
- Create and manage basic CI jobs and understand Jenkins internal storage 


### 4. Docker-based CI/CD 
- Containerized application builds (Flask example), Docker-in-Jenkins workflows 
- Build, package, and deploy containerized applications via Jenkins pipelines 

### 5. Jenkins Pipelines 
- Declarative & scripted pipelines, Jenkinsfile, pipeline stages 
- Implement end-to-end CI/CD pipelines as code 

### 6. Multibranch Pipelines 
- Git branch-based automation, GitFlow vs trunk-based CI/CD 
- Enable automatic: pipeline creation per branch and environment promotion 

### 7. Build Tools & DevSecOps 
- Maven builds, SonaQube static analysis, security scanning concepts (SAST, SCA)
- Integrate build + quality + security checks into CI/CD pipelines 

### 8. End-to-End DevSecOps (Mega Project)
- Full pipeline: checkout --> build --> scan --> containerize --> push --> deploy 
- Build production-like CI/CD pipelines with security and deployment stages 

### 9. Jenkins Shared Libraries 
- Pipeline modularization, reusable logic, multi-repo pipeline design 
- Design scalable and maintainable CI/CD pipelines for treams

### 10. Jenkins on Kubernetes 
- Deploy Jenkins on Kubernetes using **Kustomize** (Deployment, Service, PVC, ConfigMap)
- Learn to manage environment overlays (dev/staging/prod) for reproducible deployments 
- Understand scaling Jenkins with dynamic agent pods and persistent storage management 

### 11. Terraform & GitOps for Jenkins 
- Use **Terraform + Jenkins Provider** to manage Jobjs, Pipelines, Credentials, Views 
- Combine with **Jenkinsfile + Shared Libraries** to implement full CI/CD pipeline as code 
- Explore GitOps practices: integrate Jenkins deployment and configuration into **ArgoCD/Flux** workflows for declarative infrastructur and pipeline management
- Achieve fully **versioned, reproducible, and environment-consistent CI/CD pipelines**


## Summarize 
- Start with Kubernetes + Kubernetes for basic Jenkins deployment
- Layer Teraform for Jenkins resource management on top 
- 


## Hands-On Setup 

### Clone the repo 

```bash 
git clone https://github.com/Rurutia1027/Jenkins-in-Action.git
cd Jenkins-in-Action
```

### Run Jenkins using Docker 

```bash 
docker run -p 8080:8080 -p 50000:50000 jenkins/jenkins:lts
```

### Explore sample projects 
- Maven project builds 
- Docker container deployment 
- Jenkinsfile examples for pipelines 


## Next Steps / Customization 
- Deploy Jenkins as a K8s service with PersistentVolume for JENKINS_HOME. 
- Create pipelines that automatically build, scan, and deploy **microservices containers**. 
- Integrate **cloud services** (AWS, GCP, Azure) for artifact storage or deployment. 
