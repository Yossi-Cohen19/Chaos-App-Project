# Implementation Plan: Chaos Platform

This document outlines the next steps required to fully deploy the Chaos Engineering Platform.

## 1. Container Registry (ECR)
- **Status**: **Completed** :white_check_mark:
- **Repository URL**: `462645401469.dkr.ecr.us-east-1.amazonaws.com/chaos-platform-app-dev`
- **Dependencies**: None.

## 2. CI/CD Pipeline (Build & Push)
- **Status**: No CI configuration found.
- **Action**: Create a GitHub Action workflow to:
    1.  Checkout `chaos-nextjs-app`.
    2.  Build the Docker image using the existing `Dockerfile`.
    3.  Push to `462645401469.dkr.ecr.us-east-1.amazonaws.com/chaos-platform-app-dev`.
    4.  Update the image tag in `k8s-manifests` (GitOps flow).

## 3. Kubernetes Manifests
- **Status**: Directory `k8s-manifests` is empty.
- **Action**: Create standard Kubernetes manifests:
    - `deployment.yaml`: Replicas=2, rolling update strategy.
    - `service.yaml`: ClusterIP service.
    - `ingress.yaml`: (Optional) If exposing publicly via ALB/Nginx.
    - `kustomization.yaml`: To manage environment overlays (dev/prod).

## 4. Application Deployment (ArgoCD)
- **Status**: ArgoCD is installed via `addons`, but no Application is defined.
- **Action**:
    - Configure `infrastructure-live/.../app-dev/terragrunt.hcl` to deploy an **ArgoCD Application** resource.
    - Point the ArgoCD Application to the `k8s-manifests` directory in this repository.

## 5. Persistence (RDS Connection)
- **Status**: database provisions, but app needs connection string.
- **Action**:
    - Use **External Secrets Operator** (installed via addons) to fetch RDS credentials from AWS Secrets Manager.
    - Inject `DATABASE_URL` into the application pods via `envFrom` in `deployment.yaml`.
