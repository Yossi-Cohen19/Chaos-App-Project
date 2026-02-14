import { NextResponse } from 'next/server';
import * as k8s from '@kubernetes/client-node';

const kc = new k8s.KubeConfig();

// Load in-cluster config (when running in pod) or local kubeconfig (for development)
if (process.env.KUBERNETES_SERVICE_HOST) {
    kc.loadFromCluster();
} else {
    kc.loadFromDefault();
}

const k8sAppsApi = kc.makeApiClient(k8s.AppsV1Api);
const namespace = process.env.NAMESPACE || 'dev';
const deploymentName = process.env.DEPLOYMENT_NAME || 'chaos-app-dev-chaos-generic';

export async function POST(request: Request) {
    try {
        const body = await request.json();
        const { replicas } = body;

        // Validate replica count
        if (typeof replicas !== 'number' || replicas < 0 || replicas > 10) {
            return NextResponse.json(
                { error: 'Invalid replica count. Must be between 0 and 10.' },
                { status: 400 }
            );
        }

        // Patch the deployment with new replica count
        const patch = {
            spec: {
                replicas: replicas,
            },
        };

        await k8sAppsApi.patchNamespacedDeployment(
            deploymentName,
            namespace,
            patch,
            undefined,
            undefined,
            undefined,
            undefined,
            undefined,
            {
                headers: {
                    'Content-Type': 'application/strategic-merge-patch+json',
                },
            }
        );

        return NextResponse.json({
            success: true,
            replicas: replicas,
            deployment: deploymentName,
            namespace: namespace,
        });
    } catch (error: any) {
        console.error('Scale API error:', error);
        return NextResponse.json(
            {
                error: 'Failed to scale deployment',
                message: error.message || 'Unknown error',
            },
            { status: 500 }
        );
    }
}

export async function GET() {
    try {
        // Return current replica count
        const deployment = await k8sAppsApi.readNamespacedDeployment(
            deploymentName,
            namespace
        );

        return NextResponse.json({
            replicas: deployment.body.spec?.replicas || 0,
            deployment: deploymentName,
            namespace: namespace,
        });
    } catch (error: any) {
        console.error('Scale API error:', error);
        return NextResponse.json(
            {
                error: 'Failed to read deployment',
                message: error.message || 'Unknown error',
            },
            { status: 500 }
        );
    }
}
