import { NextResponse } from 'next/server';
import * as k8s from '@kubernetes/client-node';
import { EC2Client, DescribeInstanceTypesCommand } from '@aws-sdk/client-ec2';
import { PricingClient, GetProductsCommand } from '@aws-sdk/client-pricing';

const kc = new k8s.KubeConfig();

// Load in-cluster config (when running in pod) or local kubeconfig (for development)
if (process.env.KUBERNETES_SERVICE_HOST) {
    kc.loadFromCluster();
} else {
    kc.loadFromDefault();
}

const k8sCoreApi = kc.makeApiClient(k8s.CoreV1Api);
const k8sAppsApi = kc.makeApiClient(k8s.AppsV1Api);
const namespace = process.env.NAMESPACE || 'dev';
const deploymentName = process.env.DEPLOYMENT_NAME || 'chaos-app-dev-chaos-generic';
const awsRegion = process.env.AWS_REGION || 'us-east-1';

// AWS clients
const ec2Client = new EC2Client({ region: awsRegion });
const pricingClient = new PricingClient({ region: 'us-east-1' }); // Pricing API only available in us-east-1

interface InstancePricing {
    instanceType: string;
    pricePerHour: number;
}

async function getInstanceTypeFromNodes(): Promise<string> {
    try {
        const nodes = await k8sCoreApi.listNode();
        if (nodes.body.items.length === 0) {
            throw new Error('No nodes found in cluster');
        }

        // Get instance type from first node
        const instanceType = nodes.body.items[0].metadata?.labels?.['node.kubernetes.io/instance-type'] ||
            nodes.body.items[0].metadata?.labels?.['beta.kubernetes.io/instance-type'];

        if (!instanceType) {
            throw new Error('Could not determine instance type from node labels');
        }

        return instanceType;
    } catch (error) {
        console.error('Error fetching node instance type:', error);
        throw error;
    }
}

async function getInstancePricing(instanceType: string): Promise<number> {
    try {
        // Query AWS Pricing API
        const command = new GetProductsCommand({
            ServiceCode: 'AmazonEC2',
            Filters: [
                {
                    Type: 'TERM_MATCH',
                    Field: 'instanceType',
                    Value: instanceType,
                },
                {
                    Type: 'TERM_MATCH',
                    Field: 'location',
                    Value: getRegionName(awsRegion),
                },
                {
                    Type: 'TERM_MATCH',
                    Field: 'operatingSystem',
                    Value: 'Linux',
                },
                {
                    Type: 'TERM_MATCH',
                    Field: 'tenancy',
                    Value: 'Shared',
                },
                {
                    Type: 'TERM_MATCH',
                    Field: 'preInstalledSw',
                    Value: 'NA',
                },
                {
                    Type: 'TERM_MATCH',
                    Field: 'capacitystatus',
                    Value: 'Used',
                },
            ],
            MaxResults: 1,
        });

        const response = await pricingClient.send(command);

        if (!response.PriceList || response.PriceList.length === 0) {
            throw new Error(`No pricing data found for instance type: ${instanceType}`);
        }

        // Parse pricing data
        const priceData = JSON.parse(response.PriceList[0]);
        const onDemand = priceData.terms.OnDemand;
        const priceId = Object.keys(onDemand)[0];
        const priceDimensions = onDemand[priceId].priceDimensions;
        const dimensionId = Object.keys(priceDimensions)[0];
        const pricePerHour = parseFloat(priceDimensions[dimensionId].pricePerUnit.USD);

        return pricePerHour;
    } catch (error) {
        console.error('Error fetching instance pricing:', error);
        // Fallback pricing for common instance types
        const fallbackPricing: { [key: string]: number } = {
            't3.micro': 0.0104,
            't3.small': 0.0208,
            't3.medium': 0.0416,
            't3.large': 0.0832,
            't3a.micro': 0.0094,
            't3a.small': 0.0188,
            't3a.medium': 0.0376,
            't3a.large': 0.0752,
        };
        return fallbackPricing[instanceType] || 0.05; // Default fallback
    }
}

function getRegionName(region: string): string {
    const regionMap: { [key: string]: string } = {
        'us-east-1': 'US East (N. Virginia)',
        'us-east-2': 'US East (Ohio)',
        'us-west-1': 'US West (N. California)',
        'us-west-2': 'US West (Oregon)',
        'eu-west-1': 'EU (Ireland)',
        'eu-central-1': 'EU (Frankfurt)',
        'ap-southeast-1': 'Asia Pacific (Singapore)',
        'ap-southeast-2': 'Asia Pacific (Sydney)',
        'ap-northeast-1': 'Asia Pacific (Tokyo)',
    };
    return regionMap[region] || 'US East (N. Virginia)';
}

export async function GET() {
    try {
        // Get instance type from nodes
        const instanceType = await getInstanceTypeFromNodes();

        // Get pricing for instance type
        const instancePrice = await getInstancePricing(instanceType);

        // Get node count
        const nodes = await k8sCoreApi.listNode();
        const nodeCount = nodes.body.items.length;

        // Get current replica count
        const deployment = await k8sAppsApi.readNamespacedDeployment(
            deploymentName,
            namespace
        );
        const replicas = deployment.body.spec?.replicas || 1;

        // Calculate hourly cost
        // Simple calculation: (instance price * node count)
        // More accurate would be: (instance price * nodes * utilization factor)
        const hourlyCost = instancePrice * nodeCount;

        return NextResponse.json({
            hourlyCost: parseFloat(hourlyCost.toFixed(4)),
            instanceType: instanceType,
            instancePrice: parseFloat(instancePrice.toFixed(4)),
            nodeCount: nodeCount,
            replicas: replicas,
            currency: 'USD',
            region: awsRegion,
        });
    } catch (error: any) {
        console.error('Cost API error:', error);

        // Return fallback cost data if API fails
        return NextResponse.json(
            {
                error: 'Failed to fetch cost data',
                message: error.message,
                fallback: true,
                hourlyCost: 0.08, // Fallback for 2x t3.medium
                instanceType: 't3.medium',
                instancePrice: 0.0416,
                nodeCount: 2,
                replicas: 1,
                currency: 'USD',
            },
            { status: 500 }
        );
    }
}
