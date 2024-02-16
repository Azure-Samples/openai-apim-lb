# Using Azure Developer CLI (azd) for Simplified Development and Deployment

## Introduction to Azure Developer CLI

Azure Developer CLI (azd) is a command-line tool designed to simplify the development and deployment of applications on Azure. It provides a streamlined and consistent workflow for developers, making it easier to build, test, and deploy applications across various Azure services. This section will guide you through using azd for authentication and deploying your application.

## Install AZD

To get started with Azure Developer CLI, you need to install the tool on your local machine. The installation process is straightforward and has instructions for various operating systems:

[Install Azure Developer CLI](https://learn.microsoft.com/en-us/azure/developer/azure-developer-cli/install-azd)


## Authentication with Azure Developer CLI

Before you begin deploying your application, you need to authenticate with Azure. The Azure Developer CLI provides a simple command for this:

1. **Authentication Command**:
   - Use `azd auth login` to start the authentication process. This command opens a web page where you can enter your Azure credentials. Once authenticated, `azd` stores your credentials securely, allowing you to deploy and manage Azure resources without logging in again during the session.

## Deploying with Azure Developer CLI

After successful authentication, you can proceed with deploying your application using Azure Developer CLI. The process is straightforward and involves the following steps:

1. **Deploy Your Application**:
   - Use `azd up` to deploy your application. This command performs several actions:
     - **Builds your application**: Compiles and prepares your application for deployment.
     - **Provisions Azure resources**: Automatically creates and configures the necessary Azure services based on your project's requirements.
     - **Output**: The command provides a detailed output, including URLs and endpoints, for accessing your deployed application and related resources.

## Post-Deployment

Once the deployment is complete, you can access the application. Azure Developer CLI also integrates with Azure Monitor and Azure Application Insights, allowing you to monitor the performance and health of your application directly from the command line.

## Sample Code

- Test the setup with appropriate code (e.g., using the OpenAI Python SDK).
- [Example code](/docs/sample-code.md)


## Enable Entra Authentication
To enable [Protect an API in Azure APIM with Entra ID](https://learn.microsoft.com/en-us/azure/api-management/api-management-howto-protect-backend-with-aad), create App Registration set the `AZURE_ENTRA_AUTH` variable to true before running `azd up`

- Create App registration follow steps [Register an application in Microsoft Entra ID to represent the API](https://learn.microsoft.com/en-us/azure/api-management/api-management-howto-protect-backend-with-aad#register-an-application-in-microsoft-entra-id-to-represent-the-api)

- Set following AZD variables:
1. Run `azd env set AZURE_ENTRA_AUTH true`
1. Run `azd env set AZURE_CLIENT_ID  <apd id>`
1. Run `azd env set AZURE_TENANT_ID  <tenant id>`
1. Run `azd env set AZURE_AUDIENCE <app id URI>`

1. Run `azd up`

## Sample ENTRA testing code

- [Example HTTP level code](/src/tests.http)
- [Example Python OpenAI SDK + ENTRA](/src/azure_openai_aad.py)
- [Example Langchain SDK + ENTRA](/src/azure_openai_aad_langchain.py)

For all examples fill in values in `.env` file, sample `.env.sample` is provided in `src` folder

