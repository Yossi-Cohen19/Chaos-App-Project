import { NextResponse } from 'next/server';
import * as k8s from '@kubernetes/client-node';

const kc = new k8s.KubeConfig();

// Load in-cluster config (when running in pod) or local kubeconfig (for development)
if (process.env.KUBERNETES_SERVICE_HOST) {
    kc.loadFromCluster();
} else {
    kc.loadFromDefault();
}

const k8sApi = kc.makeApiClient(k8s.CoreV1Api);
const namespace = process.env.NAMESPACE || 'dev';

export async function GET() {
    try {
        const response = await k8sApi.listNamespacedPod(namespace);
        const pods = response.body.items
            .filter(pod => pod.metadata?.name?.startsWith('chaos-app'))
            .map(pod => ({
                name: pod.metadata?.name || 'unknown',
                status: pod.status?.phase || 'Unknown',
                ready: pod.status?.containerStatuses?.[0]?.ready || false,
                restarts: pod.status?.containerStatuses?.[0]?.restartCount || 0,
                age: pod.metadata?.creationTimestamp,
                nodeName: pod.spec?.nodeName || 'unknown',
            }));

        return NextResponse.json({ pods });
    } catch (error: any) {
        console.error('K8s API error:', error);
        return NextResponse.json(
            { error: 'Failed to list pods', message: error.message },
            { status: 500 }
        );
    }
}

export async function DELETE(request: Request) {
    try {
        const { searchParams } = new URL(request.url);
        const podName = searchParams.get('name');

        if (!podName) {
            return NextResponse.json(
                { error: 'Pod name is required' },
                { status: 400 }
            );
        }

        // Delete the pod
        await k8sApi.deleteNamespacedPod(podName, namespace);

        return NextResponse.json({
            success: true,
            message: `Pod ${podName} deleted successfully`,
        });
    } catch (error: any) {
        console.error('Pod deletion error:', error);
        return NextResponse.json(
            { error: 'Failed to delete pod', message: error.message },
            { status: 500 }
        );
    }
}
