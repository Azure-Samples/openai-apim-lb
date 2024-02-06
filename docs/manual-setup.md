# Manual Setup Instructions for Smart Load Balancing

## :gear: Setup Instructions

This document outlines the steps to manually set up smart load balancing for OpenAI endpoints using Azure API Management.

### Step 1: Provision Azure API Management Instance
- Provision an [Azure API Management instance](https://learn.microsoft.com/en-us/azure/api-management/get-started-create-service-instance).
- Ensure that you check the Status box enabling `Managed Identity` during provisioning.

### Step 2: Provision Azure OpenAI Service Instances
- Provision your Azure OpenAI Service instances.
- Deploy the same models and versions in each instance.
- Use consistent naming for deployments, e.g., `gpt-35-turbo` or `gpt4-8k`, and select the same version, e.g., `0613`.

### Step 3: Configure Managed Identity Access
- For each Azure OpenAI Service instance:
  - Go to the Azure OpenAI instance in the Azure Portal.
  - Click `Access control (IAM)`.
  - Click `+ Add`, then `Add role assignment`.
  - Select the role `Cognitive Services OpenAI User`.
  - Choose `Managed Identity` under `Assign access to`.
  - Select `+ Select Members`, and choose the Managed Identity of your API Management instance.

### Step 4: Download and Prepare API Schema
- Download the desired API schema for Azure OpenAI Service (excluding code samples).
    - [2023-12-01-preview](https://raw.githubusercontent.com/Azure/azure-rest-api-specs/main/specification/cognitiveservices/data-plane/AzureOpenAI/inference/preview/2023-12-01-preview/inference.json)
    - [other versions](https://github.com/Azure/azure-rest-api-specs/tree/main/specification/cognitiveservices/data-plane/AzureOpenAI/inference/preview)

### Step 5: Import API Schema into API Management
- Open `inference.json` and update the `servers` section:
  ```
    "servers": [
        {
        "url": "https://microsoft.com/openai",
        "variables": {
            "endpoint": {
            "default": "itdoesntmatter.openai.azure.com"
            }
        }
        }
    ],
    ```
- Go to your API Management instance in the Azure Portal.
- Under `API`, click `+ Add API` and select `OpenAI`.
- Load your `inference.json` file and click `Create`.
- Note: Set the API suffix appropriately if using the Azure OpenAI SDK.

> If you are using the Azure OpenAI SDK, make sure you set the API suffix to "something/**openai**". For example, "openai-load-balancing/**openai**". This is needed because the Azure OpenAI SDK automatically appends "/openai" in the requests and if that is missing in the API suffix, API Management will return 404 Not Found. Unless you want to use the API suffix solely as "openai", then there is no need to duplicate like "openai/openai".

### Step 6: Configure API Settings
- Select the new API in API Management.
- Go to `Settings`, then `Subscription`.
- Ensure `Subscription required` is checked and `Header name` is set to `api-key`.

### Step 7: Update API Management Policy
- Edit `apim-policy.xml` to include all the Azure OpenAI instances you want to use (excluding code samples).
- Assign the desired priority to each instance.
    ```
    backends.Add(new JObject()
    {
        { "url", "https://openai-eastus.openai.azure.com/" },
        { "priority", 1},
        { "isThrottling", false }, 
        { "retryAfter", DateTime.MinValue } 
    });
    ...
    ```

### Step 8: Apply Policy in API Management
- Return to API Management and select `Design`.
- Choose `All operations` and click the `</>` icon in inbound processing.
- Replace the code with your updated `apim-policy.xml`.
- Save the changes.

### Step 9: Finalize Subscription Settings
- Go to `Subscriptions` in API Management.
- Click `+ Add Subscription`.
- Name the subscription, scope it to your `Azure OpenAI Service API`, and create it.

### Step 10: Test the Configuration
- Test the setup with appropriate code (e.g., using the OpenAI Python SDK).
- [Example code](/docs/sample-code.md)

## Conclusion

By following these steps, you can establish a robust smart load balancing system for OpenAI endpoints, leveraging Azure API Management for efficient and reliable application performance.
