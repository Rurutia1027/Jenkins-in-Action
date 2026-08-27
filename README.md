# Jenkins in Action 

A hands-on project demonstrating how to build a CI/CD pipeline with Jenkins and integrate automated testing into the software delivery workflow. 

This project shows how Jenkins can automate the complete lifecycle from code changes to testing and deployment. 

## Overview 
Modern DevOps practices require fast feedback and reliable delivery. In this project, Jenkins is used to orchestrate: 
- Application build
- Automated testing
- Test report generation
- Deployment automation
- Environment management

Pipeline flow: 

Code Commit --> Jenkins Pipeline 
-> Build Application 
-> Run Tests 
-> Generate Reports 
-> Deploy Application 


## Tech Stack 
- Jenkins
- Jenkinsfile
- Docker
- Playwright
- K6
- Fly.io
- Git

## CI/CD Pipeline 
Implemented Jenkins pipeline stages: 

### 1. Build 
- Checkout source code
- Build application
- Prepare deployment artifacts

### 2. Automated Testing 
Integrated multiple testing layers:
- Backend Unit Tests
- Frontend Unit Tests
- API Tests
- End-to-End Tests
- Performance Tests

### 3. Test Reports 
Jenkins publishes: 
- Test execution results
- Code coverage reports
- Performance test reports 

### 4. Deployment 
Automated deployment workflow: 
- Staging deployment
- Post-deployment verification
- Production deployment



## Key Jenkins Concepts 
Through this project, we can 
- Configure Jenkins jobs
- Create Jenkins pipelines using Jenkinsfile
- Manage environment variables and secrets
- Integrate automated tests into CI/CD
- Automate application deployment

## Project Goal 
The goal of this project is to understand how Jenkins acts as the automation engine in a DevOps workflow, connecting source control, testing frameworks, and deployment processes into a repeatable delivery pipeline. 


## Jenkins in Real-World Scenarios 

After completing this course, we will continue exploring how Jenkins is applied in real enterprise engineering environments. 
Based on real-world Jenkins usage patterns, we will dive deeper into several practical scenarios: 

### 1. Daily Development Workflow 

How Jenkins help developers validate code changes before merging into the main branch. 

Topics include: 
- GitHub code submission workflow
- Branch-based Jenkins pipeline execution
- Shared smoke test suites
- Flexible test case selection
- Generating and reviewing test reports
- Debugging failed test cases with build context
- Re-running selected test cases after failure
- Multi-environment isolation
- Jenkins views, configuration, and Jenkinsfile design

### 2. Release Workflow 

How Jenkins supports the complete release process from branch preparation to production deployment. 

Topics include: 
- Release branch validation
- Manual pipeline triggering
- Preparing staging and production-like environments
- Complex environment configuration
- Version tagging
- Full regression testing before release
- Build artifact generation
- Docker image packaging and deployment workflow 

### 3. Scheduled Regression Workflow 

How Jenkins supports the complete release process from branch preparation to production deployment. 
- Sprint-level integration validation
- Branch merge verification
- CI hook triggering Jenkins pipelines
- Isolated test environment creation
- Automated test reports
- Small-scale integration testing after merge
- Nightly full regression testing

The regression pipeline may include: 
- BDD testing across frontend and backend
- Frontend automation testing
  > Screenshot testing
  > Visual regression testing
- Backend API testing
- Cross-service integration validation
- Performance testing with tools such as K6 or JMeter

Through these scenarios, we will understand how Jenkins acts as an automation engine that connects 
- source control
- testing
- framework
- artifact management
- and workflows

in modern DevOps practices. 


## Reference 
[Udemy: CI/CD for Test Automation: Jenkins & GitHub Actions](https://www.udemy.com/course/cicd-testers/?srsltid=AfmBOorDLG7eXXGI3Xol8nHK1RI2QjaG3mSYFoRClV86aFNuqKe902K_&couponCode=CP260817G1)
