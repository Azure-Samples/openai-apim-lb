from openai import AzureOpenAI
from dotenv import load_dotenv
from azure.identity import DefaultAzureCredential, get_bearer_token_provider
import os

load_dotenv()

apim_endpoint = os.getenv("APIM_ENDPOINT")
audience = os.getenv("AZURE_AUDIENCE")+ "/.default"

token_provider = get_bearer_token_provider(DefaultAzureCredential(), audience)     # "https://cognitiveservices.azure.com/.default"

client = AzureOpenAI(
    azure_endpoint=apim_endpoint, #do not add "/openai" at the end here because this will be automatically added by this SDK
    azure_ad_token_provider=token_provider,
    api_version="2023-12-01-preview"
)

response = client.chat.completions.create(
    model="chat",
    messages=[
        {"role": "system", "content": "You are a helpful assistant."},
        {"role": "user", "content": "Does Azure OpenAI support customer managed keys?"}
    ]
)
print(response.choices[0].message.content)