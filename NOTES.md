Evaluation Criteria:
1. Portability: The solution should work across different operating systems and cloud providers.
2. Automation: Minimal manual intervention required for setup and deployment.
3. Scalability: Ability to easily scale the application horizontally.
4. Security: Proper security measures implemented in the CI/CD pipeline and deployed application.
5. Code Quality: Clean, well-documented code for all scripts and configurations.
6. Best Practices: Adherence to DevOps best practices for containerization, orchestration, and CI/CD.
7. Functionality: The application should be fully functional and accessible after deployment.
8. Documentation: Clear, concise, and comprehensive documentation.

Bonus Points:
- [ ] Implement monitoring and logging solutions.
- [ ] Add rollback capabilities to the deployment process.
- [ ] Integrate with a package manager for dependency management.
- [ ] Implement multi-stage builds for optimized Docker images.


# CICD

Each workflow now:

triggers on main pushes affecting its service, the shared Helm chart, or its values file, plus workflow_dispatch
uses Docker Buildx to build and push to Docker Hub with tags ${{ github.sha }} and latest
runs Trivy against the pushed ${{ github.sha }} image and fails on any CRITICAL CVEs
configures AWS credentials, updates EKS kubeconfig, and runs helm upgrade --install against the existing chart with the new image tag
Assumptions baked into the workflows:

Docker images are published as ${DOCKERHUB_USERNAME}/hackathon-starter-backend and ${DOCKERHUB_USERNAME}/hackathon-starter-frontend
EKS deploys use Helm releases backend and frontend in namespace app
branch is main
You still need these repo settings in GitHub:

Secrets: DOCKERHUB_USERNAME, DOCKERHUB_TOKEN, AWS_ROLE_TO_ASSUME
Variables: EKS_CLUSTER_NAME
Optional variables: AWS_REGION (defaults to ap-southeast-1), K8S_NAMESPACE (defaults to app)
