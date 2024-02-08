# Python Sample Code for Using Azure OpenAI with API Management

This Python sample demonstrates how to use the Azure OpenAI SDK to interact with an Azure API Management endpoint. The code snippet below outlines the process of initializing the Azure OpenAI client and making a request to generate a response based on the model deployed in your Azure OpenAI service.

## Sample Code

```python
from openai import AzureOpenAI

client = AzureOpenAI(
   azure_endpoint="https://<your_APIM_endpoint>.azure-api.net/<your_api_suffix>", #do not add "/openai" at the end here because this will be automatically added by this SDK
   api_key="<your subscription key>",
   api_version="2023-12-01-preview"
)

response = client.chat.completions.create(
   model="<your_deployment_name>",
   messages=[
      {"role": "system", "content": "You are a helpful assistant."},
      {"role": "user", "content": "Does Azure OpenAI support customer managed keys?"}
   ]
)
print(response)
```

## Usage Instructions

1. **Endpoint Configuration**:
   - Replace `<your_APIM_endpoint>` with your actual Azure API Management endpoint URL.
   - Replace `<your_api_suffix>` with the API suffix configured in your API Management instance.

2. **Authentication**:
   - Replace `<your subscription key>` with your Azure API Management subscription key.

3. **API Version**:
   - The `api_version` is set to `"2023-12-01-preview"`. Ensure this matches the version deployed in your Azure OpenAI service.

4. **Model Specification**:
   - Replace `<your_deployment_name>` with the name of the model you have deployed in Azure OpenAI service.

5. **Running the Code**:
   - Execute this script to interact with the Azure OpenAI service through the configured API Management endpoint.
   - The script sends a predefined message and prints the response from the OpenAI model.

```bash
$ python ./azure_openai_sample.py 
ChatCompletion(id=None, choices=None, created=None, model=None, object=None, system_fingerprint=None, usage=None, response='Yes, Azure OpenAI supports customer managed keys. With Azure Key Vault integration, you can securely store and manage your keys using Azure Key Vault and then provide them to OpenAI in a way that is transparent and seamless. This allows you to have control over your keys and ensures that your data and models are protected.')
```

## Note

This sample is intended to be used as a basic example of integrating Azure OpenAI with Azure API Management. Depending on your specific use case and environment setup, additional configuration and error handling may be required.
