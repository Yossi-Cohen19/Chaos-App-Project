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
        const random = searchParams.get('random');
        const labelSelector = searchParams.get('labelSelector') || 'app.kubernetes.io/instance=chaos-app-dev';

        let targetPodName = podName;

        // If random flag is set or no pod name provided, select a random pod
        if (random === 'true' || !podName) {
            const response = await k8sApi.listNamespacedPod(
                namespace,
                undefined,
                undefined,
                undefined,
                undefined,
                labelSelector
            );

            const availablePods = response.body.items.filter(
                pod => pod.status?.phase === 'Running'
            );

            if (availablePods.length === 0) {
                return NextResponse.json(
                    { error: 'No running pods found matching selector' },
                    { status: 404 }
                );
            }

            // Select random pod
            const randomIndex = Math.floor(Math.random() * availablePods.length);
            targetPodName = availablePods[randomIndex].metadata?.name || null;
        }

        if (!targetPodName) {
            return NextResponse.json(
                { error: 'Pod name is required or no pods available' },
                { status: 400 }
            );
        }

        // Delete the pod
        await k8sApi.deleteNamespacedPod(targetPodName, namespace);

        return NextResponse.json({
            success: true,
            message: `Pod ${targetPodName} deleted successfully`,
            podName: targetPodName,
        });
    } catch (error: any) {
        console.error('Pod deletion error:', error);
        return NextResponse.json(
            { error: 'Failed to delete pod', message: error.message },
            { status: 500 }
        );
    }
}
