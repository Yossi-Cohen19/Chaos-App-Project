const {
    SecretsManagerClient,
    GetSecretValueCommand,
} = require("@aws-sdk/client-secrets-manager");

const secret_name = "rds!db-623b3f64-c63e-48b3-a71d-ad96bf01d9e5";

const client = new SecretsManagerClient({
    region: "us-east-1",
});

async function getSecret() {
    try {
        const response = await client.send(
            new GetSecretValueCommand({
                SecretId: secret_name,
                VersionStage: "AWSCURRENT",
            })
        );
        console.log(response.SecretString);
    } catch (error) {
        console.error(error);
    }
}

getSecret();
